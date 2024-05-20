-- Test that the AO_AUX_ONLY option will vacuum ONLY auxiliary AO tables
-- create and switch to database
CREATE DATABASE vac_ao_aux;
\c vac_ao_aux

CREATE EXTENSION gp_inject_fault;

-- Test VACUUM AO_AUX_ONLY without providing a relation list
CREATE TABLE vac_example_heap(i int, j int) DISTRIBUTED BY (i);
INSERT INTO vac_example_heap SELECT j,j FROM generate_series(1, 1000000)j;

CREATE TABLE vac_example_ao(i int, j int) USING ao_row DISTRIBUTED BY (i);
INSERT INTO vac_example_ao SELECT j,j FROM generate_series(1, 1000000)j;

CREATE TABLE vac_example_ao2(i int, j int) USING ao_row DISTRIBUTED BY (i);
INSERT INTO vac_example_ao2 SELECT j,j FROM generate_series(1, 1000000)j;

-- set fault for ao visimap, triggered after vacuum completes on the relation
WITH tableNameCTE AS (
    SELECT c.relname
    FROM pg_appendonly pa, pg_class c
    WHERE pa.visimaprelid = c.oid AND pa.relid = 'vac_example_ao'::regclass
)
SELECT gp_inject_fault('vacuum_rel_finished_one_relation', 'skip', '', '', relname, 1, 1, 0, dbid)
FROM tableNameCTE, gp_segment_configuration WHERE role = 'p' AND content != -1;

-- generate bloat on ao aux table
BEGIN; DELETE FROM vac_example_ao WHERE j % 9 = 3; ABORT;

--generate bloat on main tables
DELETE FROM vac_example_heap;
DELETE FROM vac_example_ao2;

-- CALL VACUUM on all tables, but use option to target only AO auxiliary tables
VACUUM AO_AUX_ONLY;

--gp_select_invisible breaks injecting faults so be narrow with it
SET gp_select_invisible=true;
-- show that main tables are not vacuumed
SELECT count(*) FROM vac_example_heap;
SELECT count(*) FROM vac_example_ao2;
SET gp_select_invisible=false;

-- show that ao aux table has been vacuumed, causing fault to be triggered
SELECT gp_wait_until_triggered_fault('vacuum_rel_finished_one_relation', 1, dbid)
FROM gp_segment_configuration WHERE role = 'p' AND content != -1;

-- clean up fault
SELECT gp_inject_fault('vacuum_rel_finished_one_relation', 'reset', dbid)
FROM gp_segment_configuration WHERE role = 'p' AND content != -1;

-- clean up tables
DROP TABLE vac_example_heap;
DROP TABLE vac_example_ao;
DROP TABLE vac_example_ao2;


-- Test VACUUM AO_AUX_ONLY with a provided a relation list
-- Include partitions in a provided table
CREATE TABLE vac_example_heap(i int, j int) PARTITION BY range (j) DISTRIBUTED by (i);
CREATE TABLE vac_example_0_to_500000 PARTITION OF vac_example_heap
    FOR VALUES FROM (0) TO (500000)
    USING ao_row;
CREATE TABLE vac_example_500000_to_1000001 PARTITION OF vac_example_heap
    FOR VALUES FROM (500000) TO (1000001);
INSERT INTO vac_example_heap SELECT j,j FROM generate_series(1, 1000000)j;

CREATE TABLE vac_example_heap2 (i int, j int) DISTRIBUTED by (i);
INSERT INTO vac_example_heap2 SELECT j,j FROM generate_series(1, 1000000)j;

-- generate bloat on visimap for AO partition and example heap
BEGIN; DELETE FROM vac_example_heap WHERE j < 500000; ABORT;
DELETE FROM vac_example_heap2;

-- set fault for ao visimap, triggered after vacuum completes on the relation
WITH tableNameCTE AS (
    SELECT c.relname
    FROM pg_appendonly pa, pg_class c
    WHERE pa.visimaprelid = c.oid AND pa.relid = 'vac_example_0_to_500000'::regclass
)
SELECT gp_inject_fault('vacuum_rel_finished_one_relation', 'skip', '', '', relname, 1, 1, 0, dbid)
FROM tableNameCTE, gp_segment_configuration WHERE role = 'p' AND content != -1;

-- CALL VACUUM on list of tables, and use option to target only AO auxiliary tables
VACUUM AO_AUX_ONLY vac_example_heap, vac_example_heap2;

--gp_select_invisible breaks injecting faults so be narrow with it
SET gp_select_invisible=true;
-- show that main table is not vacuumed
SELECT count(*) FROM vac_example_heap;
SET gp_select_invisible=false;

-- show that ao aux table has been vacuumed, causing fault to be triggered
SELECT gp_wait_until_triggered_fault('vacuum_rel_finished_one_relation', 1, dbid)
FROM gp_segment_configuration WHERE role = 'p' AND content != -1;

-- clean up fault
SELECT gp_inject_fault('vacuum_rel_finished_one_relation', 'reset', dbid)
FROM gp_segment_configuration WHERE role = 'p' AND content != -1;


ALTER SYSTEM RESET autovacuum;
-- start_ignore
\! gpstop -u;
-- end_ignore

\c regression
DROP DATABASE vac_ao_aux;
