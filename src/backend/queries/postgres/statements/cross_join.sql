-- CROSS JOIN 

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
        'cross_join',
        'SQL CROSS JOIN',
        'dml',
        'SQL statement used to combine every row from table A to every row from table B',
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
    SELECT id FROM concepts WHERE slug = 'cross_join' AND NOT EXISTS (SELECT 1 FROM concept_row)
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
        alias_value = 'cross join'
    FROM concept_lookup c
    CROSS JOIN (VALUES
        ('cross join'),
        ('cross_join'),
        ('sql cross join'),
        ('x join'),
        ('+ join'),
        ('cj')
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
        'join',
        'cross join',
        'cartesian product',
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
        'cross_join',
        $$SELECT
    p.product_name,
    c.category_name
FROM products p
CROSS JOIN categories c;$$,
        'Produces a Cartesian product: every row from the left table is paired with every row from the right table with no matching condition. If the first table has N rows and the second has M rows, the result will contain exactly N x M rows. Useful for generating all possible combinations (product variants by size+color, test data matrices, date dimension scaffolding, etc.). In real queries a CROSS JOIN is frequently followed by a WHERE clause to filter the results down. Be careful with large tables - the result size grows very quickly.',
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
        'local://src/backend/queries/postgres/statements/cross_join.sql',
        'Manual seed for the cross_join concept. File: src/backend/queries/postgres/statements/cross_join.sql; purpose: DML example for cross join'
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
    'src/backend/queries/postgres/statements/cross_join.sql',
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL CROSS JOIN statement concept, aliases, tags, snippet, and source.'
);

-- ROLLBACK;
COMMIT;
