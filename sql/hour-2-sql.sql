-- ============================================================
-- SQL examples from: hour-2-sql
-- ============================================================
-- ---------------------------------
-- Slide 4: SELECT - Reading Data
-- ---------------------------------

SELECT title, release_date, vote_average
FROM bluebox.film
WHERE release_date >= '2020-01-01'
ORDER BY vote_average DESC
LIMIT 5;


-- ----------------------------------
-- Slide 6: SELECT with Aggregates
-- ----------------------------------

SELECT 
    EXTRACT(year FROM release_date) as release_year,
    COUNT(*) as film_count,
    ROUND(AVG(vote_average)::numeric, 2) as avg_rating
FROM bluebox.film
WHERE release_date IS NOT NULL
GROUP BY release_year
HAVING COUNT(*) > 100
ORDER BY release_year DESC LIMIT 5;


-- ----------------------------------
-- Slide 7: INSERT - Creating Data
-- ----------------------------------

INSERT INTO bluebox.customer (
    customer_id, store_id, full_name, email, zip_code 
)
VALUES (
    999999, 1, 'Jane Smith', 'jane.smith@example.com', 90210
);


-- ----------------------------------------------------------
-- Slide 8: INSERT - What Happens Without Required Fields?
-- ----------------------------------------------------------

-- This looks simpler, but will it work?
INSERT INTO bluebox.customer (store_id, full_name, email)
VALUES (1, 'Bob Jones', 'bob@example.com');


-- ------------------------------------
-- Slide 10: UPDATE - Modifying Data
-- ------------------------------------

-- Update with conditions
UPDATE bluebox.customer
SET email = 'newemail@example.com'
WHERE customer_id = 100;

-- no such film id, so update does nothing
-- Update multiple columns
UPDATE bluebox.film
SET vote_average = 8.5
WHERE film_id = 550;


-- -----------------------------------
-- Slide 11: DELETE - Removing Data
-- -----------------------------------

-- This works! payment has no child tables referencing it
DELETE FROM bluebox.payment 
WHERE payment_id = 1
RETURNING *;

-- This fails! film has inventory rows referencing it
DELETE FROM bluebox.film 
WHERE film_id = 1472668;


-- ----------------------------------------------
-- Slide 12: DELETE - Working with Constraints
-- ----------------------------------------------

-- Option 1: Delete the referencing rows first
DELETE FROM bluebox.inventory WHERE film_id = 1472668;
DELETE FROM bluebox.film WHERE film_id = 1472668;

-- Option 2: Define FK with ON DELETE CASCADE (auto-deletes children)
ALTER TABLE bluebox.inventory 
DROP CONSTRAINT inventory_film_id_fkey,
ADD CONSTRAINT inventory_film_id_fkey 
    FOREIGN KEY (film_id) REFERENCES bluebox.film(film_id)
    ON DELETE CASCADE;

-- Now deleting a film removes its inventory automatically!
DELETE FROM bluebox.film WHERE film_id = 1472668;


-- ---------------------
-- Slide 14: Untitled
-- ---------------------

-- Required for WITHOUT OVERLAPS on non-range types
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Create a rental booking table
CREATE TABLE bluebox.rental_booking (
    booking_id SERIAL,
    film_id INT NOT NULL,
    rental_period DATERANGE NOT NULL,
    customer_id INT NOT NULL,
    PRIMARY KEY (film_id, rental_period WITHOUT OVERLAPS)
);

-- First booking succeeds
INSERT INTO rental_booking (film_id, rental_period, customer_id)
VALUES (1, '[2025-03-01, 2025-03-05)', 101);

-- Overlapping booking fails automatically!
INSERT INTO rental_booking (film_id, rental_period, customer_id)
VALUES (1, '[2025-03-03, 2025-03-07)', 102);
-- ERROR: conflicting key value violates exclusion constraint


-- -----------------------------
-- Slide 15: RETURNING Clause
-- -----------------------------

INSERT INTO bluebox.customer (customer_id, store_id, full_name, email)
VALUES (999998, 1, 'Charlie Wilson', 'charlie@example.com')
RETURNING customer_id, create_date;


-- --------------------------------------
-- Slide 16: RETURNING OLD/NEW (PG 18)
-- --------------------------------------

