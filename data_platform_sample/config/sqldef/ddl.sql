create table users (
    id int primary key,
    name varchar(255),
    age int,
    email varchar(255)
);

create table items (
    id int primary key,
    name varchar(255),
    price int
);

create table orders (
    id int primary key,
    user_id int,
    item_id int,
    quantity int,
    constraint fk_user_id foreign key (user_id) references users(id),
    constraint fk_item_id foreign key (item_id) references items(id)
);

-- $ psqldef -h localhost -W <password> -p <port> -U <username>  <dbname> < config/sqldef/ddl.sql 