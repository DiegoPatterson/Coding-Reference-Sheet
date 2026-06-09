--To clean up duplicates
-- Inspect the duplicates
SELECT
    s.id,
    s.snippet_kind,
    s.sort_order,
    s.is_primary,
    s.created_at,
    left(replace(s.content, E'\n', ' '), 90) AS content_preview,
    length(s.content) AS content_length
FROM snippets s
JOIN concepts c ON c.id = s.concept_id
WHERE c.slug = 'cross_join'
ORDER BY s.created_at;

-- Keep only the most recently inserted version for this concept
DELETE FROM snippets
WHERE id IN (
    SELECT id
    FROM (
        SELECT id,
                ROW_NUMBER() OVER (
                    PARTITION BY concept_id, snippet_kind
                    ORDER BY created_at DESC
                ) AS rn
        FROM snippets
        WHERE concept_id = (SELECT id FROM concepts WHERE slug = 'cross_join')
    ) ranked
    WHERE rn > 1
);