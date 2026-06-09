#!/usr/bin/env python3
"""
CodeDex backend server.
Flask + psycopg API for the Code Reference search engine frontend.
Serves the SPA at / and JSON API under /api/*
"""

import os
import psycopg
from psycopg.rows import dict_row
from flask import Flask, jsonify, request, send_from_directory, abort

# --- Config ---
# Override with env var to point at your CodeReferenceDB server (local, remote, different user/port/creds).
# Examples:
#   export CODEREF_DB_DSN="dbname=CodeReferenceDB user=diego host=localhost"
#   export CODEREF_DB_DSN="dbname=CodeReferenceDB user=myappuser password=secret host=localhost port=5432"
#   export CODEREF_DB_DSN="postgresql://myappuser:secret@db.internal:5432/CodeReferenceDB"
raw_dsn = os.environ.get("CODEREF_DB_DSN")
DB_DSN = raw_dsn if raw_dsn else "dbname=CodeReferenceDB user=diego host=localhost"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FRONTEND_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "frontend"))

app = Flask(__name__, static_folder=None)

# --- CORS for dev / linking frontend served separately ---
# This lets you run the HTML from any origin (different port, file:// via some tools,
# live-server on 8080/3000, etc.) and still talk to this API server.
@app.after_request
def add_cors_headers(resp):
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
    return resp

@app.route("/api/<path:_any>", methods=["OPTIONS"])
@app.route("/api", methods=["OPTIONS"])
def api_preflight(_any=None):
    """Handle CORS preflight quickly."""
    resp = app.make_response(("", 204))
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
    return resp

# Simple connection helper (no pool for prototype)
def get_conn():
    return psycopg.connect(DB_DSN, row_factory=dict_row)


# --- API Routes ---

@app.route("/api/languages", methods=["GET"])
def api_languages():
    """List all languages."""
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, code, display_name, runtime_kind, description
                FROM languages
                ORDER BY display_name
            """)
            rows = cur.fetchall()
    return jsonify(rows)


@app.route("/api/concepts", methods=["GET"])
def api_concepts():
    """List active concepts with optional filtering and pagination.

    Query params (all optional):
      q: text search in title, description, concept_type
      type: filter by concept_type (can be repeated: ?type=syntax&type=ddl or comma-separated)
      limit: page size (default 20, max 100)
      offset: pagination offset (default 0)
    """
    q = (request.args.get("q") or "").strip().lower()
    type_filters = request.args.getlist("type")
    if not type_filters:
        # support comma-separated too: ?type=syntax,ddl
        raw = (request.args.get("type") or "").strip()
        if raw:
            type_filters = [t.strip() for t in raw.split(",") if t.strip()]

    try:
        limit = max(1, min(int(request.args.get("limit", 20)), 100))
    except (TypeError, ValueError):
        limit = 20
    try:
        offset = max(0, int(request.args.get("offset", 0)))
    except (TypeError, ValueError):
        offset = 0

    with get_conn() as conn:
        with conn.cursor() as cur:
            where_clauses = ["c.is_active = TRUE"]
            params = []

            if q:
                where_clauses.append("(LOWER(c.title) LIKE %s OR LOWER(c.description) LIKE %s OR LOWER(c.concept_type) LIKE %s)")
                like = f"%{q}%"
                params.extend([like, like, like])

            if type_filters:
                placeholders = ",".join(["%s"] * len(type_filters))
                where_clauses.append(f"c.concept_type IN ({placeholders})")
                params.extend(type_filters)

            where_sql = " AND ".join(where_clauses)

            # total count for the current filter (for UI "X of Y")
            cur.execute(f"""
                SELECT COUNT(*) AS total
                FROM concepts c
                WHERE {where_sql}
            """, params)
            total = cur.fetchone()["total"]

            # page of results
            cur.execute(f"""
                SELECT c.id, c.slug, c.title, c.concept_type, c.description
                FROM concepts c
                WHERE {where_sql}
                ORDER BY c.title
                LIMIT %s OFFSET %s
            """, params + [limit, offset])
            concepts = cur.fetchall()

            # Enrich each with available language codes
            for c in concepts:
                cur.execute("""
                    SELECT DISTINCT l.code, l.display_name
                    FROM snippets s
                    JOIN languages l ON l.id = s.language_id
                    WHERE s.concept_id = %s
                    ORDER BY l.display_name
                """, (c["id"],))
                c["available_langs"] = cur.fetchall()

    return jsonify({
        "items": concepts,
        "total": total,
        "limit": limit,
        "offset": offset
    })


@app.route("/api/search", methods=["GET"])
def api_search():
    """
    Search concepts by q (matches alias, title, desc, concept_type, tag name).
    Optional ?lang=code to filter to concepts that have a snippet in that language.
    Returns lightweight results suitable for autocomplete/suggestions.
    """
    q = (request.args.get("q") or "").strip()
    lang_filter = (request.args.get("lang") or "").strip().lower() or None

    if not q:
        return jsonify([])

    like = f"%{q}%"
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT DISTINCT
                    c.id,
                    c.slug,
                    c.title,
                    c.concept_type,
                    c.description
                FROM concepts c
                LEFT JOIN concept_aliases ca ON ca.concept_id = c.id
                LEFT JOIN concept_tags ct ON ct.concept_id = c.id
                LEFT JOIN tags t ON t.id = ct.tag_id
                WHERE c.is_active = TRUE
                  AND (
                        ca.alias ILIKE %s
                     OR c.title ILIKE %s
                     OR c.description ILIKE %s
                     OR COALESCE(c.concept_type, '') ILIKE %s
                     OR COALESCE(t.name, '') ILIKE %s
                  )
                ORDER BY c.title
                LIMIT 12
            """, (like, like, like, like, like))
            matches = cur.fetchall()

            # Enrich + optional lang filter
            results = []
            for c in matches:
                cur.execute("""
                    SELECT DISTINCT l.code, l.display_name
                    FROM snippets s
                    JOIN languages l ON l.id = s.language_id
                    WHERE s.concept_id = %s
                    ORDER BY l.display_name
                """, (c["id"],))
                langs = cur.fetchall()
                c["available_langs"] = langs

                if lang_filter:
                    if not any(l["code"] == lang_filter for l in langs):
                        continue
                results.append(c)

    return jsonify(results)


