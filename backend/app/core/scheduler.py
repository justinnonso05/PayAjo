import logging
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import AsyncSessionLocal
from app.core.config import settings
from app.modules.group.models import Group
from app.modules.cycle.service import evaluate_payout_for_group
from sqlalchemy import select

import logging
import sys

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter('%(asctime)s - [SCHEDULER] - %(levelname)s - %(message)s'))
    logger.addHandler(handler)
scheduler = AsyncIOScheduler()

async def payout_job():
    logger.info("Running automated payout job...")
    async with AsyncSessionLocal() as db:
        from app.common.enums import GroupStatus
        from datetime import datetime, timezone
        groups_res = await db.execute(
            select(Group).where(
                Group.status == GroupStatus.ACTIVE,
                Group.next_payout_date != None,
                Group.next_payout_date <= datetime.now(timezone.utc)
            )
        )
        groups = groups_res.scalars().all()
        matched_count = 0
        for group in groups:
            safe_group_id = group.id
            try:
                result = await evaluate_payout_for_group(db, group)
                await db.commit()
                if result:
                    if result.get("status") == "paid":
                        matched_count += 1
                        logger.info(f"MATCH: Group '{result['group_name']}' -> Paid NGN {result['amount']} to {result['user_name']} ({result['user_id']})")
                    elif result.get("status") == "quorum_failed":
                        logger.warning(f"SKIPPED: Group '{result['group_name']}' is due, but quorum not met ({result['collected']}% < {result['required']}%)")
            except Exception as e:
                await db.rollback()
                logger.error(f"Error evaluating payout for group {safe_group_id}: {e}", exc_info=True)
    logger.info(f"Automated payout job completed successfully. Processed {matched_count} matches.")

from app.modules.group.reminder_service import evaluate_and_send_reminders

async def reminder_job():
    logger.info("Running automated reminder job...")
    async with AsyncSessionLocal() as db:
        from app.common.enums import GroupStatus
        groups_res = await db.execute(
            select(Group).where(Group.status == GroupStatus.ACTIVE)
        )
        groups = groups_res.scalars().all()
        for group in groups:
            try:
                await evaluate_and_send_reminders(db, group)
                await db.commit()
            except Exception as e:
                await db.rollback()
                logger.error(f"Error evaluating reminders for group {group.id}: {e}", exc_info=True)
    logger.info("Automated reminder job completed.")

from app.modules.cycle.auto_debit_service import evaluate_and_process_auto_debits

async def auto_debit_job():
    logger.info("Running automated auto-debit job...")
    async with AsyncSessionLocal() as db:
        from app.common.enums import GroupStatus
        groups_res = await db.execute(
            select(Group).where(Group.status == GroupStatus.ACTIVE)
        )
        groups = groups_res.scalars().all()
        for group in groups:
            try:
                await evaluate_and_process_auto_debits(db, group)
            except Exception as e:
                logger.error(f"Error evaluating auto-debits for group {group.id}: {e}", exc_info=True)
    logger.info("Automated auto-debit job completed.")

def start_scheduler():
    # Only start if enabled in env
    interval_minutes = getattr(settings, "SCHEDULER_INTERVAL_MINUTES", 5)
    scheduler.add_job(payout_job, IntervalTrigger(minutes=interval_minutes), id="payout_job", replace_existing=True)
    scheduler.add_job(reminder_job, IntervalTrigger(minutes=interval_minutes), id="reminder_job", replace_existing=True)
    scheduler.add_job(auto_debit_job, IntervalTrigger(minutes=interval_minutes), id="auto_debit_job", replace_existing=True)
    scheduler.start()
    logger.info(f"Scheduler started with {interval_minutes} minutes interval.")

def stop_scheduler():
    scheduler.shutdown()