UPDATE bluebox.film 
SET vote_average = 8.6 
WHERE film_id = 155
RETURNING OLD.vote_average AS before, NEW.vote_average AS after, title;


-- ------------------------------------
-- Slide 17: UPSERT with ON CONFLICT
-- ------------------------------------

INSERT INTO bluebox.customer (customer_id, store_id, full_name, email)
VALUES (100, 1, 'Updated Name', 'updated@example.com')
ON CONFLICT (customer_id) 
DO UPDATE SET 
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email;


-- -----------------------
-- Slide 19: INNER JOIN
-- -----------------------

SELECT f.title, p.name as actor
FROM bluebox.film f
INNER JOIN bluebox.film_cast fc ON f.film_id = fc.film_id
INNER JOIN bluebox.person p ON fc.person_id = p.person_id
WHERE f.title = 'The Dark Knight'
LIMIT 3;


-- ----------------------
-- Slide 20: LEFT JOIN
-- ----------------------

-- Find films and their cast count (including films with no cast)
SELECT f.title, COUNT(fc.person_id) as cast_count
FROM bluebox.film f
LEFT JOIN bluebox.film_cast fc ON f.film_id = fc.film_id
GROUP BY f.film_id, f.title
ORDER BY cast_count DESC LIMIT 5;


-- -----------------------
-- Slide 21: RIGHT JOIN
-- -----------------------

-- Same query rewritten - RIGHT JOIN is rarely used
-- Most prefer to swap tables and use LEFT JOIN instead
SELECT f.title, COUNT(fc.person_id) as cast_count
FROM bluebox.film_cast fc
RIGHT JOIN bluebox.film f ON fc.film_id = f.film_id
GROUP BY f.film_id, f.title;


-- ----------------------------
-- Slide 22: FULL OUTER JOIN
-- ----------------------------

-- Find people who are actors OR crew (or both)
SELECT p.name,
    CASE WHEN fc.person_id IS NOT NULL THEN 'Actor' END as is_actor,
    CASE WHEN fcr.person_id IS NOT NULL THEN 'Crew' END as is_crew
FROM (SELECT DISTINCT person_id FROM bluebox.film_cast) fc
FULL OUTER JOIN (SELECT DISTINCT person_id FROM bluebox.film_crew) fcr 
    ON fc.person_id = fcr.person_id
JOIN bluebox.person p 
    ON p.person_id = COALESCE(fc.person_id, fcr.person_id)
ORDER BY p.name
;


-- ---------------------------
-- Slide 23: Multiple JOINs
-- ---------------------------

-- Find cast of The Dark Knight
-- film → film_cast → person (3 tables connected)
SELECT f.title, p.name as actor, fc.film_character
FROM bluebox.film f
JOIN bluebox.film_cast fc ON f.film_id = fc.film_id
JOIN bluebox.person p ON fc.person_id = p.person_id
WHERE f.title = 'The Dark Knight'
LIMIT 5;


-- ---------------------------------
-- Slide 25: Arrays in PostgreSQL
-- ---------------------------------

SELECT film_id, title, genre_ids 
FROM bluebox.film 
WHERE title = 'The Dark Knight';

-- What do these IDs mean? Check the film_genre table
SELECT genre_id, name FROM bluebox.film_genre 
WHERE genre_id IN (18, 28, 80, 53);


-- -------------------------------
-- Slide 26: Adding to an Array
-- -------------------------------

-- Add a genre to a film's array
UPDATE bluebox.film
SET genre_ids = genre_ids || ARRAY[9648]  -- Add Mystery
WHERE film_id = 155;

-- Alternative: array_append function
UPDATE bluebox.film
SET genre_ids = array_append(genre_ids, 9648)
WHERE film_id = 155;


-- ----------------------------
-- Slide 28: Querying Arrays
-- ----------------------------

-- Find Action films
-- = ANY() checks if value exists anywhere in the array
SELECT f.title
FROM bluebox.film f
JOIN bluebox.film_genre fg ON fg.genre_id = ANY(f.genre_ids)
WHERE fg.name = 'Action'
LIMIT 3;

-- Find films that are both Action AND Crime
-- @> checks if array contains ALL specified values
SELECT title FROM bluebox.film f
WHERE genre_ids @> ARRAY(
    SELECT genre_id FROM bluebox.film_genre 
    WHERE name IN ('Action', 'Crime')
) LIMIT 3;