@app.route("/api/concept/<slug>", methods=["GET"])
def api_concept(slug):
    """Full details for one concept: metadata + all snippets across languages + aliases/tags."""
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, slug, title, concept_type, description, is_active
                FROM concepts
                WHERE slug = %s AND is_active = TRUE
            """, (slug,))
            concept = cur.fetchone()
            if not concept:
                abort(404, description="Concept not found")

            # aliases
            cur.execute("""
                SELECT alias, alias_kind, is_primary
                FROM concept_aliases
                WHERE concept_id = %s
                ORDER BY is_primary DESC, alias
            """, (concept["id"],))
            concept["aliases"] = cur.fetchall()

            # tags
            cur.execute("""
                SELECT t.name, t.tag_group
                FROM concept_tags ct
                JOIN tags t ON t.id = ct.tag_id
                WHERE ct.concept_id = %s
                ORDER BY t.name
            """, (concept["id"],))
            concept["tags"] = cur.fetchall()

            # snippets grouped by language
            cur.execute("""
                SELECT
                    l.id as language_id,
                    l.code,
                    l.display_name,
                    l.runtime_kind,
                    s.id as snippet_id,
                    s.snippet_kind,
                    s.content,
                    s.notes,
                    s.sort_order,
                    s.is_primary
                FROM snippets s
                JOIN languages l ON l.id = s.language_id
                WHERE s.concept_id = %s
                ORDER BY l.display_name, s.sort_order, s.is_primary DESC
            """, (concept["id"],))
            raw_snippets = cur.fetchall()

            # Group by language code (dedup same content if duplicates exist)
            langs_map = {}
            for s in raw_snippets:
                code = s["code"]
                if code not in langs_map:
                    langs_map[code] = {
                        "code": s["code"],
                        "display_name": s["display_name"],
                        "runtime_kind": s["runtime_kind"],
                        "snippets": []
                    }
                # simple dedup on content
                contents = {x["content"] for x in langs_map[code]["snippets"]}
                if s["content"] not in contents:
                    langs_map[code]["snippets"].append({
                        "kind": s["snippet_kind"],
                        "content": s["content"],
                        "notes": s["notes"],
                        "is_primary": s["is_primary"]
                    })

            concept["implementations"] = list(langs_map.values())

            # sources (optional)
            cur.execute("""
                SELECT source_type, source_uri, notes
                FROM sources
                WHERE concept_id = %s
                ORDER BY id
            """, (concept["id"],))
            concept["sources"] = cur.fetchall()

    return jsonify(concept)


@app.route("/api/browse", methods=["GET"])
def api_browse():
    """
    Hierarchical view: languages -> list of concepts (that have snippets in that lang).
    Used by the hamburger organization menu.
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, code, display_name FROM languages ORDER BY display_name")
            langs = cur.fetchall()

            for lang in langs:
                cur.execute("""
                    SELECT DISTINCT c.id, c.slug, c.title, c.concept_type
                    FROM snippets s
                    JOIN concepts c ON c.id = s.concept_id
                    WHERE s.language_id = %s AND c.is_active = TRUE
                    ORDER BY c.title
                """, (lang["id"],))
                lang["concepts"] = cur.fetchall()
    return jsonify(langs)


