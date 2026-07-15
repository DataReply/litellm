from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from litellm.proxy.common_utils.user_credentials_rotation_manager import (
    UserCredentialsRotationManager,
)


@pytest.mark.asyncio
async def test_find_users_needing_reminders_filters_active_window():
    mock_prisma = MagicMock()
    mock_prisma.db.litellm_usertable.find_many = AsyncMock(return_value=[])

    manager = UserCredentialsRotationManager(mock_prisma, reminder_days=10)
    await manager._find_users_needing_reminders()

    where = mock_prisma.db.litellm_usertable.find_many.await_args.kwargs["where"]
    now = datetime.now(timezone.utc)
    lower_bound = where["password_expiry"]["gte"]
    upper_bound = where["password_expiry"]["lte"]

    assert where["password"] == {"not": None}
    assert where["user_email"] == {"not": None}
    assert where["sso_user_id"] is None
    assert lower_bound >= now - timedelta(seconds=5)
    assert timedelta(days=9, hours=23) <= upper_bound - lower_bound <= timedelta(days=10, seconds=5)


@pytest.mark.asyncio
async def test_notify_user_sends_email_for_expiring_password():
    mock_prisma = MagicMock()
    manager = UserCredentialsRotationManager(mock_prisma, reminder_days=10)
    user = MagicMock()
    user.user_email = "user@example.com"
    user.password_expiry = datetime(2030, 1, 1, tzinfo=timezone.utc)

    with patch(
        "litellm.proxy.common_utils.user_credentials_rotation_manager.send_email",
        new_callable=AsyncMock,
    ) as mock_send_email:
        await manager._notify_user(user)

    mock_send_email.assert_awaited_once()
    call = mock_send_email.await_args.kwargs
    assert call["receiver_email"] == "user@example.com"
    assert call["subject"] == "LiteLLM password rotation reminder"
    assert "2030-01-01" in call["html"]
    assert "/ui/change-password" in call["html"]


@pytest.mark.asyncio
async def test_process_rotations_skips_when_lock_not_acquired():
    mock_prisma = MagicMock()
    mock_pod_lock_manager = MagicMock()
    mock_pod_lock_manager.redis_cache = MagicMock()
    mock_pod_lock_manager.acquire_lock = AsyncMock(return_value=False)
    mock_pod_lock_manager.release_lock = AsyncMock()

    manager = UserCredentialsRotationManager(
        mock_prisma,
        pod_lock_manager=mock_pod_lock_manager,
        reminder_days=10,
    )
    manager._find_users_needing_reminders = AsyncMock()

    await manager.process_rotations()

    manager._find_users_needing_reminders.assert_not_awaited()
    mock_pod_lock_manager.release_lock.assert_not_awaited()


@pytest.mark.asyncio
async def test_process_rotations_acquires_and_releases_lock():
    mock_prisma = MagicMock()
    mock_pod_lock_manager = MagicMock()
    mock_pod_lock_manager.redis_cache = MagicMock()
    mock_pod_lock_manager.acquire_lock = AsyncMock(return_value=True)
    mock_pod_lock_manager.release_lock = AsyncMock()

    manager = UserCredentialsRotationManager(
        mock_prisma,
        pod_lock_manager=mock_pod_lock_manager,
        reminder_days=10,
    )
    manager._find_users_needing_reminders = AsyncMock(return_value=[])

    await manager.process_rotations()

    mock_pod_lock_manager.acquire_lock.assert_awaited_once()
    acquire_call = mock_pod_lock_manager.acquire_lock.await_args
    assert acquire_call.kwargs["cronjob_id"] == "litellm_user_credentials_rotation_job"
    assert acquire_call.kwargs["ttl"] >= 300
    mock_pod_lock_manager.release_lock.assert_awaited_once_with(
        cronjob_id="litellm_user_credentials_rotation_job"
    )


@pytest.mark.asyncio
async def test_process_rotations_continues_after_notify_error():
    mock_prisma = MagicMock()
    manager = UserCredentialsRotationManager(mock_prisma, reminder_days=10)
    user_one = MagicMock(user_id="user-1")
    user_two = MagicMock(user_id="user-2")
    manager._find_users_needing_reminders = AsyncMock(return_value=[user_one, user_two])
    manager._notify_user = AsyncMock(side_effect=[Exception("boom"), None])

    await manager.process_rotations()

    assert manager._notify_user.await_count == 2
