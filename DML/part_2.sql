-- 1. Create table ‘table_to_delete’ and fill it with the following query
CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;

-- 2. Lookup how much space this table consumes with the following query:
SELECT *, pg_size_pretty(total_bytes) AS total, 
pg_size_pretty(index_bytes) AS INDEX,
pg_size_pretty(toast_bytes) AS toast,
pg_size_pretty(table_bytes) AS TABLE
FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
FROM (SELECT c.oid,nspname AS table_schema, 
relname AS TABLE_NAME,
c.reltuples AS row_estimate,
pg_total_relation_size(c.oid) AS total_bytes,
pg_indexes_size(c.oid) AS index_bytes,
pg_total_relation_size(reltoastrelid) AS toast_bytes
FROM pg_class c
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE relkind = 'r'
) a
) a
WHERE table_name LIKE '%table_to_delete%';

--RESULT:
-- |oid   |table_schema|table_name     |row_estimate|total_bytes|index_bytes|toast_bytes|table_bytes|total |index  |toast     |table |
|------|------------|---------------|------------|-----------|-----------|-----------|-----------|------|-------|----------|------|
|18,228|public      |table_to_delete|-1          |602,415,104|0          |8,192      |602,406,912|575 MB|0 bytes|8192 bytes|575 MB|


-- 3. Issue the following DELETE operation on ‘table_to_delete’:
DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0;

-- a. Note how much time it takes to perform this DELETE statement
-- Execute time (ms)	11119

-- b. Lookup how much space this table consumes after previous DELETE;
SELECT *, pg_size_pretty(total_bytes) AS total, 
pg_size_pretty(index_bytes) AS INDEX,
pg_size_pretty(toast_bytes) AS toast,
pg_size_pretty(table_bytes) AS TABLE
FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
FROM (SELECT c.oid,nspname AS table_schema, 
relname AS TABLE_NAME,
c.reltuples AS row_estimate,
pg_total_relation_size(c.oid) AS total_bytes,
pg_indexes_size(c.oid) AS index_bytes,
pg_total_relation_size(reltoastrelid) AS toast_bytes
FROM pg_class c
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE relkind = 'r'
) a
) a
WHERE table_name LIKE '%table_to_delete%';

-- RESULT:
-- |oid   |table_schema|table_name     |row_estimate|total_bytes|index_bytes|toast_bytes|table_bytes|total |index  |toast     |table |
|------|------------|---------------|------------|-----------|-----------|-----------|-----------|------|-------|----------|------|
|18,233|public      |table_to_delete|-1          |602,431,488|0          |8,192      |602,423,296|575 MB|0 bytes|8192 bytes|575 MB|


-- c. Perform the following command (if you're using DBeaver, press Ctrl+Shift+O to observe server output (VACUUM results)):
VACUUM FULL VERBOSE table_to_delete;
-- Duration 4433 ms

-- d. Check space consumption of the table once again and make conclusions;
SELECT *, pg_size_pretty(total_bytes) AS total, 
pg_size_pretty(index_bytes) AS INDEX,
pg_size_pretty(toast_bytes) AS toast,
pg_size_pretty(table_bytes) AS TABLE
FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
FROM (SELECT c.oid,nspname AS table_schema, 
relname AS TABLE_NAME,
c.reltuples AS row_estimate,
pg_total_relation_size(c.oid) AS total_bytes,
pg_indexes_size(c.oid) AS index_bytes,
pg_total_relation_size(reltoastrelid) AS toast_bytes
FROM pg_class c
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE relkind = 'r'
) a
) a
WHERE table_name LIKE '%table_to_delete%';

--RESULT:
-- |oid   |table_schema|table_name     |row_estimate|total_bytes|index_bytes|toast_bytes|table_bytes|total |index  |toast     |table |
|------|------------|---------------|------------|-----------|-----------|-----------|-----------|------|-------|----------|------|
|18,233|public      |table_to_delete|6,666,667   |401,580,032|0          |8,192      |401,571,840|383 MB|0 bytes|8192 bytes|383 MB|

/* Conslusion: when we perform a DELETE operation on that table to remove 1/3 of all rows, the space consumed by the table will not decrease immediately. 
 * This is because in PostgreSQL when a row is deleted, it is only marked as "dead" but its space is not reclaimed immediately. 
 * Instead, the space is considered "free space" and can be used for future insertions.
 * When we then performed a VACUUM FULL operation on the table, this reclaims the space previously occupied by the deleted rows. 
 * So after the VACUUM FULL, the space consumed by the table was less than it was before the deletion. 
 * The space consumption will be lower by the size of deleted tuples.
 */

-- e. Recreate ‘table_to_delete’ table
DROP TABLE table_to_delete;

CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;

--4. Issue the following TRUNCATE operation:
TRUNCATE table_to_delete;
-- a. Note how much time it takes to perform this TRUNCATE statement.
-- Execute time (ms)	52

-- b. Compare with previous results and make conclusion.
/* Conslusion: when we issue a TRUNCATE statement on a table, it removes all data from the table quickly.
 *  It is much faster than using a DELETE statement because it does not generate any undo logs and it also does not fire any triggers. 
 * In addition, it releases all the space held by the table, so that the space can be reused.
 */

-- c. Check space consumption of the table once again and make conclusions;
SELECT *, pg_size_pretty(total_bytes) AS total, 
pg_size_pretty(index_bytes) AS INDEX,
pg_size_pretty(toast_bytes) AS toast,
pg_size_pretty(table_bytes) AS TABLE
FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
FROM (SELECT c.oid,nspname AS table_schema, 
relname AS TABLE_NAME,
c.reltuples AS row_estimate,
pg_total_relation_size(c.oid) AS total_bytes,
pg_indexes_size(c.oid) AS index_bytes,
pg_total_relation_size(reltoastrelid) AS toast_bytes
FROM pg_class c
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE relkind = 'r'
) a
) a
WHERE table_name LIKE '%table_to_delete%';

-- RESULT:
-- |oid   |table_schema|table_name     |row_estimate|total_bytes|index_bytes|toast_bytes|table_bytes|total     |index  |toast     |table  |
|------|------------|---------------|------------|-----------|-----------|-----------|-----------|----------|-------|----------|-------|
|18,220|public      |table_to_delete|0           |8,192      |0          |8,192      |0          |8192 bytes|0 bytes|8192 bytes|0 bytes|

/* Conslusion: the table size has been significantly reduced.
 * TRUNCATE statement also reset the table's statistics and makes a full vacuum of the table, which is a more efficient way 
 * of freeing space than using the VACUUM command.
 * Additionally, TRUNCATE is a DDL statement and it also resets the auto-increment value of SERIAL columns and also releases 
 * the table's resources like sequences, indexes, triggers and so on.
 */

