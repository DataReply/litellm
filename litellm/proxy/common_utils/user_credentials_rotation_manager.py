"""
User Credentials Rotation Manager - Automated user credentials rotation based on rotation schedules

Handles finding user credentials that need rotation based on their individual schedules.
"""

from datetime import datetime, timezone
from typing import List

from litellm._logging import verbose_proxy_logger
from litellm.constants import (
    LITELLM_INTERNAL_JOBS_SERVICE_ACCOUNT_NAME,
    LITELLM_USER_CREDENTIALS_ROTATION_GRACE_PERIOD,
    LITELLM_USER_CREDENTIALS_ROTATION_LOCK_TTL_SECONDS,
)
from litellm.proxy._types import (
    GenerateKeyResponse,
    LiteLLM_UserTableFiltered,
    RegenerateKeyRequest,
)
from litellm.proxy.hooks.key_management_event_hooks import KeyManagementEventHooks
from litellm.proxy.management_endpoints.key_management_endpoints import (
    _calculate_key_rotation_time,
    regenerate_key_fn,
)
from litellm.proxy.utils import PrismaClient
from litellm.repositories.table_repositories import (
    DeprecatedVerificationTokenRepository,
)
from litellm.repositories.user_repository import (
    UserRepository,
)


class KeyRotationManager:
    """
    Manages automated user credentials rotation based 
    on individual user credentials rotation schedules.
    """

    def __init__(self, prisma_client: PrismaClient, pod_lock_manager=None, notify_users_on_expiration=False):
        self.prisma_client = prisma_client
        self.pod_lock_manager = pod_lock_manager
        self.notify_users_on_expiration

    async def process_rotations(self):
        """
        Main entry point - find and rotate user credentials that are due for rotation.
        Uses PodLockManager to ensure only one pod runs rotation in multi-pod deployments.
        """
        from litellm.constants import USER_CREDENTIALS_ROTATION_JOB_NAME

        lock_acquired = False
        try:
            # If we have a pod lock manager with Redis, try to acquire the lock
            if self.pod_lock_manager and self.pod_lock_manager.redis_cache:
                # Use a dedicated lock TTL (default 600s) instead of the check interval
                # (which defaults to 86400s / 24h). Using the check interval would create
                # a 24-hour deadlock window if a pod crashes before releasing the lock.
                lock_ttl = max(
                    LITELLM_USER_CREDENTIALS_ROTATION_LOCK_TTL_SECONDS, 300
                )  # At least 5 minutes, configurable via LITELLM_USER_CREDENTIALS_ROTATION_LOCK_TTL_SECONDS
                lock_acquired = (
                    await self.pod_lock_manager.acquire_lock(
                        cronjob_id=USER_CREDENTIALS_ROTATION_JOB_NAME,
                        ttl=lock_ttl,
                    )
                    or False
                )
                if not lock_acquired:
                    verbose_proxy_logger.warning(
                        "User Credentials rotation: another pod is already running rotation "
                        "or Redis lock acquisition failed — skipping this cycle. "
                        "User Credentials will be rotated on the next cycle."
                    )
                    return

            verbose_proxy_logger.info("Starting scheduled user credentials rotation check...")

            # Find credentials that are due for rotation
            user_credentials_to_rotate = await self._find_credentials_needing_rotation()

            if not user_credentials_to_rotate:
                verbose_proxy_logger.debug("No user credentials are due for rotation at this time")
                return

            verbose_proxy_logger.info(f"Found {len(user_credentials_to_rotate)} keys due for rotation")

            if self.notify_users_on_expiration:
                # Notify each user
                for user in user_credentials_to_rotate:
                    try:
                        await self._notify_user(user)
                        verbose_proxy_logger.info(f"Successfully notified user: {user.user_id}")
                    except Exception as e:
                        verbose_proxy_logger.error(f"Failed to notify user {user.user_id}: {e}")

        except Exception as e:
            verbose_proxy_logger.error(f"User password expired process failed: {e}")
        finally:
            # Only release the lock if it was actually acquired
            if lock_acquired and self.pod_lock_manager and self.pod_lock_manager.redis_cache:
                await self.pod_lock_manager.release_lock(
                    cronjob_id=USER_CREDENTIALS_ROTATION_JOB_NAME,
                )

    async def _find_credentials_needing_rotation(self) -> List[LiteLLM_UserTableFiltered]:
        """
        Find user_credentials that are due for rotation based on their password_expiry timestamp.

        Logic:
        - password_expiry is not null AND password_expiry <= now
        """
        now = datetime.now(timezone.utc)

        credentials_with_rotation = await UserRepository(self.prisma_client).table.find_many(
            where={
                "password_expiry": { "lte": now } # Users whose passwords expiry timestamp has passed
            }
        )

        return credentials_with_rotation

    async def _notify_user(self, user: LiteLLM_UserTableFiltered):
        """
        Notify users whose password is expired
        """
        # TODO: implement email notification
        return
