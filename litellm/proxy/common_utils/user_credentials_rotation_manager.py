from datetime import datetime, timedelta, timezone
from typing import Any

from litellm._logging import verbose_proxy_logger
from litellm.constants import LITELLM_USER_CREDENTIALS_ROTATION_LOCK_TTL_SECONDS
from litellm.models.user import LiteLLM_UserTable
from litellm.proxy.utils import PrismaClient, send_email
from litellm.repositories.user_repository import UserRepository


UserCredentialsReminderRow = LiteLLM_UserTable


class UserCredentialsRotationManager:
    def __init__(
        self,
        prisma_client: PrismaClient,
        pod_lock_manager: Any = None,
        reminder_days: int = 10,
    ):
        self.prisma_client = prisma_client
        self.pod_lock_manager = pod_lock_manager
        self.reminder_days = max(reminder_days, 0)

    async def process_rotations(self) -> None:
        from litellm.constants import USER_CREDENTIALS_ROTATION_JOB_NAME

        lock_acquired = False
        try:
            if self.pod_lock_manager and self.pod_lock_manager.redis_cache:
                lock_ttl = max(LITELLM_USER_CREDENTIALS_ROTATION_LOCK_TTL_SECONDS, 300)
                lock_acquired = (
                    await self.pod_lock_manager.acquire_lock(
                        cronjob_id=USER_CREDENTIALS_ROTATION_JOB_NAME,
                        ttl=lock_ttl,
                    )
                    or False
                )
                if not lock_acquired:
                    verbose_proxy_logger.warning(
                        "User credentials rotation: another pod is already running reminders or Redis lock acquisition failed; skipping this cycle"
                    )
                    return

            users_to_notify = await self._find_users_needing_reminders()
            if not users_to_notify:
                verbose_proxy_logger.debug(
                    "No user credential rotation reminders are due at this time"
                )
                return

            for user in users_to_notify:
                try:
                    await self._notify_user(user=user)
                    verbose_proxy_logger.info(
                        "Sent user credential rotation reminder to user_id=%s",
                        user.user_id,
                    )
                except Exception as e:
                    verbose_proxy_logger.error(
                        "Failed to send user credential rotation reminder to user_id=%s: %s",
                        user.user_id,
                        e,
                    )
        except Exception as e:
            verbose_proxy_logger.error(
                "User credential rotation reminder process failed: %s",
                e,
            )
        finally:
            if (
                lock_acquired
                and self.pod_lock_manager
                and self.pod_lock_manager.redis_cache
            ):
                await self.pod_lock_manager.release_lock(
                    cronjob_id=USER_CREDENTIALS_ROTATION_JOB_NAME,
                )

    async def _find_users_needing_reminders(self) -> list[UserCredentialsReminderRow]:
        now = datetime.now(timezone.utc)
        reminder_threshold = now + timedelta(days=self.reminder_days)
        return await UserRepository(self.prisma_client).table.find_many(
            where={
                "password": {"not": None},
                "password_expiry": {
                    "gte": now,
                    "lte": reminder_threshold,
                },
                "user_email": {"not": None},
                "sso_user_id": None,
            }
        )

    async def _notify_user(self, user: UserCredentialsReminderRow) -> None:
        user_email = getattr(user, "user_email", None)
        password_expiry = getattr(user, "password_expiry", None)
        if not isinstance(user_email, str) or not user_email.strip() or password_expiry is None:
            return

        subject = "LiteLLM password rotation reminder"
        html = (
            "<p>Your LiteLLM password will expire soon.</p>"
            f"<p>Password expiry: <b>{password_expiry}</b></p>"
            "<p>Please rotate your password before the expiry date to keep access.</p>"
        )
        await send_email(
            receiver_email=user_email,
            subject=subject,
            html=html,
        )


__all__ = ["UserCredentialsRotationManager"]
