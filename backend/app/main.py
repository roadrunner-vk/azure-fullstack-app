from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import close_db, connect_db
from app.routes.todos import router as todo_router
from app.routes.chat import router as chat_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    yield
    await close_db()


app = FastAPI(title="Todo API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://ca-frontend.ashyocean-77968f26.northeurope.azurecontainerapps.io",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
async def health():
    return {"status": "healthy"}


app.include_router(todo_router, prefix="/api/todos", tags=["todos"])
app.include_router(chat_router, prefix="/api/chat", tags=["chat"])
