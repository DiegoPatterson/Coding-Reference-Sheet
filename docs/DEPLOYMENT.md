# CodeReference / CodeDex Deployment Guide

This guide explains how to set up the full system (PostgreSQL `CodeReferenceDB` + Flask backend + web frontend) so the search engine works against **your** `CodeReferenceDB` database server.

It is the "proper" sequence that was used when the DB-backed version was first made to work.

---

## 1. Prerequisites

- **PostgreSQL** (server can be local or remote). The project was tested with PostgreSQL 18.
- **Python 3.12+**
- A clone / checkout of this directory:
  ```
  /home/diego/Documents/Programs/Coding Practice/CodeReference
  ```
- (Optional but recommended) A dedicated Postgres user/role for the app (the examples below use the `diego` role that matches the OS user for peer auth).

Verify Postgres is reachable:

```bash
psql --version
psql -c "SELECT version();"
```

---

## 2. Create the `CodeReferenceDB` Database

### Local Postgres (common dev case, peer auth)

```bash
createdb CodeReferenceDB
```

If your `diego` role does not have `CREATEDB` privilege or you are using a different user:

```bash
sudo -u postgres psql -c "CREATE DATABASE CodeReferenceDB OWNER diego;"
# or
sudo -u postgres createdb -O diego CodeReferenceDB
```

### Remote / Dedicated DB Server

```bash
# From your machine, or run on the DB host
psql -h db.example.com -U postgres -c "CREATE DATABASE CodeReferenceDB OWNER appuser;"
```

Make sure `pg_hba.conf` on the DB server allows your client IP / user, and that you have network connectivity (port 5432 open).

Store credentials safely (never commit passwords).

---

## 3. Initialize Schema and Seed Baseline Data

All SQL files are idempotent (use `IF NOT EXISTS`, `ON CONFLICT DO NOTHING`, upserts).

```bash
cd "/home/diego/Documents/Programs/Coding Practice/CodeReference"

# 1. Create the core tables (concepts, languages, snippets, tags, etc.)
psql -d CodeReferenceDB -f src/backend/queries/initialize_base.sql

# 2. Load shared baseline languages + tags (do these before concept seeds)
psql -d CodeReferenceDB -f src/backend/queries/postgres/load_language.sql
psql -d CodeReferenceDB -f src/backend/queries/python/load_language.sql

# 3. Seed the demo concepts (one per language group for now)
psql -d CodeReferenceDB -f src/backend/queries/postgres/statements/create_table.sql
psql -d CodeReferenceDB -f src/backend/queries/python/statements/print.sql
```

### Connecting to a non-local / non-default `CodeReferenceDB` server

Use the full connection options every time:

```bash
# Example for remote host + different user + password (password can also come from ~/.pgpass)
PGPASSWORD=yourpass psql -h db.internal -p 5432 -U appuser -d CodeReferenceDB \
  -f src/backend/queries/initialize_base.sql

# ... repeat for the other .sql files
```

Or set up a `~/.pgpass` file (chmod 600) for password-less `psql` invocations.

### Verify the database

```bash
psql -d CodeReferenceDB -c "\dt"
psql -d CodeReferenceDB -c "SELECT slug, title, concept_type FROM concepts ORDER BY title;"
psql -d CodeReferenceDB -c "SELECT code, display_name FROM languages ORDER BY code;"
psql -d CodeReferenceDB -c "SELECT count(*) AS snippets FROM snippets;"
```

You should see the two demo concepts and the baseline languages.

---

## 4. Python Virtual Environment & Dependencies

```bash
cd "/home/diego/Documents/Programs/Coding Practice/CodeReference"

python3 -m venv .venv
source .venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt
```

This installs Flask and the binary psycopg driver needed to talk to Postgres.

---

## 5. Configure Connection to Your `CodeReferenceDB` Server

The backend defaults to the local `diego` setup:

```
dbname=CodeReferenceDB user=diego host=localhost
```

**For any other setup** (remote DB server, different user, password, non-standard port, cloud Postgres, etc.) set the environment variable **before** starting the server:

```bash
# Local alternative user/port
export CODEREF_DB_DSN="dbname=CodeReferenceDB user=appuser host=localhost port=5432"

# Remote with password (or use .pgpass + just host/user)
export CODEREF_DB_DSN="dbname=CodeReferenceDB user=appuser password=SuperSecret123 host=db.example.com port=5432"

# URI form also works
export CODEREF_DB_DSN="postgresql://appuser:pass@db.example.com:5432/CodeReferenceDB"
```

You can put the `export` line in your `~/.bashrc`, a project `.env` (sourced manually), or a systemd unit `Environment=` line.

The server prints the DSN it is using on startup so you can confirm.

---

## 6. Run the Backend + Frontend

```bash
cd "/home/diego/Documents/Programs/Coding Practice/CodeReference"
source .venv/bin/activate
# (optional) export CODEREF_DB_DSN=... as shown above

python src/backend/server.py
```

You should see:

```
CodeDex server starting...
  Frontend: .../src/frontend
  DB: dbname=CodeReferenceDB ...
  Open http://127.0.0.1:5000 ...
```

Open **http://127.0.0.1:5000** (use 127.0.0.1 not localhost in some browser / IPv6 situations).

The single process serves:
- the SPA at `/`
- the full JSON API at `/api/*`

Everything reads live from `CodeReferenceDB`.

### Running in the background

```bash
nohup python src/backend/server.py > /tmp/codedex.log 2>&1 &
echo $! > /tmp/codedex.pid
```

Tail the log to watch:

