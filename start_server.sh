#!/usr/bin/env bash
#
# Helper to start the CodeDex server against your CodeReferenceDB.
# This ensures a clean environment (no leftover bad CODEREF_DB_DSN).
#
# Usage:
#   ./start_server.sh
#   ./start_server.sh --check-only     # just run diagnostics, don't start
#

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "=== CodeDex / CodeReferenceDB starter ==="
echo "Project: $PROJECT_DIR"
echo

# Activate venv if present
if [[ -f .venv/bin/activate ]]; then
    # shellcheck disable=SC1091
    source .venv/bin/activate
    echo "✓ Activated .venv"
else
    echo "⚠ No .venv found — you may need to run: python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
fi

echo
echo "=== 1. Environment check (the usual culprit) ==="
echo "CODEREF_DB_DSN = '${CODEREF_DB_DSN:-<not set>}'"
bad_vars=$(env | grep -i 'CODEREF_DB_DSN' || true)
if [[ -n "$bad_vars" ]]; then
    echo "⚠ Potentially problematic CODEREF_DB_DSN is set in this shell:"
    echo "$bad_vars"
    echo "   (We will 'unset' it before starting the server below.)"
else
    echo "✓ No CODEREF_DB_DSN in current environment (will use built-in default)"
fi

echo
echo "=== 2. psql connectivity (as your current user) ==="
if command -v psql >/dev/null 2>&1; then
    if psql -d CodeReferenceDB -c "SELECT current_user, current_database(), now();" 2>&1; then
        echo "✓ psql can reach CodeReferenceDB"
    else
        echo "✗ psql connection failed — check that the DB exists and you have access"
    fi
else
    echo "⚠ psql not in PATH"
fi

echo
echo "=== 3. Python + psycopg connectivity test ==="
if python -c "
import os, sys
import psycopg
dsn = os.environ.get('CODEREF_DB_DSN') or 'dbname=CodeReferenceDB user=diego host=localhost'
print('Using DSN:', dsn)
try:
    with psycopg.connect(dsn) as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT current_user, current_database()')
            row = cur.fetchone()
            print('✓ Python connected as', row[0], 'to', row[1])
except Exception as e:
    print('✗ Python connect failed:', e, file=sys.stderr)
    sys.exit(1)
" 2>&1; then
    echo "✓ Python DB layer OK"
else
    echo "✗ Python DB layer failed (see above)"
fi

echo
if [[ "${1:-}" == "--check-only" ]]; then
    echo "Check-only mode. Not starting the server."
    exit 0
fi

echo "=== 4. Starting server (forcing clean DSN) ==="
echo "Forcing: unset CODEREF_DB_DSN (so we use the built-in default for diego/local)"
unset CODEREF_DB_DSN

echo
echo "Server will print its DSN on startup. Look for the ✓ line."
echo "Open http://127.0.0.1:5000 once it says 'Running on http://127.0.0.1:5000'"
echo "Press Ctrl-C to stop."
echo

exec python src/backend/server.py
