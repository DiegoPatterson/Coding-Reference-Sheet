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
        '____',      -- TODO: slug
        '____',      -- TODO: title
        '____',      -- TODO: concept_type
        '____',      -- TODO: description
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
    SELECT id FROM concepts WHERE slug = '_____' AND NOT EXISTS (SELECT 1 FROM concept_row)     -- TODO: slug
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
        alias_value = '____'    -- TODO: primary alias
    FROM concept_lookup c
    CROSS JOIN (VALUES          -- TODO: other possible
        ('____'),
        ('____'),
        ('sql ____'),
        ('____ Statement')
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
    WHERE t.name IN (          -- TODO: related tags
        '___'
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
        '______',           -- TODO: snippet kind (slug)
        $$____$$,           -- TODO: use example
        '_____',            -- TODO: use example explenation
        1,                  -- TODO: Example order
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
        'local://src/backend/queries/postgres/statements/_____/______',             -- TODO: source uri
        'Manual seed for the _______ concept. File: src/backend/queries/postgres/statements/____/____; purpose: DML example for ________ statements.'       -- TODO: note
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
    'src/backend/queries/postgres/statements/______/______',        -- TODO: Source name (reletive location)
    'sql',
    now(),
    now(),
    'success',
    'Loaded SQL ________ statement concept, aliases, tags, snippet, and source.'        -- TODO: note
);

-- ROLLBACK;
COMMIT;

