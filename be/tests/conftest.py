import pytest
import asyncio
from typing import AsyncGenerator, Generator
from httpx import AsyncClient, ASGITransport
from databases import Database
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch, AsyncMock

# Add project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Set test environment variables BEFORE importing app
os.environ["MONGO_URI"] = "mongodb://localhost:27017/test"
os.environ["DATABASE_URL"] = "sqlite:///./test.db"
os.environ["SECRET_KEY"] = "test_secret_key_for_testing_only"
os.environ["FIREBASE_CREDENTIALS_JSON"] = '{"type": "service_account", "project_id": "test"}'

# Mock external services before importing app
mock_firebase_app = MagicMock()
mock_motor_client = MagicMock()
mock_mongo_collection = AsyncMock()

# Create a mock engine that doesn't try to connect
mock_engine = MagicMock()
mock_metadata = MagicMock()
mock_metadata.create_all = MagicMock()  # Mock the create_all method

# Patch all external dependencies
with patch("firebase_admin.initialize_app", return_value=mock_firebase_app), \
     patch("firebase_admin.credentials.Certificate", return_value=MagicMock()), \
     patch("motor.motor_asyncio.AsyncIOMotorClient", return_value=mock_motor_client), \
     patch("app.bars_and_restaurants.models.nosql_models.create_geo_index", new_callable=AsyncMock), \
     patch("app.database.engine", mock_engine):
    
    # Now it's safe to import app components
    from app.main import app
    from app.database import Base, database as app_database
    
    # Import all models to ensure their tables are registered with Base.metadata
    from app.auth.auth_models import User, Token, RefreshToken
    from app.auth.rbac_models import UserProfile, BarStaff, StaffInvitation

# Test database URL (use SQLite for testing)
TEST_DATABASE_URL = "sqlite+aiosqlite:///./test.db"

# Create test database engine (for sync operations like create_all/drop_all)
test_engine = create_engine(
    "sqlite:///./test.db",
    connect_args={"check_same_thread": False}
)

# Create test database (for async operations)
test_database = Database(TEST_DATABASE_URL)


@pytest.fixture(scope="session")
def event_loop() -> Generator:
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="function", autouse=True)
async def setup_database():
    """Create tables before each test and drop after."""
    # Create all tables
    Base.metadata.create_all(bind=test_engine)
    
    # Connect to test database
    await test_database.connect()
    
    yield
    
    # Disconnect and drop all tables
    await test_database.disconnect()
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    import app.database as db_module
    import app.auth.routes as auth_routes
    import app.auth.middleware as auth_middleware
    import app.auth.dependencies as auth_dependencies
    import app.auth.profile as profile_routes
    import app.auth.rbac_middleware as rbac_middleware
    import app.bars_and_restaurants.routes.bars as bars_routes
    import app.bars_and_restaurants.routes.bar_owners as bar_owners_routes
    import app.bars_and_restaurants.routes.orders as orders_routes
    import app.bars_and_restaurants.routes.menus as menus_routes
    import app.bars_and_restaurants.routes.cart as cart_routes
    import app.bars_and_restaurants.routes.wallet as wallet_routes
    
    original_db = db_module.database
    
    db_module.database = test_database
    auth_routes.database = test_database
    auth_middleware.database = test_database
    auth_dependencies.database = test_database
    profile_routes.database = test_database
    rbac_middleware.database = test_database
    bars_routes.database = test_database
    bar_owners_routes.database = test_database
    orders_routes.database = test_database
    menus_routes.database = test_database
    cart_routes.database = test_database
    wallet_routes.database = test_database
    
    # Patch new discounts service
    import app.bars_and_restaurants.services.discounts as discounts_service
    discounts_service.database = test_database
    
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    
    db_module.database = original_db
    auth_routes.database = original_db
    auth_middleware.database = original_db
    auth_dependencies.database = original_db
    profile_routes.database = original_db
    rbac_middleware.database = original_db
    bars_routes.database = original_db
    bar_owners_routes.database = original_db
    orders_routes.database = original_db
    menus_routes.database = original_db
    cart_routes.database = original_db
    wallet_routes.database = original_db
    discounts_service.database = original_db


