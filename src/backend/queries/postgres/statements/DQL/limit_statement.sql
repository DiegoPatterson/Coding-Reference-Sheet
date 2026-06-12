-- SQL LIMIT Statement

BEGIN;

WITH concept_row AS (
    INSERT INTO concepts (
        slug, 
        title,
        concept_type,
        description,
        is_active
    )
    VALUES (
        'limit',
        'SQL LIMIT',
        'dql',
        'SQL statement used to limit the maximum numbers of records to return',
        TRUE
    )
    ON CONFLICT (slug) DO UPDATE
    SET
        title = EXCLUDED.title,
        concept_type = EXCLUDED.concept_type,
        description = EXCLUDED.description,
        is_active = EXCLUDED.is_active,
        updated_at = now()
    RETURNING ID
),
concept_lookup AS (
    SELECT id FROM concept_row
    UNION ALL
    SELECT id FROM concepts WHERE slug = 'limit' AND NOT EXISTS (SELECT 1 FROM concept_row)
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
        alias_value = 'limit'
    FROM concept_lookup c
    CROSS JOIN (VALUES
        ('limit'),
        ('sql limit')
    ) AS aliases(alias_value)
    ON CONFLICT (concept_id, alias) DO NOTHING
    RETURNING id
),
tag_link_insert AS (
    INSERT INTO  concept_tags (concept_id, tag_id)
    SELECT
        c.id,
        t.id
    FROM concept_lookup c
    CROSS JOIN tags t
    WHERE t.name IN (
        'dql',
        'sql',
        'database',
        'query'
    )
    ON CONFLICT (concept_id, tag_id) DO NOTHING
    RETURNING concept_id, tag_id
),
snippet_insert AS (
    INSERT INTO snippets (
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
        'limit',
        $$SELECT
    id,
    email,
    created_at
FROM users
WHERE active = TRUE
ORDER BY created_at DESC
LIMIT 10 OFFSET 10;$$,
        'LIMIT restricts the number of rows returned by a query. It should nearly always be paired with ORDER BY to get predictable "top N" results. OFFSET skips the first N rows before applying the limit (commonly used for pagination: page size x (page number - 1)). Important notes: Large OFFSET values are inefficient because the database must still scan and discard the skipped rows, For deep pagination on large tables, prefer keyset/cursor pagination instead (e.g. WHERE id > last_seen_id), PostgreSQL also supports the SQL standard syntax: OFFSET ... FETCH FIRST n ROWS ONLY. Without an ORDER BY, LIMIT returns an arbitrary subset of matching rows.',
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
        'local://src/backend/queries/postgres/statements/limit_statement.sql',
        'Manual seed for the limit concept. File: src/backend/queries/postgres/statements/limit_statement.sql; purpose: DQL example for limit'
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
    'src/backend/queries/postgres/statements/limit_statement.sql',
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL LIMIT statement concept, aliases, tags, snippet, and source.'
);

-- ROLLBACK;
COMMIT;