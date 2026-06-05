-- Baseline seed for PostgreSQL-related lookup rows.
-- This file should only load reusable shared data.
-- Concept-specific rows belong in separate files later.

BEGIN;

-- Baseline lookup data. These rows can be reused by many concepts.
INSERT INTO languages (code, display_name, runtime_kind, description)
VALUES
	('sql', 'SQL', 'query language', 'Structured query language used to define, query, and manage relational data.'),
	('psql', 'psql', 'database shell', 'Interactive PostgreSQL command-line shell used to run SQL and manage a database session.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO tags (name, tag_group)
VALUES
	('database', 'topic'),
	('postgresql', 'topic')
ON CONFLICT (name, tag_group) DO NOTHING;

COMMIT;
