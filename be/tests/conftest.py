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
    """Create a test client for making requests."""
    # Import and replace the database at runtime
    import app.database as db_module
    import app.auth.routes as auth_routes
    import app.bars_and_restaurants.routes.bars as bars_routes
    import app.bars_and_restaurants.routes.orders as orders_routes
    import app.bars_and_restaurants.routes.menus as menus_routes
    
    # Store original database
    original_db = db_module.database
    
    # Replace with test database globally
    db_module.database = test_database
    auth_routes.database = test_database
    bars_routes.database = test_database
    orders_routes.database = test_database
    menus_routes.database = test_database
    
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    
    # Restore original database
    db_module.database = original_db
    auth_routes.database = original_db
    bars_routes.database = original_db
    orders_routes.database = original_db
    menus_routes.database = original_db


@pytest.fixture
def mock_firebase_token():
    """Mock Firebase token for testing authentication."""
    return {
        "uid": "test_firebase_uid_123",
        "phone_number": "+1234567890",
        "email": "test@example.com"
    }


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
    """Sample bar data for testing."""
    return {
        "name": "Test Bar",
        "address": "123 Test Street",
        "phone_number": "+1234567890",
        "email": "bar@test.com",
        "owner_id": 1,
        "latitude": 40.7128,
        "longitude": -74.0060
    }


@pytest.fixture
def sample_google_login():
    """Sample Google login data for testing."""
    return {
        "email": "google@test.com",
        "google_id": "google_test_id_123"
    }


@pytest.fixture
def sample_apple_login():
    """Sample Apple login data for testing."""
    return {
        "email": "apple@test.com",
        "apple_id": "apple_test_id_123"
    }


@pytest.fixture
def sample_facebook_login():
    """Sample Facebook login data for testing."""
    return {
        "email": "facebook@test.com",
        "facebook_id": "facebook_test_id_123"
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
    
    to_encode = {"sub": str(user_id)}
    expire = datetime.now(timezone.utc) + timedelta(minutes=360)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


# ============== Wallet Test Fixtures ==============

@pytest.fixture
def db_session():
    """Create a synchronous database session for wallet tests."""
    from sqlalchemy.orm import Session
    
    session = sessionmaker(bind=test_engine)(class_=Session)
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
def test_bar(db_session):
    """Create a test bar for wallet tests."""
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
