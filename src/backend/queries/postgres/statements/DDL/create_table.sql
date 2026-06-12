-- SQL CREATE TABLE 

BEGIN;

WITH concept_row AS (
    INSERT INTO concepts(
        slug,
        title,
        concept_type,
        description,
        is_active
    )
    VALUES (
        'create_table',
        'SQL CREATE TABLE',
        'ddl',
        'SQL statement used to define a new table and its columns, data types, constraints, and relationships.',
        TRUE
    )
    ON CONFLICT (slug) DO UPDATE
    SET
        title = EXCLUDED.title,
        concept_type = EXCLUDED.concept_type,
        description = EXCLUDED.description,
        is_active = EXCLUDED.is_active,
        updated_at = now()
    RETURNING id
),
concept_lookup AS (
    SELECT id FROM concept_row
    UNION ALL
    SELECT id FROM concepts WHERE slug = 'create_table' AND NOT EXISTS (SELECT 1 FROM concept_row)
),

sql_language AS (
    SELECT id FROM languages WHERE code = 'sql'
),
alias_insert AS (
    INSERT INTO concept_aliases (
        concept_id,
        alias,
        alias_kind,
        is_primary
    )
    SELECT
        c.id,
        alias_value,
        'keyword',
        alias_value = 'create table'
    FROM concept_lookup c
    CROSS JOIN (VALUES
        ('create table'),
        ('create_table'),
        ('ct')
    ) AS aliases(alias_value)
    ON CONFLICT (concept_id, alias) DO NOTHING
    RETURNING id
),
tag_link_insert AS (
    INSERT INTO concept_tags (concept_id, tag_id)
    SELECT
        c.id,
        t.id
    FROM concept_lookup c
    CROSS JOIN tags t
    WHERE t.name IN (
        'database',
        'sql',
        'ddl',
        'schema',
        'table',
        'constraints',
        'relationships'
    )
    ON CONFLICT (concept_id, tag_id) DO NOTHING
    RETURNING concept_id, tag_id
),
snippet_insert AS (
    INSERT INTO snippets(
        concept_id,
        language_id,
        snippet_kind,
        content,
        notes,
        sort_order,
        is_primary
    )
    SELECT
        c.id,
        l.id,
        'create_table',
        $$CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);$$,
        'Basic CREATE TABLE example for defining a new table.',
        1,
        TRUE
    FROM concept_lookup c
    CROSS JOIN sql_language l
    ON CONFLICT DO NOTHING
    RETURNING id
),
source_insert AS (
    INSERT INTO sources (
        concept_id,
        source_type,
        source_uri,
        notes
    )
    SELECT
        c.id,
        'manual',
        'local://src/backend/queries/postgres/statements/create_table.sql',
        'Manual seed for the create_table concept. File: src/backend/queries/postgres/statements/create_table.sql; purpose: DDL example for creating tables.'
    FROM concept_lookup c
    ON CONFLICT DO NOTHING
    RETURNING id
)
SELECT
    (SELECT id FROM concept_lookup LIMIT 1) AS concept_id,
    (SELECT id FROM sql_language LIMIT 1) AS language_id,
    (SELECT count(*) FROM alias_insert) AS aliases_added,
    (SELECT count(*) FROM tag_link_insert) AS concept_tags_added,
    (SELECT count(*) FROM snippet_insert) AS snippets_added,
    (SELECT count(*) FROM source_insert) AS sources_added;

INSERT INTO import_runs (
    source_name,
    source_format,
    started_at,
    finished_at,
    status,
    notes
)

VALUES (
    'src/backend/queries/postgres/statements/create_table.sql',
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL CREATE TABLE statement concept, aliases, tags, snippet, and source.'
);

COMMIT;

-- SELECT * FROM concepts WHERE slug = 'create_table';
-- SELECT * FROM snippets s JOIN concepts c ON s.concept_id = c.id WHERE c.slug = 'create_table';
-- SELECT * FROM concept_aliases WHERE concept_id = (SELECT id FROM concepts WHERE slug='create_table');
-- SELECT source_uri, notes FROM sources WHERE source_uri LIKE '%create_table.sql';