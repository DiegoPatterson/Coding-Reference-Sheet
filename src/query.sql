-- For Peace of mind
SELECT current_user, current_database(), now();

-- Create Tables
CREATE TABLE IF NOT EXISTS concepts (
    id              BIGSERIAL PRIMARY KEY,
    slug            TEXT NOT NULL UNIQUE,
    title           TEXT NOT NULL,
    concept_type    TEXT,
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS concept_aliases (
    id              BIGSERIAL PRIMARY KEY,
    concept_id      BIGINT NOT NULL REFERENCES concepts(id)    ON DELETE CASCADE,
    alias           TEXT NOT NULL,
    alias_kind      TEXT,
    is_primary      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(concept_id, alias)
);

CREATE TABLE IF NOT EXISTS tags (
    id              BIGSERIAL PRIMARY KEY,
    name            TEXT NOT NULL,
    tag_group       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(name, tag_group)
);

CREATE TABLE IF NOT EXISTS concept_tags (
    concept_id      BIGINT NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    tag_id          BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (concept_id, tag_id)
);

CREATE TABLE IF NOT EXISTS languages (
    id              BIGSERIAL PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE, -- e.g. 'sql', 'psql', 'python'
    display_name    TEXT,
    runtime_kind    TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS snippets (
    id              BIGSERIAL PRIMARY KEY,
    concept_id      BIGINT NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    language_id     BIGINT REFERENCES languages(id),
    snippet_kind    TEXT NOT NULL,  -- e.g 'connect', 'table'
    content         TEXT NOT NULL,
    notes           TEXT,
    sort_order      INT NOT NULL DEFAULT 0,
    is_primary      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sources (
    id              BIGSERIAL PRIMARY KEY,
    concept_id      BIGINT REFERENCES concepts(id) ON DELETE SET NULL,
    source_type     TEXT,
    source_uri      TEXT,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS import_runs (
    id              BIGSERIAL PRIMARY KEY,
    source_name     TEXT,
    source_format   TEXT,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at     TIMESTAMPTZ,
    status          TEXT,
    notes           TEXT
);

-- CREATE TABLE IF NOT EXISTS futureproof_tables (
--     users           SERIAL PRIMARY KEY,
--     bookmarks       TEXT,
--     search_history  TEXT,
--     concept_version TEXT,
--     sync_jobs       TEXT
-- );