-- Unnest: expand array to rows (list all genres for a film)
SELECT f.title, g.name as genre
FROM bluebox.film f, unnest(f.genre_ids) as gid
JOIN bluebox.film_genre g ON g.genre_id = gid
WHERE f.title = 'The Dark Knight';


-- -------------------------------
-- Slide 30: Working with JSONB
-- -------------------------------

-- Create table with JSONB
CREATE TABLE movie_metadata (
    movie_id INT PRIMARY KEY,
    data JSONB
);

-- Insert JSON data
INSERT INTO movie_metadata (movie_id, data)
VALUES (1, '{
    "director": "Christopher Nolan",
    "budget": 160000000,
    "awards": ["Oscar", "BAFTA"]
}');


[.column]

-- Different row, completely different structure - that's OK!
INSERT INTO movie_metadata (movie_id, data)
VALUES (2, '{
    "streaming": ["Netflix", "Hulu"],
    "runtime_minutes": 148,
    "has_sequel": true
}');


-- ---------------------------
-- Slide 32: Querying JSONB
-- ---------------------------

-- Extract value as text (most common)
SELECT data->>'director' as director
FROM movie_metadata;

-- Extract nested value (awards array, first item)
SELECT data->'awards'->>0 as first_award
FROM movie_metadata;

-- Check if key exists
SELECT * FROM movie_metadata
WHERE data ? 'budget';

-- Query by JSON value (containment)
SELECT * FROM movie_metadata
WHERE data @> '{"director": "Christopher Nolan"}';


-- ---------------------------
-- Slide 35: Running Totals
-- ---------------------------

SELECT 
    payment_date::date,
    amount,
    SUM(amount) OVER (
        ORDER BY payment_date
    ) as running_total
FROM bluebox.payment
WHERE customer_id = 53853
ORDER BY payment_date;


-- ------------------------------------------
-- Slide 36: LAG - Compare to Previous Row
-- ------------------------------------------

SELECT 
    payment_date::date,
    amount,
    LAG(amount) OVER (ORDER BY payment_date) as prev_amount,
    amount - LAG(amount) OVER (ORDER BY payment_date) as difference
FROM bluebox.payment
WHERE customer_id = 53853
ORDER BY payment_date;


-- ------------------------------
-- Slide 37: LEAD - Look Ahead
-- ------------------------------

SELECT 
    title,
    release_date,
    LEAD(title) OVER (ORDER BY release_date) as next_film,
    LEAD(release_date) OVER (ORDER BY release_date) as next_release
FROM bluebox.film
WHERE release_date >= '2023-01-01'
ORDER BY release_date
LIMIT 5;


-- ----------------------------------------------------
-- Slide 40: CTE: Calculate Once, Use Multiple Times
-- ----------------------------------------------------

WITH customer_totals AS (
    SELECT customer_id, SUM(amount) as total_spent
    FROM bluebox.payment
    GROUP BY customer_id
)
SELECT 
    c.full_name,
    ct.total_spent,
    ROUND((SELECT AVG(total_spent) FROM customer_totals), 2) as avg_spent
FROM customer_totals ct
JOIN bluebox.customer c ON ct.customer_id = c.customer_id
WHERE ct.total_spent > (SELECT AVG(total_spent) FROM customer_totals)
ORDER BY ct.total_spent DESC LIMIT 5;


-- --------------------------
-- Slide 41: Multiple CTEs
-- --------------------------

WITH 
yearly_stats AS (
    -- Step 1: Aggregate films by year
    SELECT EXTRACT(year FROM release_date)::int as year,
           COUNT(*) as film_count,
           ROUND(AVG(vote_average)::numeric, 2) as avg_rating
    FROM film
    WHERE release_date IS NOT NULL AND vote_average IS NOT NULL
    GROUP BY EXTRACT(year FROM release_date)
),
top_years AS (
    -- Step 2: Filter to busy years, rank by rating
    SELECT * FROM yearly_stats
    WHERE film_count > 50
    ORDER BY avg_rating DESC LIMIT 5
)
SELECT * FROM top_years;


-- -------------------------------------------------
-- Slide 43: Real-World Function: Return a Rental
-- -------------------------------------------------

