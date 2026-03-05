-- ============================================================
-- SQL examples from: hour-4-troubleshooting
-- ============================================================
-- ------------------------------
-- Slide 6: Exploring pg_class
-- ------------------------------

SELECT relname, relkind, reltuples::bigint as row_estimate
FROM pg_class
WHERE relnamespace = 'bluebox'::regnamespace
  AND relkind = 'r' ORDER BY reltuples DESC LIMIT 5;


-- ------------------------------------------------
-- Slide 7: pg\_stat\_activity - Active Sessions
-- ------------------------------------------------

SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    NOW() - query_start as query_duration,
    LEFT(query, 50) as query_preview
FROM pg_stat_activity
WHERE datname = 'bluebox'
  AND state != 'idle';


-- ----------------------------------
-- Slide 8: pg\_stat\_user\_tables
-- ----------------------------------

SELECT relname, n_live_tup, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname = 'bluebox' ORDER BY n_live_tup DESC LIMIT 5;


-- -----------------------------------
-- Slide 9: pg\_stat\_user\_indexes
-- -----------------------------------

SELECT relname, indexrelname, idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE schemaname = 'bluebox' ORDER BY idx_scan DESC LIMIT 5;


-- ----------------------------------------
-- Slide 10: pg_locks - Lock Information
-- ----------------------------------------

SELECT 
    l.pid,
    l.locktype,
    l.mode,
    l.granted,
    a.usename,
    a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE NOT l.granted;  -- Waiting locks


-- --------------------------------------
-- Slide 12: Find the Source of a Lock
-- --------------------------------------

WITH sos AS (
  SELECT array_cat(array_agg(pid),
    array_agg((pg_blocking_pids(pid))[array_length(pg_blocking_pids(pid),1)])) pids
  FROM pg_locks WHERE NOT granted
)
SELECT a.pid, a.usename, a.state,
   a.wait_event_type || ': ' || a.wait_event AS wait_event,
   current_timestamp-a.state_change time_in_state,
   l.relation::regclass relname, l.locktype, l.mode,
   pg_blocking_pids(l.pid) blocking_pids,
   (pg_blocking_pids(l.pid))[array_length(pg_blocking_pids(l.pid),1)] last_session,
   coalesce((pg_blocking_pids(l.pid))[1]||'.'||coalesce(
     case when locktype='transactionid' then 1 
     else array_length(pg_blocking_pids(l.pid),1)+1 end,0),
     a.pid||'.0') lock_depth,
   a.query
FROM pg_stat_activity a
JOIN sos s ON (a.pid = any(s.pids))
LEFT OUTER JOIN pg_locks l ON (a.pid = l.pid and not l.granted)
ORDER BY lock_depth;


-- -----------------------------------
-- Slide 15: Check Current Settings
-- -----------------------------------

-- See what's currently configured
SHOW logging_collector;   -- off by default!
SHOW log_destination;
SHOW log_statement;
SHOW log_min_duration_statement;


-- -------------------------------------
-- Slide 16: Enable Logging Collector
-- -------------------------------------

-- Enable the logging collector (writes to files)
ALTER SYSTEM SET logging_collector = 'on';

-- Configure where logs go (inside container)
ALTER SYSTEM SET log_directory = '/var/log/postgresql';
ALTER SYSTEM SET log_filename = 'postgresql.log';


-- --------------------------------
-- Slide 19: Log Severity Levels
-- --------------------------------

-- Default is WARNING - show current setting
SHOW log_min_messages;


-- -------------------------------
-- Slide 20: Log SQL Statements
-- -------------------------------

-- Turn on ALL statement logging temporarily
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();

-- Now run a query and watch your tail window!
SELECT title FROM bluebox.film LIMIT 3;


-- ------------------------------
-- Slide 21: See It in the Log
-- ------------------------------

-- Put it back to DDL only (recommended for production)
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();


-- ----------------------------
-- Slide 22: Log DDL Changes
-- ----------------------------

-- This WILL be logged
CREATE TABLE bluebox.log_test (id serial, name text);

-- This will NOT be logged (not DDL)
INSERT INTO bluebox.log_test (name) VALUES ('test');

-- This WILL be logged
DROP TABLE bluebox.log_test;


-- -----------------------------
-- Slide 23: Log Slow Queries
-- -----------------------------

-- Check current slow query threshold
SHOW log_min_duration_statement;

-- Lower it to catch queries > 100ms
ALTER SYSTEM SET log_min_duration_statement = '100ms';
SELECT pg_reload_conf();

-- This slow query will be logged with its duration
SELECT pg_sleep(0.2);


-- ---------------------------
-- Slide 24: Log SQL Errors
-- ---------------------------

-- Enable logging the statement that caused errors
ALTER SYSTEM SET log_min_error_statement = 'error';
SELECT pg_reload_conf();

-- Now cause an error
SELECT * FROM bluebox.nonexistent_table;


-- ----------------------------
-- Slide 25: Log Line Prefix
-- ----------------------------

ALTER SYSTEM SET log_line_prefix = '%m [%p] %h %u@%d ';
SELECT pg_reload_conf();


