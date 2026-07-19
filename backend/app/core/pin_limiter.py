"""
PIN attempt rate-limiting using an in-memory store.
5 failed attempts → 15-minute cooldown.
No Redis required — suitable for single-process hackathon deployment.
"""
from datetime import datetime, timedelta, timezone
from typing import Dict, Tuple
import asyncio

# In-memory store: user_id -> (fail_count, locked_until | None)
_pin_attempts: Dict[str, Tuple[int, datetime | None]] = {}

MAX_ATTEMPTS = 5
COOLDOWN_MINUTES = 15


def _now() -> datetime:
    return datetime.now(timezone.utc)


def check_pin_rate_limit(user_id: str) -> None:
    """
    Raises ValueError if the user is currently locked out.
    Call this BEFORE verifying the PIN.
    """
    record = _pin_attempts.get(user_id)
    if record is None:
        return

    fail_count, locked_until = record
    if locked_until and _now() < locked_until:
        remaining = int((locked_until - _now()).total_seconds() / 60) + 1
        raise ValueError(f"Too many incorrect PIN attempts. Try again in {remaining} minute(s).")
    elif locked_until and _now() >= locked_until:
        # Cooldown expired — reset
        _pin_attempts.pop(user_id, None)


def record_pin_failure(user_id: str) -> int:
    """
    Increments the failure counter. If MAX_ATTEMPTS is reached, locks the user out.
    Call this AFTER a PIN verification failure.
    Returns the number of attempts remaining (0 means now locked out).
    """
    record = _pin_attempts.get(user_id, (0, None))
    fail_count = record[0] + 1
    locked_until = None

    if fail_count >= MAX_ATTEMPTS:
        locked_until = _now() + timedelta(minutes=COOLDOWN_MINUTES)

    _pin_attempts[user_id] = (fail_count, locked_until)
    return max(0, MAX_ATTEMPTS - fail_count)


def record_pin_success(user_id: str) -> None:
    """
    Resets the failure counter on a successful PIN entry.
    Call this AFTER a successful PIN verification.
    """
    _pin_attempts.pop(user_id, None)


def get_pin_attempts_remaining(user_id: str) -> int:
    """Returns how many attempts are left before lockout."""
    record = _pin_attempts.get(user_id)
    if record is None:
        return MAX_ATTEMPTS
    fail_count, _ = record
    return max(0, MAX_ATTEMPTS - fail_count)
