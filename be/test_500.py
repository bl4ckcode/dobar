import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database import database

client = TestClient(app)

def test_timeline_500():
    # Find an order
    response = client.get("/health")
    print(response.json())

if __name__ == "__main__":
    test_timeline_500()