-- ---------------------------
-- Slide 26: Log Lock Waits
-- ---------------------------

-- Enable lock wait logging
ALTER SYSTEM SET log_lock_waits = 'on';
SELECT pg_reload_conf();


-- ---------------------------------
-- Slide 27: Simulate a Lock Wait
-- ---------------------------------

BEGIN;
UPDATE bluebox.film SET vote_average = vote_average 
WHERE film_id = 11;
-- Don't commit! Leave this open...

UPDATE bluebox.film SET vote_average = vote_average 
WHERE film_id = 11;


-- --------------------------------------------
-- Slide 28: pgAudit: Detailed Audit Logging
-- --------------------------------------------

-- Add to shared_preload_libraries, then:
CREATE EXTENSION pgaudit;

-- What to audit
ALTER SYSTEM SET pgaudit.log = 'ddl, write';
SELECT pg_reload_conf();


-- ------------------------------------
-- Slide 29: pgAudit: Example Output
-- ------------------------------------

CREATE TABLE bluebox.audit_test (id int);
DROP TABLE bluebox.audit_test;


-- -----------------------------------------
-- Slide 32: Finding Long-Running Queries
-- -----------------------------------------

SELECT 
    pid,
    NOW() - query_start as duration,
    usename,
    state,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start
LIMIT 10;


-- --------------------------------------
-- Slide 33: Finding Idle Transactions
-- --------------------------------------

-- Idle transactions can hold locks!
SELECT 
    pid,
    NOW() - xact_start as transaction_duration,
    NOW() - state_change as idle_duration,
    usename,
    query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND xact_start IS NOT NULL
ORDER BY xact_start;


-- ------------------------------------
-- Slide 34: Finding Blocked Queries
-- ------------------------------------

SELECT 
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks blocked_locks ON blocked.pid = blocked_locks.pid
JOIN pg_locks blocking_locks ON blocked_locks.locktype = blocking_locks.locktype
    AND blocked_locks.relation = blocking_locks.relation
    AND blocked_locks.pid != blocking_locks.pid
JOIN pg_stat_activity blocking ON blocking_locks.pid = blocking.pid
WHERE NOT blocked_locks.granted;


-- ------------------------------
-- Slide 35: Canceling a Query
-- ------------------------------

-- Cancel the current query (graceful)
SELECT pg_cancel_backend(12345);

-- Returns true if signal sent successfully


-- -------------------------------------
-- Slide 36: Terminating a Connection
-- -------------------------------------

-- Terminate the entire connection (forceful)
SELECT pg_terminate_backend(12345);

-- Terminate all connections to a database except our own
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'bluebox'
  AND pid != pg_backend_pid();


-- ------------------------------
-- Slide 37: Statement Timeout
-- ------------------------------

-- Set for session
SET statement_timeout = '30s';

-- Set for a single transaction
BEGIN;
SET LOCAL statement_timeout = '10s';
SELECT * FROM huge_table;  -- Will timeout after 10s
COMMIT;

-- Set per user
ALTER ROLE app_user SET statement_timeout = '60s';


-- -------------------------------------
-- Slide 38: Idle Transaction Timeout
-- -------------------------------------

-- postgresql.conf or per-session
idle_in_transaction_session_timeout = '10min'

-- Per user
ALTER ROLE app_user SET idle_in_transaction_session_timeout = '5min';


-- -------------------------
-- Slide 39: Lock Timeout
-- -------------------------

-- Set lock timeout
SET lock_timeout = '5s';

-- Now this will fail fast if table is locked
ALTER TABLE bluebox.rental ADD COLUMN new_col INT;

-- ERROR: canceling statement due to lock timeout


-- ---------------------------------
-- Slide 42: Key Metrics to Watch
-- ---------------------------------

-- Connection count
SELECT count(*) FROM pg_stat_activity;

-- Database size growth
SELECT pg_database_size('bluebox');

-- Transaction rate (per second)
SELECT (xact_commit + xact_rollback) / extract(epoch from now() -  coalesce(stats_reset, 
(pg_catalog.pg_stat_file('base/' || datid || '/PG_VERSION')).modification)) AS tps
FROM pg_stat_database 
WHERE datname = 'bluebox';


-- ----------------------------
-- Slide 43: Cache Hit Ratio
-- ----------------------------

SELECT 
    datname,
    ROUND(
        blks_hit::numeric / NULLIF(blks_hit + blks_read, 0) * 100, 
        2
    ) as cache_hit_ratio
FROM pg_stat_database
WHERE datname = 'bluebox';

-- Should be > 99% for OLTP workloads


-- --------------------------------------
-- Slide 45: Simple Health Check Query
-- --------------------------------------

SELECT 
    'connections' as metric, 
    count(*)::text as value 
FROM pg_stat_activity
UNION ALL
SELECT 
    'database_size', 
    pg_size_pretty(pg_database_size('bluebox'))
UNION ALL
SELECT 
    'active_queries', 
    count(*)::text 
FROM pg_stat_activity 
WHERE state = 'active'
UNION ALL
SELECT 
    'oldest_transaction', 
    COALESCE(max(age(backend_xmin))::text, 'none')
FROM pg_stat_activity;