@pytest.fixture
def mock_firebase_token():
    return {
        "uid": "test_firebase_uid_123",
        "phone_number": "+1234567890",
        "email": "test@example.com"
    }


@pytest.fixture
async def test_user_in_db(setup_database):
    from app.auth.auth_models import User
    user_data = {
        "firebase_uid": "test_firebase_uid_123",
        "phone_number": "+1234567890",
        "email": "test@example.com",
        "is_active": True
    }
    user_id = await test_database.execute(User.__table__.insert().values(**user_data))
    return {"id": user_id, **user_data}


@pytest.fixture
def auth_headers(test_user_in_db):
    token = create_test_token(test_user_in_db["id"])
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
async def auth_client(client: AsyncClient, test_user_in_db) -> AsyncGenerator[tuple, None]:
    token = create_test_token(test_user_in_db["id"])
    headers = {"Authorization": f"Bearer {token}"}
    yield client, headers, test_user_in_db


@pytest.fixture
def sample_user_data():
    """Sample user data for testing."""
    return {
        "firebase_uid": "test_firebase_uid_123",
        "phone_number": "+1234567890",
        "email": "test@example.com",
        "is_active": True
    }


@pytest.fixture
def sample_bar_data():
    return {
        "name": "Test Bar",
        "address": "123 Test Street",
        "phone_number": "+1234567890",
        "email": "bar@test.com",
        "owner_id": 1
    }


@pytest.fixture
async def test_bar_owner_in_db(setup_database):
    from app.bars_and_restaurants.models.relational_models import BarOwner
    import random
    owner_data = {
        "id": random.randint(1, 999999),
        "name": "Test Owner",
        "email": f"owner{random.randint(1,9999)}@test.com",
        "phone_number": "+1234567890"
    }
    await test_database.execute(BarOwner.__table__.insert().values(**owner_data))
    return owner_data


@pytest.fixture
async def test_bar_in_db(test_bar_owner_in_db):
    from app.bars_and_restaurants.models.relational_models import Bar
    bar_data = {
        "name": "Test Bar",
        "address": "123 Test Street",
        "phone_number": "+1234567890",
        "email": "bar@test.com",
        "owner_id": test_bar_owner_in_db["id"]
    }
    bar_id = await test_database.execute(Bar.__table__.insert().values(**bar_data))
    return {"id": bar_id, **bar_data}


@pytest.fixture
async def second_test_bar_in_db(test_bar_owner_in_db):
    from app.bars_and_restaurants.models.relational_models import Bar
    bar_data = {
        "name": "Second Test Bar",
        "address": "456 Other Street",
        "phone_number": "+9876543210",
        "email": "bar2@test.com",
        "owner_id": test_bar_owner_in_db["id"]
    }
    bar_id = await test_database.execute(Bar.__table__.insert().values(**bar_data))
    return {"id": bar_id, **bar_data}


@pytest.fixture
async def test_order_in_db(test_user_in_db, test_bar_in_db):
    from app.bars_and_restaurants.models.relational_models import Order
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)
    order_data = {
        "user_id": test_user_in_db["id"],
        "bar_id": test_bar_in_db["id"],
        "status": "pending",
        "total_price": 25.00,
        "subtotal": 20.00,
        "tax": 5.00,
        "order_type": "pickup",
        "payment_method": "credit_card",
        "created_at": now,
        "updated_at": now
    }
    order_id = await test_database.execute(Order.__table__.insert().values(**order_data))
    return {"id": order_id, **order_data}


