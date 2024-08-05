
from fastapi import APIRouter, FastAPI
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
from enum import Enum
from pydantic import BaseModel

from app.json_logging import LoggingContextRoute

api_router = APIRouter()
api_router.route_class = LoggingContextRoute


class ItemType(str, Enum):
    BOOK = "book"
    FOOD = "food"
    ELECTRONICS = "electronics"


class Item(BaseModel):
    type: ItemType
    name: str
    id: int
    description: str | None = None
    price: float



@api_router.get("/health")
async def health_chekc():
    return {"message": "Everything is OK!"}

@api_router.get("/")
async def read_root():
    return {"Hello": "World"}


@api_router.get("/items/{item_id}")
async def read_item(item_id: int, q: str | None = None):
    dummy_item = Item(type=ItemType.BOOK, id=item_id, name="book", price=35.0)
    if item_id > 5:
        return JSONResponse(content=jsonable_encoder({"error": "item not found"}), status_code=404)
    return JSONResponse(content=jsonable_encoder(dummy_item), status_code=200)


app = FastAPI()
app.include_router(api_router)
