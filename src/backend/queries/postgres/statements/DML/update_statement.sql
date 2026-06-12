-- SQL UPDATE

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
        'update',       -- slug
        'UPDATE',       -- title
        'dml',          -- concept type
        'SQL statement used to modify the value(s) in existing records in a table.',
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
    SELECT id FROM concepts WHERE slug = 'update' AND NOT EXISTS (SELECT 1 FROM concept_row)
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
        alias_value = 'update'
    FROM concept_lookup c
    CROSS JOIN (VALUES
        ('update'),
        ('sql_update'),
        ('sql update'),
        ('update_statement'),
        ('update statement')
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
        'update',
        'table'
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
        'update',
        $$UPDATE users
SET
    last_login = NOW(),
    login_count = COALESCE(login_count, 0) + 1,
    active = TRUE,
    updated_at = NOW()
WHERE id = 42
  AND active = FALSE
RETURNING id, email, last_login, login_count, active;$$,
        'Modifies existing rows in a table. The SET clause supports literal values, column references, arithmetic, function calls such as NOW() or COALESCE, and even subqueries. The WHERE clause is almost always required because omitting it updates every row in the table, which is a very common and expensive mistake. PostgreSQLs RETURNING clause is extremely useful as it immediately returns the updated rows with their new values, which is perfect for logging, auditing, or handing fresh data back to the application without a follow-up SELECT. Advanced patterns include using UPDATE table SET ... FROM other_table WHERE ... to perform correlated join-style updates in one statement, and driving updates from a CTE with WITH ... UPDATE .... Best practice is to first write the matching SELECT using the same WHERE condition to review the rows, and to wrap the UPDATE in a BEGIN ... COMMIT block so you can ROLLBACK if the affected row count is not what you expected.',
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
        'local://src/backend/queries/postgres/statements/DML/update_statement.sql',
        'Manual seed for the update concept. File: src/backend/queries/postgres/statements/DML/update_statement.sql; purpose: DML example for UPDATE statements.'
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
    'src/backend/queries/postgres/statements/DML/update_statement.sql',
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL UPDATE statement concept, aliases, tags, snippet, and source.'
);

-- ROLLBACK;
COMMIT;