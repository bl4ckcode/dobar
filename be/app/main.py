from .database import engine, Base, database
from fastapi import FastAPI
from .auth.routes import router
from contextlib import asynccontextmanager
from firebase_admin import auth, initialize_app, credentials

# Initialize Firebase Admin SDK
cred = credentials.Certificate("/Users/carlosalves/Documents/PDev/barz777-firebase-adminsdk-1daez-49a9bc4a0e.json")
initialize_app(cred)

Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect()
    yield
    await database.disconnect()

app = FastAPI(lifespan=lifespan)
# Include the router
app.include_router(router, prefix="/auth")