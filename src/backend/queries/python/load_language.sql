BEGIN;

-- load baseline lookups
INSERT INTO languages (code, display_name, runtime_kind, description)
VALUES
    ('python', 'Python', 'programming language', 'High-level programming language known for readability, flexibility, and a large library ecosystem.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO tags (name, tag_group)
VALUES
    ('programming language', 'category'),
    ('interpreted', 'category'),
    ('high-level', 'category'),
    ('dynamically typed', 'category'),
    ('scripting', 'category'),
    ('backend', 'category'),
    ('data science', 'category'),
    ('machine learning', 'category')
ON CONFLICT (name, tag_group) DO NOTHING;

COMMIT;

SELECT * FROM tags
