# Polyglot Syntax Journal & Concept Indexer

A lightweight, terminal-based knowledge-graph journal designed to help developers track, link, and cross-reference programming concepts across multiple languages (Python, Java, C++, etc.). 

Instead of a flat document, this journal utilizes an inverted-index ontology model to instantly map high-level conceptual keywords (e.g., `iteration`, `count`, `sequence`) back to code syntax snippets across different languages.

---

## Features

* **Cross-Language Reference:** View syntax for the exact same programmatic concept across multiple languages side-by-side.
* **Semantic Tag Mapping (Mini-Ontology):** Search using abstract descriptive keywords (`logic`, `branching`, `loops`) rather than strict language syntax.
* **Dynamic Inverted Indexing:** Automatically builds an in-memory concept network on startup for $O(1)$ keyword-to-concept retrieval.
* **Modular Foundation:** Data and query layers are decoupled from the display logic, making it trivial to attach a Graphical User Interface (GUI) later.

---

## Project Architecture

The architecture is split into three core pillars:

1. **The Knowledge Base (`dict`):** A nested dictionary structure where each node represents a unique programming concept containing metadata, relational search tags (`set`), and language-specific code snippets.
2. **The Semantic Indexer (`inverted index`):** A compiler function that maps atomic tags to a set of matching concept IDs, serving as the relational query engine.
3. **The Interface Layer (`CLI`):** An interactive terminal loop handling data presentation and search queries.

---

## Getting Started

### Prerequisites
* Python 3.12+ recommended
* PostgreSQL running with the `CodeReferenceDB` database (see `src/backend/queries/initialize_base.sql`)
* (For the web UI) the Python packages installed in the project venv

### Quick Start – CodeDex Web UI (recommended)
```bash
cd "/home/diego/Documents/Programs/Coding Practice/CodeReference"
source .venv/bin/activate
pip install flask 'psycopg[binary]'
python src/backend/server.py
# open http://localhost:5000
```

This runs **one server** that serves both the search-engine frontend and the API that talks to your DB.

### Linking the Frontend to *Your Own Server*
If you have (or want to use) your own server / backend code ("my server") instead of (or alongside) the provided `server.py`:

1. Make sure your server implements these 5 endpoints (they return JSON, no auth):
   - `GET /api/languages`
   - `GET /api/concepts`
   - `GET /api/search?q=...&lang=...` (lang optional)
   - `GET /api/concept/<slug>`
   - `GET /api/browse`

2. In the frontend, change **one line** near the top of `src/frontend/index.html`:

   ```js
   let API = 'http://localhost:5000';   // <--- point this at your server
   ```

   You can also override at runtime with the URL query string:
   `http://localhost:8080/?api=http://localhost:9000`

3. If your frontend and your API server are on **different ports** (or one is `file://`), enable CORS on your API server for the frontend's origin (the provided `server.py` already does wide-open CORS for development).

4. Ways to serve just the frontend while pointing at your API:
   - `python -m http.server 8080 --directory src/frontend`
   - Use VS Code "Live Server" extension on `src/frontend/index.html`
   - Any static file server

   Then visit the port you chose and it will call your API (thanks to the `let API = ...` setting).

The contract is tiny and easy to re-implement in FastAPI, Flask, Express, etc. if you want everything in "your server".

### Old CLI
The original terminal journal is in `Old/V01/`.

---

## CodeDex Web Frontend (Search Engine)

New in this workspace: a fully functional search-engine UI in `src/frontend/index.html` served by a lightweight Flask API (`src/backend/server.py`) that queries your live `CodeReferenceDB`.

- **Language dropdown**: far right inside the search bar — filters suggestion results.
- **Hamburger (☰)**: right side — collapsible language accordions with statements inside.
- **Logo (CodeDex)**: top left — always click to return to the clean front/home page.
- Search is fuzzy across titles, aliases (py, ct, ...), descriptions, concept_type (e.g. `ddl`), and tags.
- Selecting a result "pulls it up" with syntax-highlighted snippets per language and one-click copy.

Everything is driven directly from the same Postgres database you already have seeded.
