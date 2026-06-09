-- DELETE SQL Statment

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
        'delete',
        'SQL DELETE',
        'dml',
        'SQL statement used to delete existing records in a table',
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
    SELECT id FROM concepts WHERE slug = 'delete' AND NOT EXISTS (SELECT 1 FROM concept_row)
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
        alias_value = 'delete'
    FROM concept_lookup c
    CROSS JOIN (VALUES
        ('delete'),
        ('sql_delete')
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
        'delete',
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
        'delete',
        $$DELETE FROM users
WHERE active = FALSE
  AND last_login < NOW() - INTERVAL '1 year'
RETURNING id, email, last_login;$$,
        'Removes one or more rows from a table. The WHERE clause is critical - omitting it deletes every row in the table. This example targets stale inactive users and uses PostgreSQL''s RETURNING clause to immediately return the deleted rows (very useful for auditing, logging, or confirming the right data was affected). You can also do more advanced deletes in Postgres using a USING clause (similar to a join) or by referencing subqueries in the WHERE. For clearing an entire table, TRUNCATE is usually faster and resets sequences, but it bypasses row-level triggers and some constraints.',
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
        'local://src/backend/queries/postgres/statements/delete_statement.sql',
        'Manual seed for the delete concept. File: src/backend/queries/postgres/statements/delete_statement.sql; purpose: DML example for delete'
    FROM concept_lookup c
    ON CONFLICT DO NOTHING
    RETURNING id
)
SELECT
    (SELECT id FROM concept_lookup LIMIT 1) AS concept_id,
    (SELECT id FROM sql_language LIMIT 1) AS language_id,
    (SELECT count(*) FROM alias_insert) AS aliases_added,
    (SELECT count(*) FROM tag_link_insert) AS concept_tags_added,
    (SELECT count(*) FROM snippet_insert) AS snippets_added;

INSERT INTO import_runs (
    source_name,
    source_format,
    started_at,
    finished_at,
    status,
    notes
)

VALUES (
    'src/backend/queries/postgres/statements/delete_statement.sql',
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL DELETE statement concept, aliases, tags, snippet, and source.'
);

-- ROLLBACK;
COMMIT;