# --- Frontend serving ---

@app.route("/", methods=["GET"])
def serve_index():
    """Serve the search-engine SPA."""
    index_path = os.path.join(FRONTEND_DIR, "index.html")
    if not os.path.exists(index_path):
        return "Frontend not built yet. See src/frontend/index.html", 503
    return send_from_directory(FRONTEND_DIR, "index.html")


# Also allow direct asset access if we split later (css/js)
@app.route("/<path:filename>", methods=["GET"])
def serve_frontend_assets(filename):
    # Only serve known safe files from frontend dir (no traversal)
    if ".." in filename or filename.startswith("/"):
        abort(404)
    full = os.path.join(FRONTEND_DIR, filename)
    if os.path.isfile(full):
        return send_from_directory(FRONTEND_DIR, filename)
    # Fallback to index for SPA if needed (but we use hash or explicit)
    if filename.endswith((".js", ".css", ".ico", ".png", ".svg")):
        abort(404)
    return serve_index()


@app.errorhandler(404)
def not_found(e):
    if request.path.startswith("/api/"):
        return jsonify({"error": str(e)}), 404
    return serve_index(), 404


if __name__ == "__main__":
    print("CodeDex server starting...")
    print(f"  Frontend: {FRONTEND_DIR}")
    print(f"  DB: {DB_DSN}")
    print("  Open http://127.0.0.1:5000 (preferred) or http://localhost:5000")
    print("")

    # Early connectivity check so you get a clear error instead of 500s later
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT current_user, current_database()")
                who = cur.fetchone()
        print(f"  ✓ Database connection successful (connected as {who.get('current_user')} to {who.get('current_database')})")
    except Exception as e:
        print("  ✗ FATAL: Cannot connect to the database.")
        print(f"     DSN used: {DB_DSN}")
        print(f"     Error: {e}")
        print("")
        print("     Quick checks:")
        print("       1. psql -d CodeReferenceDB -c \"SELECT current_user, current_database();\"")
        print("       2. In the SAME terminal, run:   env | grep -i coderef")
        print("       3. Use the correct value, e.g.:")
        print("            export CODEREF_DB_DSN=\"dbname=CodeReferenceDB user=diego host=localhost\"")
        print("            # or simply:  unset CODEREF_DB_DSN")
        print("       4. Then: python src/backend/server.py")
        print("")
        print("     See docs/DEPLOYMENT.md for full troubleshooting.")
        import sys
        sys.exit(1)

    print("")
    print("  DB connection: set CODEREF_DB_DSN env var to target your CodeReferenceDB server")
    print("    (supports full libpq DSN or postgresql:// URI; defaults work for local 'diego' user).")
    print("")
    print("  To use the frontend with *your own server* instead:")
    print("    - Edit the `let API = '...'` line at the top of src/frontend/index.html")
    print("    - Or visit http://127.0.0.1:5000?api=http://your-server:port")
    print("    - CORS is enabled so you can serve the HTML from any port / live-server.")
    # use_reloader=False prevents double-start + file watcher noise during dev
    app.run(host="127.0.0.1", port=5000, debug=False, use_reloader=False)
