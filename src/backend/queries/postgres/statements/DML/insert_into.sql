-- SQL INSERT INTO

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
        'insert_into',      -- slug
        'INSERT INTO',      -- title
        'dml',              -- concept_type
        'SQL statement used to add one or more new rows of data into a table, specifying the target columns and the values (or a subquery).',
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
    SELECT id FROM concepts WHERE slug = 'insert_into' AND NOT EXISTS (SELECT 1 FROM concept_row)
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
        alias_value = 'insert into'
    FROM concept_lookup c
    CROSS JOIN (VALUES
        ('insert into'),
        ('insert_into'),
        ('insert'),
        ('sql insert'),
        ('insert statement')
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
        'dml',
        'sql',
        'database',
        'insert',
        'table',
        'data'
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
        'insert_into',
        $$INSERT INTO users (email, active) 
        VALUES ('ada@example.com', TRUE);$$,
        'Basic INSERT INTO example adding a single new active user row.',
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
        'local://src/backend/queries/postgres/statements/insert_into.sql',
        'Manual seed for the insert_into concept. File: src/backend/queries/postgres/statements/insert_into.sql; purpose: DML example for INSERT INTO statements.'
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
    'src/backend/queries/postgres/statements/insert_into.sql',
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL INSERT INTO statement concept, aliases, tags, snippet, and source.'
);

-- ROLLBACK;
COMMIT;

