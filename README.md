# PostgreSQL Full Day Training

A comprehensive, open source training curriculum for PostgreSQL—from absolute beginner to production-ready in one day.

## What is this?

This repository contains all materials for a 6-8 hour PostgreSQL training workshop:

- **Hour 1:** PostgreSQL for the Absolute Beginner (includes setup)
- **Hour 2:** Getting Started with SQL in Postgres
- **Hour 3:** Postgres DBA Basics
- **Hour 4:** Postgres Troubleshooting
- **Hour 5:** Configuration and Performance Tuning
- **Hour 6:** Query Tuning

The training uses [Bluebox](https://github.com/ryanbooz/bluebox), a modern sample database with real TMDB movie data and PostGIS geography.

## Who is this for?

- Developers building applications with PostgreSQL
- DBAs transitioning from other database platforms
- DevOps/SRE engineers managing Postgres infrastructure
- Anyone curious about PostgreSQL

**Prerequisites:** Basic SQL familiarity helpful but not required.

## Prerequisites

**Docker Desktop** - This is the only prerequisite.

- **Mac/Windows**: [docker.com/products/docker-desktop](https://docker.com/products/docker-desktop)
- **Linux**: Docker Engine + Docker Compose

```bash
# Verify Docker is installed
docker --version
docker compose version
```

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/Snowflake-Labs/postgres-full-day-training.git
cd postgres-full-day-training

# 2. Start PostgreSQL
docker compose up -d

# 3. Install a psql client (choose one)
# Mac:
brew install libpq
# Windows: Use pgAdmin or install PostgreSQL from postgresql.org
# Linux:
apt install postgresql-client

# 4. Connect and create database
psql postgresql://postgres:training@localhost:5432/postgres -c "CREATE DATABASE bluebox;"
psql postgresql://postgres:training@localhost:5432/bluebox -c "CREATE EXTENSION postgis;"

# 5. Load Bluebox data
curl -LO https://raw.githubusercontent.com/ryanbooz/bluebox/main/bluebox_schema.sql
curl -LO https://raw.githubusercontent.com/ryanbooz/bluebox/main/bluebox_data.sql.gz
gunzip bluebox_data.sql.gz
psql postgresql://postgres:training@localhost:5432/bluebox -f bluebox_schema.sql
psql postgresql://postgres:training@localhost:5432/bluebox -f bluebox_data.sql

# 6. Verify
psql postgresql://postgres:training@localhost:5432/bluebox -c "SELECT COUNT(*) FROM bluebox.film;"
# Should return: 7836
```

**Hour 1 includes detailed setup instructions** with multiple psql client options.

## Markdown Format

Slides are written in Markdown for [Deckset](https://www.deckset.com/) (macOS) or another markdown-to-slide program. They can also be viewed as plain Markdown or converted to other formats.

## Repository Structure

```
├── hour-1-beginner.md        # Slides: PostgreSQL fundamentals + setup
├── hour-2-sql.md             # Slides: SQL in Postgres
├── hour-3-dba.md             # Slides: DBA basics
├── hour-4-troubleshooting.md # Slides: Troubleshooting
├── hour-5-performance.md     # Slides: Performance tuning
├── hour-6-query-tuning.md    # Slides: Query optimization
├── docker-compose.yml        # Docker configuration
├── diagrams/                 # Images and diagrams
├── slides/                   # PDF versions of the markdown
├── dependencies.md           # Software dependencies
└── add_slide_numbers.py      # Utility script to renumber slides if things are added/removed
```

## Running the Training

### For Instructors

1. Open the hour-*.md files in Deckset or similar
2. Ensure Docker is running with the Bluebox database loaded
3. Have a terminal ready for live demos

### For Self-Study

1. Follow the Quick Start to set up the database
2. Read through the slides in order
3. Run the SQL examples as you go

## Topics Covered

| Hour | Topics |
|------|--------|
| 1 | Setup, psql, schemas, data types, constraints |
| 2 | CRUD, JOINs, arrays, JSONB, window functions, CTEs |
| 3 | Backups, WAL, replication, connection pooling, VACUUM |
| 4 | System catalogs, logging, locks, monitoring |
| 5 | Memory config, shared_buffers, parallel queries |
| 6 | EXPLAIN, indexes, pg_stat_statements, query patterns |

## PostgreSQL Version

This training targets **PostgreSQL 18** but is compatible with PostgreSQL 14+. Some features (like `RETURNING OLD/NEW` and `WITHOUT OVERLAPS`) require PostgreSQL 18.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Acknowledgments

- [Bluebox](https://github.com/ryanbooz/bluebox) sample database by Ryan Booz
- The PostgreSQL community
- [TMDB](https://www.themoviedb.org/) for movie data used in Bluebox

## Presentations

This training has been presented at:

- SCaLE 23x (2026) - Southern California Linux Expo

---

**Questions?** Open an issue or reach out to the maintainers.
