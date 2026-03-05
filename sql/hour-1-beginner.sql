-- ============================================================
-- SQL examples from: hour-1-beginner
-- ============================================================
-- -----------------------------------------------------
-- Slide 13: Step 5: Create Database and Load Bluebox
-- -----------------------------------------------------

CREATE DATABASE bluebox;
\c bluebox
CREATE EXTENSION postgis;


-- --------------------------------------
-- Slide 14: Step 6: Verify Your Setup
-- --------------------------------------

SELECT COUNT(*) FROM bluebox.film;


-- ----------------------
-- Slide 25: psql Tips
-- ----------------------

-- Edit in your favorite editor
\e

-- Run SQL from a file
\i /path/to/script.sql

-- Output to file
\o output.txt
SELECT * FROM film;
\o

-- Get help on SQL commands
\h CREATE TABLE


-- --------------------------------------
-- Slide 27: Expanded Display: \x auto
-- --------------------------------------

\x auto   -- Let psql decide (recommended!)
\x on     -- Always record
\x off    -- Always horizontal (default)


-- -----------------------------------
-- Slide 28: Pretty Unicode Borders
-- -----------------------------------

\pset linestyle unicode
\pset border 2


-- --------------------------------------
-- Slide 29: More Useful psql Settings
-- --------------------------------------

\timing              -- Show query execution time
\conninfo            -- Show current connection info
\pset pager off      -- Turn off page-by-page scrolling


-- ---------------------------------
-- Slide 30: Making NULLs Visible
-- ---------------------------------

\pset null '☘️'
SELECT title, budget FROM bluebox.film WHERE budget IS NULL LIMIT 3;


-- ---------------------------
-- Slide 32: Postgres Roles
-- ---------------------------

-- Create a user (role with login)
CREATE ROLE app_user WITH LOGIN PASSWORD 'secure_password';

-- Create a group (role without login)
CREATE ROLE readonly;


-- ----------------------------
-- Slide 33: Role Attributes
-- ----------------------------

CREATE ROLE app_user WITH 
  LOGIN 
  PASSWORD 'secure_password'
  CREATEDB 
  CREATEROLE;


-- -------------------------------------------------
-- Slide 34: ⚠️ Password Security: Don't Do This!
-- -------------------------------------------------

-- This works, BUT the password may be logged in plaintext!
CREATE ROLE app_user WITH PASSWORD 'secret123!' LOGIN;


-- ------------------------------------
-- Slide 36: Password Best Practices
-- ------------------------------------

-- Check if you have old MD5 passwords
SELECT rolname, rolpassword 
FROM pg_authid 
WHERE rolpassword LIKE 'md5%';


-- --------------------------------
-- Slide 37: Granting Privileges
-- --------------------------------

-- Grant connection to database
GRANT CONNECT ON DATABASE bluebox TO app_user;

-- Grant schema usage
GRANT USAGE ON SCHEMA bluebox TO app_user;

-- Grant table privileges
GRANT SELECT ON ALL TABLES IN SCHEMA bluebox TO app_user;

-- Grant specific privileges
GRANT SELECT, INSERT, UPDATE ON bluebox.rental TO app_user;


-- ------------------------------------------
-- Slide 38: Manage Privileges with Groups
-- ------------------------------------------

-- Create a group role for data analytics team
CREATE ROLE data_analytics NOLOGIN;

-- Grant read access on Bluebox to the group
GRANT CONNECT ON DATABASE bluebox TO data_analytics;
GRANT USAGE ON SCHEMA bluebox TO data_analytics;
GRANT SELECT ON ALL TABLES IN SCHEMA bluebox TO data_analytics;


-- ----------------------------------------
-- Slide 39: Grant Users Role Membership
-- ----------------------------------------

-- Create a user for an analyst
CREATE ROLE maria LOGIN;
\password maria

-- Add maria to the data_analytics group
GRANT data_analytics TO maria;

-- Maria now inherits all permissions from data_analytics!


-- ----------------------------------
-- Slide 40: View Role Memberships
-- ----------------------------------

\du


-- ---------------------------
-- Slide 43: Default Schema
-- ---------------------------

-- The default schema is 'public'
CREATE TABLE my_table (id int);

-- Same as:
CREATE TABLE public.my_table (id int);


