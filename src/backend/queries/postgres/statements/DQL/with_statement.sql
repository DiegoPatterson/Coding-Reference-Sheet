-- SQL WITH

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
        'with',      -- slug
        'WITH',      -- title
        'dql',      -- concept_type
        'SQL clause that defines one or more named temporary result sets known as Common Table Expressions (CTEs) which can be referenced in the main query to improve readability, avoid repetition, and support recursive queries.',      -- TODO: description
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
    SELECT id FROM concepts WHERE slug = 'with' AND NOT EXISTS (SELECT 1 FROM concept_row)     -- slug
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
        alias_value = 'with'    -- primary alias
    FROM concept_lookup c
    CROSS JOIN (VALUES          -- other possible
        ('with'),
        ('sql with'),
        ('with Statement')
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
        'query',
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
        'with',           -- snippet kind (slug)
        $$$WITH active_readers AS (
    SELECT reader_id, COUNT(*) AS total_loans
    FROM loans
    GROUP BY reader_id
    HAVING COUNT(*) > 2
),
recent_loan AS (
    SELECT DISTINCT ON (reader_id) 
           reader_id, book_id, borrowed_at
    FROM loans
    ORDER BY reader_id, borrowed_at DESC
)
SELECT 
    r.name,
    ar.total_loans,
    b.title AS last_borrowed_book,
    rl.borrowed_at
FROM active_readers ar
JOIN readers r ON ar.reader_id = r.reader_id
JOIN recent_loan rl ON ar.reader_id = rl.reader_id
JOIN books b ON rl.book_id = b.book_id
ORDER BY ar.total_loans DESC;$$,           -- use example
        'Common Table Expressions defined with the WITH keyword let you create named temporary result sets that can be referenced like tables within the main query. They dramatically improve readability by breaking complex logic into clear named steps instead of deeply nested subqueries and allow the same derived result to be used multiple times without repetition. PostgreSQL supports recursive CTEs via WITH RECURSIVE for traversing hierarchical data such as org charts or category trees. CTEs are evaluated once and their results can be used in SELECT INSERT UPDATE or DELETE. They pair especially well with window functions aggregates and HAVING when you need to reference summarized data in multiple places or apply further filtering and joins on the summarized results.',            -- use example explenation
        1,                  -- Example order
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
        'local://src/backend/queries/postgres/statements/DQL/with_statement.sql',             -- source uri
        'Manual seed for the WITH concept. File: src/backend/queries/postgres/statements/DQL/with_statement.sql; purpose: DML example for with statements.'       -- note
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
    'src/backend/queries/postgres/statements/DQL/with_statement.sql',        -- Source name (reletive location)
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL WITH statement concept, aliases, tags, snippet, and source.'        -- note
);

-- ROLLBACK;
COMMIT;

