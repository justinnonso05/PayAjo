import asyncio
import argparse
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

from app.core.config import settings

async def clear_database():
    """
    Strategically clears the PostgreSQL database without running into foreign key issues.
    It does this by dropping the public schema completely and recreating it.
    This wipes all tables, views, and the alembic_version table.
    """
    print(f"Connecting to database to clear it...")
    
    # We use AUTOCOMMIT because DROP SCHEMA cannot run inside a transaction block
    engine = create_async_engine(settings.DATABASE_URL, isolation_level="AUTOCOMMIT")
    
    try:
        async with engine.begin() as conn:
            print("Dropping public schema (CASCADE)...")
            await conn.execute(text("DROP SCHEMA public CASCADE;"))
            
            print("Recreating public schema...")
            await conn.execute(text("CREATE SCHEMA public;"))
            
            # Re-grant default permissions
            await conn.execute(text("GRANT ALL ON SCHEMA public TO public;"))
            
        print("✅ Database cleared successfully!")
        print("👉 You can now run `alembic upgrade head` to recreate your tables.")
    except Exception as e:
        print(f"❌ Error clearing database: {e}")
    finally:
        await engine.dispose()
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Wipe the PostgreSQL database cleanly.")
    parser.add_argument("--confirm", action="store_true", help="Confirm that you want to wipe the database")
    args = parser.parse_args()
    
    if not args.confirm:
        print("⚠️  WARNING: This will completely wipe all data and tables in your database!")
        print("To proceed, run the script with the --confirm flag:")
        print("python clear_db.py --confirm")
        exit(1)
        
    asyncio.run(clear_database())
