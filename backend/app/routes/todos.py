from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException

from app.database import get_database
from app.models import TodoCreate, TodoResponse, TodoUpdate

router = APIRouter()


def _doc_to_response(doc: dict) -> TodoResponse:
    return TodoResponse(
        id=str(doc["_id"]),
        title=doc["title"],
        description=doc.get("description", ""),
        due_date=doc.get("due_date"),
        completed=doc.get("completed", False),
        created_at=doc["created_at"],
    )


@router.get("/", response_model=list[TodoResponse])
async def list_todos():
    db = get_database()
    docs = await db.todos.find().sort("created_at", -1).to_list(100)
    return [_doc_to_response(d) for d in docs]


@router.post("/", response_model=TodoResponse, status_code=201)
async def create_todo(todo: TodoCreate):
    db = get_database()
    doc = {
        "title": todo.title,
        "description": todo.description,
        "due_date": todo.due_date,
        "completed": False,
        "created_at": datetime.now(timezone.utc),
    }
    result = await db.todos.insert_one(doc)
    doc["_id"] = result.inserted_id
    return _doc_to_response(doc)


@router.get("/{todo_id}", response_model=TodoResponse)
async def get_todo(todo_id: str):
    db = get_database()
    if not ObjectId.is_valid(todo_id):
        raise HTTPException(status_code=400, detail="Invalid ID format")
    doc = await db.todos.find_one({"_id": ObjectId(todo_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Todo not found")
    return _doc_to_response(doc)


@router.patch("/{todo_id}", response_model=TodoResponse)
async def update_todo(todo_id: str, update: TodoUpdate):
    db = get_database()
    if not ObjectId.is_valid(todo_id):
        raise HTTPException(status_code=400, detail="Invalid ID format")
    changes = {k: v for k, v in update.model_dump().items() if v is not None}
    if not changes:
        raise HTTPException(status_code=400, detail="No fields to update")
    result = await db.todos.update_one(
        {"_id": ObjectId(todo_id)}, {"$set": changes}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Todo not found")
    doc = await db.todos.find_one({"_id": ObjectId(todo_id)})
    return _doc_to_response(doc)


@router.delete("/{todo_id}", status_code=204)
async def delete_todo(todo_id: str):
    db = get_database()
    if not ObjectId.is_valid(todo_id):
        raise HTTPException(status_code=400, detail="Invalid ID format")
    result = await db.todos.delete_one({"_id": ObjectId(todo_id)})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Todo not found")
