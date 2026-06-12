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
        'having',      -- slug
        'HAVING',      -- title
        'dql',      -- concept_type
        'SQL statement used to  filter the results of a GROUP BY query based on aggregate functions. filters groups after the aggregation has been performed.',      -- description
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
    SELECT id FROM concepts WHERE slug = 'having' AND NOT EXISTS (SELECT 1 FROM concept_row)     -- slug
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
        alias_value = 'having'    -- primary alias
    FROM concept_lookup c
    CROSS JOIN (VALUES          -- other possible
        ('having'),
        ('sql having'),
        ('having statement')
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
    WHERE t.name IN (          -- related tags
        'dql',
        'sql',
        'database',
        'having',
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
        'having',           
        $$SELECT
    genre,
    COUNT(*) AS book_count,
    AVG(pages) AS avg_pages
FROM books
GROUP BY genre
HAVING COUNT(*) > 2 AND AVG(pages) > 300
ORDER BY book_count DESC;$$,           
        'HAVING is used to filter groups of rows after they have been aggregated by a GROUP BY clause applying conditions that reference aggregate functions such as COUNT SUM AVG MAX or MIN. Unlike the WHERE clause which filters individual rows before any grouping takes place HAVING operates on the summarized group results and is the only correct place to apply filters that depend on those aggregates for example requiring a group to contain more than a certain number of rows or to have an average above a threshold. The HAVING clause appears after the GROUP BY and before ORDER BY or LIMIT and supports multiple conditions combined with AND or OR while also allowing references to both aggregated expressions and columns that appear in the GROUP BY list. It is essential for analytical queries that need to identify only those groups meeting specific summary criteria such as genres with more than a handful of books or readers who have borrowed more than a target number of titles. Because the aggregation step must complete before HAVING can evaluate its conditions queries using it can be more expensive on large datasets than equivalent filtering pushed earlier into the WHERE clause when possible.',            
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
        'local://src/backend/queries/postgres/statements/DQL/having_statement.sql',             -- source uri
        'Manual seed for the HAVING concept. File: src/backend/queries/postgres/statements/DQL/having_statement.sql; purpose: DML example for having statements.'       -- note
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
    'src/backend/queries/postgres/statements/DQL/having_statement.sql',
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL having statement concept, aliases, tags, snippet, and source.'
);

-- ROLLBACK;
COMMIT;

