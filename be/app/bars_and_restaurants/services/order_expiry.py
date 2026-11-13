"""
When an order drops off the live cashier queue.

An order expires at the close of the venue operating day (shift) in which it
was created, in the venue's local time (``America/Sao_Paulo`` for the MVP):

* Same-day shift (e.g. 11:00-23:00): expires at that day's close.
* Overnight shift (close <= open, e.g. 20:00-04:00): an evening order expires
  at the next day's close, and an early-morning order (before the close)
  belongs to the previous day's shift and expires at that close.
* Created while the venue is closed (before opening, after closing, on a
  closed day): belongs to the next shift and expires at its close.

Bars without configured operating hours expire orders 24h after creation.
No order is live for more than 24h. A shift is always shorter than 24h, so
this cap only affects orders created while the venue is closed, e.g. right
before several closed days. Callers may therefore skip orders older than
``MAX_ORDER_LIFETIME`` without evaluating the hours.

Operating hours come from ``bars.operating_hours``:
``{"monday": {"open": "18:00", "close": "02:00", "is_closed": false}, ...}``.
Some write paths accept them unvalidated. Entries that are closed, malformed,
or have open == close are ignored. If no usable entries remain, the bar is
treated as having no configured hours.
"""

import json
import logging
from datetime import date, datetime, time, timedelta, timezone
from typing import Any, Dict, Optional, Tuple
from zoneinfo import ZoneInfo

logger = logging.getLogger(__name__)

DEFAULT_VENUE_TIMEZONE = "America/Sao_Paulo"
MAX_ORDER_LIFETIME = timedelta(hours=24)

WEEKDAYS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")

Shift = Tuple[time, time]  # (open, close) in venue local time


def _parse_clock(value: Any) -> Optional[time]:
    """Parse ``HH:MM`` / ``HH:MM:SS``. ``24:00`` means midnight at day end."""
    if not isinstance(value, str):
        return None
    value = value.strip()
    if value in ("24:00", "24:00:00"):
        return time(0, 0)
    try:
        parsed = time.fromisoformat(value)
    except ValueError:
        return None
    return parsed.replace(tzinfo=None)


def parse_operating_hours(operating_hours: Any) -> Dict[int, Shift]:
    """Map weekday index (Monday=0) to its (open, close) shift, skipping
    closed or unusable days."""
    if isinstance(operating_hours, str):
        try:
            operating_hours = json.loads(operating_hours)
        except ValueError:
            return {}
    if not isinstance(operating_hours, dict):
        return {}

    shifts: Dict[int, Shift] = {}
    for index, day_name in enumerate(WEEKDAYS):
        hours = operating_hours.get(day_name)
        if not isinstance(hours, dict) or hours.get("is_closed"):
            continue
        open_time = _parse_clock(hours.get("open"))
        close_time = _parse_clock(hours.get("close"))
        if open_time is None or close_time is None or open_time == close_time:
            continue
        shifts[index] = (open_time, close_time)
    return shifts


def venue_timezone(tz_name: Optional[str]) -> ZoneInfo:
    try:
        return ZoneInfo(tz_name or DEFAULT_VENUE_TIMEZONE)
    except Exception:
        logger.warning("Unknown venue timezone %r; using %s", tz_name, DEFAULT_VENUE_TIMEZONE)
        return ZoneInfo(DEFAULT_VENUE_TIMEZONE)


def _as_utc(value: datetime) -> datetime:
    # Order timestamps are stored as naive UTC (datetime.utcnow()).
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _shift_close_utc(day: date, shift: Shift, tz: ZoneInfo) -> datetime:
    open_time, close_time = shift
    close_day = day + timedelta(days=1) if close_time <= open_time else day
    return datetime.combine(close_day, close_time, tzinfo=tz).astimezone(timezone.utc)


def order_expiry_utc(
    created_at: datetime,
    operating_hours: Any,
    tz_name: Optional[str] = None,
) -> datetime:
    """UTC instant at which an order created at ``created_at`` stops being live."""
    created_utc = _as_utc(created_at)
    latest = created_utc + MAX_ORDER_LIFETIME

    shifts = parse_operating_hours(operating_hours)
    if not shifts:
        return latest

    tz = venue_timezone(tz_name)
    local_date = created_utc.astimezone(tz).date()

    # Check shifts in start order, beginning with yesterday's (it may run past
    # midnight). The first one still open at creation time is the order's
    # operating day: the shift it was placed in, or the next one if the venue
    # was closed.
    for offset in range(-1, 8):
        day = local_date + timedelta(days=offset)
        shift = shifts.get(day.weekday())
        if shift is None:
            continue
        close_utc = _shift_close_utc(day, shift, tz)
        if close_utc > created_utc:
            return min(close_utc, latest)
    return latest


def is_order_expired(
    created_at: datetime,
    operating_hours: Any,
    tz_name: Optional[str] = None,
    now: Optional[datetime] = None,
) -> bool:
    now_utc = _as_utc(now) if now is not None else datetime.now(timezone.utc)
    return now_utc >= order_expiry_utc(created_at, operating_hours, tz_name)
