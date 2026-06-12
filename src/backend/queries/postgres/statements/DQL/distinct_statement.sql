-- SQL DISTINCT STATEMENT

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
        'distinct',
        'DISTINCT',
        'dql',
        'If a column contains duplicate values, it will only return one of each.',
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
    SELECT id FROM concepts WHERE slug = 'distinct' AND NOT EXISTS (SELECT 1 FROM concept_row)
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
        alias_value = 'distinct'
    FROM concept_lookup c
    CROSS JOIN(VALUES
        ('select_distinct'),
        ('select distinct'),
        ('distinct'),
        ('sql distinct')
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
        'dql',
        'sql',
        'database',
        'distinct',
        'query'
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
        'distinct',
        $$SELECT DISTINCT
    genre,
    published_year
FROM books
WHERE pages > 300
ORDER BY genre;$$,
        'Removes duplicate rows from the result set of a SELECT query so that each unique combination of values from the specified columns appears only once. It is placed directly after the SELECT keyword and evaluates uniqueness across all columns included in the select list. PostgreSQL additionally supports DISTINCT ON which returns the first row for each distinct value of the listed expressions while still allowing you to select other columns making it useful for retrieving one representative row per group such as the most recent entry per category. Because DISTINCT must identify and discard duplicates it generally requires sorting or hashing the data which can be expensive on large tables or high cardinality columns so it is worth evaluating whether GROUP BY or window functions might be a more performant alternative depending on the rest of your query needs.',
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
        'local://src/backend/queries/postgres/statements/DQL/distinct_statement.sql',
        'Manual seed for the distinct concept. File: src/backend/queries/postgres/statements/DQL/distinct_statement.sql; purpose: DML example for DISTINCT statements.'
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
    'src/backend/queries/postgres/statements/DQL/distinct_statement.sql',
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL DISTINCT statement concept, aliases, tags, snippet, and source.'
);

-- ROLLBACK;
COMMIT;