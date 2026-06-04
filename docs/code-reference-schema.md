# CodeReference PostgreSQL Schema Plan

```mermaiderDiagram
    CONCEPTS ||--o{ CONCEPT_ALIASES : has
    CONCEPTS ||--o{ CONCEPT_TAGS : has
    TAGS ||--o{ CONCEPT_TAGS : includes
    CONCEPTS ||--o{ SNIPPETS : has
    LANGUAGES ||--o{ SNIPPETS : uses
    CONCEPTS ||--o{ SOURCES : references
    CONCEPTS ||--o{ IMPORT_RUNS : seeded_by

    CONCEPTS {
        bigint id PK
        text slug UK
        text title
        text concept_type
        text description
        boolean is_active
        timestamptz created_at
        timestamptz updated_at
    }

    CONCEPT_ALIASES {
        bigint id PK
        bigint concept_id FK
        text alias
        text alias_kind
        boolean is_primary
        timestamptz created_at
    }

    TAGS {
        bigint id PK
        text name UK
        text tag_group
        timestamptz created_at
    }

    CONCEPT_TAGS {
        bigint concept_id FK
        bigint tag_id FK
        timestamptz created_at
    }

    LANGUAGES {
        bigint id PK
        text code UK
        text display_name
        text runtime_kind
        boolean is_query_language
    }

    SNIPPETS {
        bigint id PK
        bigint concept_id FK
        bigint language_id FK
        text snippet_kind
        text content
        text notes
        integer sort_order
        boolean is_primary
    }

    SOURCES {
        bigint id PK
        bigint concept_id FK
        text source_type
        text source_uri
        text notes
    }

    IMPORT_RUNS {
        bigint id PK
        text source_name
        text source_format
        timestamptz started_at
        timestamptz finished_at
        text status
        text notes
    }
}
```

## Design Notes

- `CONCEPTS` is the stable top-level entity and should map to the current `store.json` concept keys.
- `CONCEPT_ALIASES` replaces the old `keyword_index` idea and gives you more than one search term per concept.
- `TAGS` and `CONCEPT_TAGS` let you search by topic instead of only by exact aliases.
- `LANGUAGES` makes it easy to support SQL, psql, Python, Java, and anything else later without changing `SNIPPETS`.
- `SNIPPETS` stores the actual reference material and can hold multiple entries per language and concept.
- `SOURCES` gives you a place to keep links, docs, or origin notes for each concept.
- `IMPORT_RUNS` helps future-proof migrations from JSON, CSV, or other seed sources.

## Good PostgreSQL Practice This Covers

- primary keys and foreign keys
- unique constraints on slugs, aliases, and tag names
- many-to-many relationships
- clean separation between concepts, aliases, tags, languages, and snippets
- room for search indexes and future full-text search
