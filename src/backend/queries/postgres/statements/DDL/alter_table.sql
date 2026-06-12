-- SQL ALTER TABLE

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
        'alter_table',
        'ALTER TABLE',
        'ddl',
        'SQL statement used to add, delete, or modify columns in an existing table as well as to add and drop various constraints on an existing table',
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
    SELECT id FROM concepts WHERE slug = 'alter_table' AND NOT EXISTS (SELECT 1 FROM concept_row)
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
        alias_value = 'alter table'
    FROM concept_lookup c
    CROSS JOIN (VALUES
        ('alter table'),
        ('alter_table'),
        ('sql alter'),
        ('sql_alter'),
        ('alter statement'),
        ('alter_statement')
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
    CROSS JOIN tags T
    WHERE t.name IN (
        'ddl',
        'sql',
        'database',
        'alter',
        'table',
        'entry'
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
        'alter_table',
        $$ALTER TABLE users
    ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ,
    ALTER COLUMN email SET NOT NULL,
    ADD CONSTRAINT users_email_unique UNIQUE (email);$$,
        'Modifies the structure of an existing table without dropping and recreating it. You can add new columns using ADD COLUMN often with the IF NOT EXISTS clause to keep scripts idempotent, change column definitions with ALTER COLUMN to adjust data types, nullability, or defaults, add or drop constraints for data integrity, and rename tables or columns. Multiple operations can be combined in a single statement by separating the actions with commas. This is one of the most commonly used DDL statements when iterating on a database schema as application requirements evolve. Some alterations on large tables can be slow or temporarily lock the table so it is recommended to test changes thoroughly and perform them during maintenance windows whenever possible.',
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
        'local://src/backend/queries/postgres/statements/DDL/alter_table.sql',
        'Manual seed for the alter_table concept. File: src/backend/queries/postgres/statements/DDL/alter_table.sql; purpose: DDL example for ALTER TABLE statements.'
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
    'src/backend/queries/postgres/statements/DDL/alter_table.sql',
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL ALTER TABLE statement concept, aliases, tags, snippet, and source.'
)

-- ROLLBACK;
COMMIT;