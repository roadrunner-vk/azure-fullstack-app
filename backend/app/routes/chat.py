import logging

from fastapi import APIRouter, HTTPException
from openai import AsyncAzureOpenAI
from pydantic import BaseModel

from app.config import AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_KEY, AZURE_OPENAI_DEPLOYMENT

logger = logging.getLogger(__name__)

router = APIRouter()

_client: AsyncAzureOpenAI | None = None


def _get_client() -> AsyncAzureOpenAI:
    global _client
    if _client is None:
        _client = AsyncAzureOpenAI(
            api_key=AZURE_OPENAI_KEY,
            api_version="2024-06-01",
            azure_endpoint=AZURE_OPENAI_ENDPOINT,
        )
    return _client


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]


class ChatResponse(BaseModel):
    reply: str


@router.post("/", response_model=ChatResponse)
async def chat(req: ChatRequest):
    if not AZURE_OPENAI_KEY or not AZURE_OPENAI_ENDPOINT:
        raise HTTPException(status_code=503, detail="Azure OpenAI not configured")

    try:
        client = _get_client()

        messages = [{"role": "system", "content": "You are a helpful assistant."}]
        messages += [{"role": m.role, "content": m.content} for m in req.messages]

        response = await client.chat.completions.create(
            model=AZURE_OPENAI_DEPLOYMENT,
            messages=messages,
            max_tokens=1000,
            temperature=0.7,
        )

        return ChatResponse(reply=response.choices[0].message.content)
    except Exception as e:
        logger.exception("Chat endpoint error")
        raise HTTPException(status_code=502, detail=str(e))