-- -----------------------------
-- Slide 44: Creating Schemas
-- -----------------------------

-- Bluebox already has its schema, but you could create more:
CREATE SCHEMA reporting;

-- Then create tables in that schema
CREATE TABLE reporting.daily_stats (...);


-- -------------------------------
-- Slide 45: Schema Search Path
-- -------------------------------

-- View current search path
SHOW search_path;
-- Output: "$user", public

-- Set search path
SET search_path TO bluebox, public;

-- Now queries will look in bluebox first
SELECT * FROM film;  -- Same as bluebox.film


-- ---------------------------
-- Slide 46: Bluebox Schema
-- ---------------------------

SET search_path TO bluebox, public;
\dt


-- -----------------------------------
-- Slide 47: ALTER User Search Path
-- -----------------------------------

-- Set search path
ALTER USER maria SET search_path TO bluebox, public;

-- From next login, queries will look in bluebox first
SELECT * FROM film;  -- Same as bluebox.film


-- -------------------------------------
-- Slide 51: ⏰ Time: Use TIMESTAMPTZ!
-- -------------------------------------

-- TIMESTAMP: No timezone info (dangerous!)
CREATE TABLE events (event_time TIMESTAMP);

-- TIMESTAMPTZ: Stores in UTC, converts on display ✓
CREATE TABLE events (event_time TIMESTAMPTZ);

-- What time is it?
SELECT NOW();  -- 2026-01-16 10:30:00-08


-- --------------------------------------
-- Slide 52: 💰 Use NUMERIC, Not MONEY!
-- --------------------------------------

-- DON'T use the MONEY type
price MONEY  -- ❌ Locale-dependent, rounding issues

-- DO use NUMERIC for currency
price NUMERIC(10,2)  -- ✓ Exact precision, no surprises

SELECT amount FROM bluebox.payment LIMIT 3;


-- --------------------------------------
-- Slide 53: 🎯 Custom Data Types: ENUM
-- --------------------------------------

CREATE TYPE mpaa_rating AS ENUM (
    'G', 'PG', 'PG-13', 'R', 'NC-17', 'NR'
);

-- Used in the film table
SELECT title, rating FROM bluebox.film 
WHERE rating = 'PG-13' LIMIT 3;


-- -----------------------------
-- Slide 54: Creating a Table
-- -----------------------------

CREATE TABLE bluebox.customer_review (
    review_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES bluebox.customer(customer_id),
    film_id BIGINT REFERENCES bluebox.film(film_id),
    rating SMALLINT CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ---------------------------------------
-- Slide 55: Add Yourself as a Customer
-- ---------------------------------------

-- Add yourself to the Bluebox database
INSERT INTO bluebox.customer 
    (customer_id, store_id, full_name, email)
VALUES (
    (SELECT MAX(customer_id) + 1 FROM bluebox.customer),
    1,                          -- Store #1
    'Your Name Here',           -- Your name!
    'you@example.com'
)
RETURNING customer_id, full_name;


-- ---------------------------------
-- Slide 56: Find Films to Review
-- ---------------------------------

-- Find some popular films to review
SELECT film_id, title FROM bluebox.film 
WHERE title IN ('The Dark Knight', 'Inception', 
                'Interstellar', 'Dune: Part Two');


-- --------------------------------
-- Slide 57: Insert Your Reviews
-- --------------------------------

-- Use YOUR customer_id from the previous step!
INSERT INTO bluebox.customer_review 
    (customer_id, film_id, rating, review_text)
VALUES 
    (205026, 155, 5, 'Heath Ledger was incredible!'),
    (205026, 27205, 5, 'Mind-bending! Had to watch twice'),
    (205026, 693134, 5, 'Even better than the first Dune!');


-- ----------------------------------
-- Slide 58: Querying Your Reviews
-- ----------------------------------

-- See your reviews with a JOIN
SELECT c.full_name, f.title, r.rating, 
       LEFT(r.review_text, 30) as review
FROM bluebox.customer_review r
JOIN bluebox.customer c ON r.customer_id = c.customer_id
JOIN bluebox.film f ON r.film_id = f.film_id
ORDER BY r.created_at DESC;


-- ---------------------------
-- Slide 59: Bluebox Tables
-- ---------------------------

\d bluebox.film
