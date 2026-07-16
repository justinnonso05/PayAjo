from apscheduler.schedulers.asyncio import AsyncIOScheduler

scheduler = AsyncIOScheduler()

async def daily_payout_tick():
    """
    Runs daily to check if any groups have met their payout criteria
    and triggers disbursements.
    """
    # TODO: Implement payout sweep logic
    print("Running daily payout tick...")

# Schedule it to run daily at midnight
scheduler.add_job(daily_payout_tick, 'cron', hour=0, minute=0)
