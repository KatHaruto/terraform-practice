from sqlmodel import SQLModel, create_engine, Field, Session
from pathlib import Path


class User(SQLModel, table=True):
    __tablename__ = "users"
    id: int = Field(primary_key=True)
    name: str
    age: int
    email: str


class Item(SQLModel, table=True):
    __tablename__ = "items"
    id: int = Field(primary_key=True)
    name: str
    price: int


class Order(SQLModel, table=True):
    __tablename__ = "orders"
    id: int = Field(primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    item_id: int = Field(foreign_key="items.id")
    quantity: int


# Create the database engine
engine = create_engine("postgresql://postgres:password@localhost:10432/postgres")

seed_data_paths = [
    (User, Path("data/seed_user.csv")),
    (Item, Path("data/seed_item.csv")),
    (Order, Path("data/seed_order.csv")),
]

with Session(engine) as session:
    for data_class, seed_data_path in seed_data_paths:
        with open(seed_data_path) as file:
            lines = file.readlines()
            header = lines[0].strip().split(",")
            for line in lines[1:]:
                data = line.strip().split(",")
                data_instance = data_class(**dict(zip(header, data)))
                session.add(data_instance)
            session.commit()
print('done')