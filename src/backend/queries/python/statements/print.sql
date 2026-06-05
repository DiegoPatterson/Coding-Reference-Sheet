-- Python print seed file.
-- Run the shared baseline seed first, then load this file for concept-level data.

BEGIN;

-- One demo concept that links back to the shared baseline rows.
WITH concept_row AS (
	INSERT INTO concepts (
		slug,
		title,
		concept_type,
		description,
		is_active
	)
	VALUES (
		'python_print_statement',
		'Python Print Statement',
		'syntax',
		'Displays text or values to standard output using the built-in print() function.',
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
	SELECT id FROM concepts WHERE slug = 'python_print_statement' AND NOT EXISTS (SELECT 1 FROM concept_row)
),
python_language AS (
	SELECT id
	FROM languages
	WHERE code = 'python'
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
		alias_value = 'python'
	FROM concept_lookup c
	CROSS JOIN (VALUES
		('python'),
		('py')
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
		'console output',
		'io',
		'syntax',
		'printing'
	)
	ON CONFLICT (concept_id, tag_id) DO NOTHING
	RETURNING concept_id
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
		'print_statement',
		$$print("Hello, world!")$$,
		'Example: printing a simple string to standard output.',
		1,
		TRUE
	FROM concept_lookup c
	CROSS JOIN python_language l
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
		'local://src/backend/queries/python/statements/print.sql',
		'Seed for the `print()` concept: example, provenance, and short notes.'
	FROM concept_lookup c
	ON CONFLICT DO NOTHING
	RETURNING id
)
SELECT
	(SELECT id FROM concept_lookup LIMIT 1) AS concept_id,
	(SELECT id FROM python_language LIMIT 1) AS language_id,
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
	'src/backend/queries/python/statements/print.sql',
	'sql',
	now(),
	now(),
	'success',
	'Loaded Python print statement concept, aliases, tags, snippet, and source.'
);

COMMIT;
