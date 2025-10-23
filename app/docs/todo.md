# TODO
Add tests for adding and deleting items from the database. we should be able to do
SqliteException(1): while preparing statment, no such table: changes, SQL logic error
code 1.
causing statment:
intert into "changes" ("id", "table_name", "row_id", "operation", "payload_json", "udpated_at"
, "created_at", "is_pushed") ...

We should have unit tests for every single funciton in the code so that if we
make any changes to anything including database then we can see when functionality
breaks. We should have seen this error in a test case before seeing the bug in prod.