CREATE OR REPLACE FUNCTION return_rental(p_rental_id BIGINT)
RETURNS TABLE (days_rented INT, late_fee NUMERIC, message TEXT) AS $$
DECLARE
    v_rental RECORD;
    v_days INT;
    v_fee NUMERIC := 0;
    v_max_days INT := 7;
    v_daily_fee NUMERIC := 1.50;
BEGIN
    SELECT * INTO v_rental FROM bluebox.rental WHERE rental_id = p_rental_id;
    IF NOT FOUND THEN
        RETURN QUERY SELECT 0, 0::NUMERIC, 'Rental not found'::TEXT;
        RETURN;
    END IF;
    
    v_days := EXTRACT(day FROM upper(v_rental.rental_period) 
                              - lower(v_rental.rental_period))::INT;
    IF v_days > v_max_days THEN
        v_fee := (v_days - v_max_days) * v_daily_fee;
    END IF;
    
    RETURN QUERY SELECT v_days, v_fee,
        CASE WHEN v_fee > 0 
             THEN format('Late fee: $%s for %s extra days', v_fee, v_days - v_max_days)
             ELSE 'Returned on time!' END;
END;
$$ LANGUAGE plpgsql;


-- -------------------------------
-- Slide 44: Using the Function
-- -------------------------------

-- Pass in a rental_id to check
SELECT * FROM return_rental(1);


-- ---------------------------------------------------
-- Slide 47: Method 1a: Pattern Matching with ILIKE
-- ---------------------------------------------------

-- Find all Spider-Man movies (case-insensitive)
SELECT title FROM bluebox.film 
WHERE title ILIKE '%spider%';


-- ---------------------------------------------------
-- Slide 48: Method 1b: Pattern Matching with regex
-- ---------------------------------------------------

-- Find all Spider-Man movies (case-insensitive)
SELECT title FROM bluebox.film 
WHERE title ~* 'spider-man';


-- ---------------------------------------
-- Slide 49: Method 2: Full-Text Search
-- ---------------------------------------

-- Bluebox has a pre-built 'fulltext' column (title + overview)
SELECT title FROM bluebox.film 
WHERE fulltext @@ to_tsquery('english', 'running');


-- ---------------------------------------
-- Slide 50: Full-Text Search Operators
-- ---------------------------------------

-- Use plainto_tsquery for natural language input
SELECT title FROM bluebox.film 
WHERE fulltext @@ plainto_tsquery('dark knight batman');


-- ----------------------------------------------
-- Slide 51: How Bluebox fulltext Column Works
-- ----------------------------------------------

-- This is how Bluebox defines it:
fulltext tsvector GENERATED ALWAYS AS (
    to_tsvector('english', 
        COALESCE(title, '') || ' ' || COALESCE(overview, '')
    )
) STORED;

-- Indexed with GIN for fast searches
CREATE INDEX film_fulltext_idx ON film USING gin(fulltext);


-- -----------------------------------------------
-- Slide 52: Method 3: Vector Search (Semantic)
-- -----------------------------------------------

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create a demo table with sample embeddings (3 dimensions)
CREATE TABLE movie_vectors (
    title TEXT,
    embedding vector(3)
);


-- ---------------------------------------
-- Slide 53: Vector Search: Sample Data
-- ---------------------------------------

-- Insert sample movies with fake embeddings
-- Similar movies have similar vectors
INSERT INTO movie_vectors VALUES
    ('The Dark Knight',    '[0.9, 0.1, 0.8]'),  -- Action/Dark
    ('Batman Begins',      '[0.85, 0.15, 0.75]'), -- Similar!
    ('Frozen',             '[0.1, 0.9, 0.2]'),  -- Family/Light
    ('Moana',              '[0.15, 0.85, 0.25]'), -- Similar!
    ('John Wick',          '[0.95, 0.05, 0.7]'); -- Action/Dark


-- --------------------------------------------------
-- Slide 54: Vector Search: Finding Similar Movies
-- --------------------------------------------------

-- Find movies similar to "The Dark Knight"
SELECT title, 
       embedding <-> '[0.9, 0.1, 0.8]' AS distance
FROM movie_vectors
ORDER BY distance
LIMIT 3;