@pytest.fixture
async def test_completed_order_in_db(test_user_in_db, test_bar_in_db):
    from app.bars_and_restaurants.models.relational_models import Order
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)
    order_data = {
        "user_id": test_user_in_db["id"],
        "bar_id": test_bar_in_db["id"],
        "status": "completed",
        "total_price": 25.00,
        "created_at": now,
        "updated_at": now
    }
    order_id = await test_database.execute(Order.__table__.insert().values(**order_data))
    return {"id": order_id, **order_data}


@pytest.fixture
def sample_google_login():
    return {
        "id_token": "mock_google_id_token_123",
        "email": "google@test.com",
        "display_name": "Google User"
    }


@pytest.fixture
def sample_apple_login():
    return {
        "id_token": "mock_apple_id_token_123",
        "email": "apple@test.com",
        "display_name": "Apple User"
    }


@pytest.fixture
def mock_payment_gateway():
    """Mock payment gateway for testing."""
    class MockPaymentGateway:
        def create_charge(self, amount: float, currency: str, **kwargs):
            return {
                "status": "success",
                "payment_intent_id": "test_payment_intent_123",
                "client_secret": "test_client_secret"
            }
        
        def refund_charge(self, charge_id=None, payment_intent_id=None, amount=None):
            return {
                "status": "success",
                "refund_id": "test_refund_123",
                "amount_refunded": amount or 1000
            }
    
    return MockPaymentGateway()


# Helper function to create a JWT token for testing
def create_test_token(user_id: int) -> str:
    """Create a JWT token for testing authenticated endpoints."""
    from datetime import datetime, timedelta, timezone
    from jose import jwt
    
    SECRET_KEY = os.getenv("SECRET_KEY", "test-secret-key")
    ALGORITHM = "HS256"
    
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=60)
    
    to_encode = {
        "sub": str(user_id),
        "exp": expire,
        "iat": now,
        "type": "access"
    }
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


# ============== Wallet Test Fixtures ==============

@pytest.fixture
def db_session():
    """Create a synchronous database session for wallet tests."""
    session = sessionmaker(bind=test_engine)()
    yield session
    session.rollback()
    session.close()


@pytest.fixture
def test_user(db_session):
    """Create a test user for wallet tests."""
    from app.auth.auth_models import User
    
    user = User(
        firebase_uid="test_wallet_user_123",
        phone_number="+1234567890",
        email="wallet_test@example.com",
        is_active=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
async def test_menu_in_db(test_bar_in_db):
    from app.bars_and_restaurants.models.relational_models import Menu
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)
    menu_data = {
        "name": "Test Menu",
        "bar_id": test_bar_in_db["id"],
        "created_at": now,
        "updated_at": now
    }
    menu_id = await test_database.execute(Menu.__table__.insert().values(**menu_data))
    return {"id": menu_id, **menu_data}


@pytest.fixture
def test_bar(db_session):
    from app.bars_and_restaurants.models.relational_models import Bar, BarOwner
    
    # Create bar owner first
    owner = BarOwner(
        name="Test Owner",
        email="owner@test.com",
        phone_number="+1234567890"
    )
    db_session.add(owner)
    db_session.commit()
    db_session.refresh(owner)
    
    # Create bar
    bar = Bar(
        name="Test Wallet Bar",
        address="123 Test St",
        phone_number="+1234567890",
        email="bar@test.com",
        owner_id=owner.id
    )
    db_session.add(bar)
    db_session.commit()
    db_session.refresh(bar)
    return bar


@pytest.fixture
def test_order(db_session, test_user, test_bar):
    """Create a test order for wallet tests."""
    from app.bars_and_restaurants.models.relational_models import Order
    from datetime import datetime, timezone
    
    order = Order(
        user_id=test_user.id,
        bar_id=test_bar.id,
        status="completed",
        total_price=100.0,
        subtotal=90.0,
        tax=10.0,
        payment_status="paid",
        order_type="dine_in",
        created_at=datetime.now(timezone.utc)
    )
    db_session.add(order)
    db_session.commit()
    db_session.refresh(order)
    return order
