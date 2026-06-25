import traceback

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import close_db, connect_db, get_database
from app.routes.todos import router as todo_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    yield
    await close_db()


app = FastAPI(title="Todo API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
async def health():
    return {"status": "healthy"}


@app.get("/api/dbcheck")
async def dbcheck():
    try:
        db = get_database()
        result = await db.command("ping")
        return {"status": "connected", "ping": result}
    except Exception as e:
        return {"status": "error", "error": str(e), "trace": traceback.format_exc()}


app.include_router(todo_router, prefix="/api/todos", tags=["todos"])