```bash
tail -f /tmp/codedex.log
```

Stop later with `kill $(cat /tmp/codedex.pid)`.

---

## 7. Using the Frontend Against a Separately Deployed API Server

If you want to run the Python API on one host/port and serve the static `index.html` from somewhere else (Live Server, another machine, file://, nginx, etc.):

1. In `src/frontend/index.html` change (or override via query string):

   ```js
   let API = 'http://127.0.0.1:5000';   // point at your API server
   ```

2. You can also do it at runtime without editing:

   ```
   http://your-frontend-host:8080/?api=http://your-api:5000
   ```

3. The provided server already sets very open CORS headers (`*`). If you write your own API server, make sure it allows the origin the HTML is loaded from.

See the main [README.md](../README.md) "Linking the Frontend to *Your Own Server*" section for the exact 5 endpoints the frontend expects.

---

## 8. Adding / Maintaining Data (Seeding New Concepts)

There is **no web UI for editing** yet. All data lives in `CodeReferenceDB` and is loaded via plain SQL scripts following a strict idempotent pattern.

### Recommended workflow

1. Pick a language directory under `src/backend/queries/` (or create e.g. `java/`).

2. Create a new file `.../statements/your_concept.sql` (copy `print.sql` or `create_table.sql` as template).

3. Inside the file:
   - Start with `BEGIN;`
   - Use a CTE `WITH concept_row AS ( INSERT INTO concepts ... ON CONFLICT (slug) DO UPDATE ... RETURNING id )`
   - Add `concept_lookup`, language lookup CTEs
   - Insert aliases into `concept_aliases` (with `is_primary`)
   - Link tags (tags must already exist — add them in a `load_language.sql` style file for that language or in the concept file itself with `ON CONFLICT`)
   - Insert one or more rows into `snippets` (you can have multiple per language/concept, different `snippet_kind`)
   - Optionally add `sources`
   - Record an entry in `import_runs`
   - End with `COMMIT;`
   - Finish with a few commented `SELECT` verification queries.

4. Run it:

   ```bash
   psql -d CodeReferenceDB -f src/backend/queries/python/statements/your_concept.sql
   ```

5. Refresh the web UI (or hard-reload) — the new concept should appear in search, browse, etc.

The `import_runs` table gives you an audit log of what was loaded and when.

---

## 9. Production / "Real Server" Deployment Notes

The current `server.py` is a development Flask server. It is fine for personal use and small teams.

For a more robust deployment:

- Use a production WSGI server:
  ```bash
  pip install gunicorn
  gunicorn -w 3 -b 0.0.0.0:5000 --access-logfile - 'src.backend.server:app'
  ```
  (You may need to adjust the import path or run from the project root with `PYTHONPATH=.`.)

- Put it behind a reverse proxy (nginx, Caddy, Traefik) that terminates TLS and forwards `/` and `/api/` .

- Use a proper connection pool (replace the simple `psycopg.connect` with `psycopg_pool.ConnectionPool`).

- Restrict CORS to the exact frontend origin(s) instead of `*`.

- Load `CODEREF_DB_DSN` from a secret manager / environment file that is not in git.

- Consider adding basic auth or an API key layer if the service is exposed beyond localhost.

- The frontend has no build step — it is a single `index.html` + CDN assets. You can serve the `src/frontend/` directory with any static file server.

---

## 10. Troubleshooting

- **"psycopg.OperationalError: connection to server ... failed"**  
  Check `CODEREF_DB_DSN`, that Postgres is listening, `pg_hba.conf`, firewall, and that the database actually exists (`psql -l`).

- **Concept not showing up after loading SQL**  
  Make sure you committed the transaction, that the language row exists, that `is_active = TRUE`, and hard-refresh the browser. Check `import_runs` and the `snippets` table directly.

- **CORS errors when serving frontend from another port**  
  The built-in server allows everything. Your custom server must send the `Access-Control-Allow-Origin` header.

- **Port 5000 already in use**  
  Either kill the previous process or change the `app.run(..., port=XXXX)` line (and update any `let API` or `?api=` overrides).

- **Tags not linking**  
  The tag `INSERT`s in concept files only succeed for tags that already exist in the `tags` table. Add missing tags first (see the `load_language.sql` files for the pattern).

---

## Quick "I Just Want It Running Again" Checklist

The easiest way is to use the helper script (it activates the venv, runs diagnostics, detects bad `CODEREF_DB_DSN` values, unsets them, and starts the server):

```bash
cd "/home/diego/Documents/Programs/Coding Practice/CodeReference"
./start_server.sh
# visit http://127.0.0.1:5000
```

For just a connectivity check without starting the server:

```bash
./start_server.sh --check-only
```

Manual version (if you prefer):

```bash
cd "/home/diego/Documents/Programs/Coding Practice/CodeReference"

# DB (only if you dropped/recreated it)
# psql -d CodeReferenceDB -f src/backend/queries/initialize_base.sql
# ... the other seeds ...

source .venv/bin/activate
unset CODEREF_DB_DSN   # or: export CODEREF_DB_DSN="dbname=CodeReferenceDB user=diego host=localhost"
python src/backend/server.py
# visit http://127.0.0.1:5000
```

See also the shorter Quick Start in the root [README.md](../README.md).

---

If you are pointing this at a completely separate `CodeReferenceDB` instance (different machine, different credentials, managed Postgres, etc.), the only thing you normally need to change is the value of the `CODEREF_DB_DSN` environment variable (and make sure the schema + seeds have been applied to that instance).

Happy referencing!
