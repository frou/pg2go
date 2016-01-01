CREATE FUNCTION name_pg2go(nm text, exported boolean) RETURNS text AS $$
  SELECT CASE
    WHEN lower(nm) IN ('id', 'uid') THEN
      CASE WHEN exported THEN upper(nm) ELSE lower(nm) END
    WHEN exported THEN
      -- snake_case -> PascalCase
      replace(initcap(replace(nm, '_', ' ')), ' ', '')
    ELSE
      -- snake_case -> camelCase
      lower(substring(nm, 1, 1)) || substring(name_pg2go(nm, true), 2)
    END
$$
LANGUAGE SQL
IMMUTABLE;

CREATE FUNCTION type_pg2go(typ text, nullable boolean) RETURNS text AS $$
  SELECT CASE
    WHEN nullable THEN
      CASE typ
        WHEN 'bigint'           THEN 'sql.NullInt64'
        WHEN 'boolean'          THEN 'sql.NullBool'
        WHEN 'double precision' THEN 'sql.NullFloat64'
        WHEN 'integer'          THEN 'sql.NullInt64'
        WHEN 'numeric'          THEN 'sql.NullInt64'
        WHEN 'real'             THEN 'sql.NullFloat64'
        WHEN 'smallint'         THEN 'sql.NullInt64'

        WHEN 'character varying'  THEN 'sql.NullString'
        WHEN 'character'          THEN 'sql.NullString'
        WHEN 'text'               THEN 'sql.NullString'
        WHEN 'bytea'              THEN '[]byte'

        WHEN 'timestamp with time zone'    THEN 'pq.NullTime /* go get github.com/lib/pq */'
        WHEN 'timestamp without time zone' THEN 'pq.NullTime /* go get github.com/lib/pq */'
        WHEN 'date'                        THEN 'pq.NullTime /* go get github.com/lib/pq */'
        WHEN 'time with time zone'         THEN 'pq.NullTime /* go get github.com/lib/pq */'
        WHEN 'time without time zone'      THEN 'pq.NullTime /* go get github.com/lib/pq */'

        ELSE 'NEED_GO_TYPE_FOR_NULLABLE_' || replace(typ, ' ', '_')
      END
    ELSE
      CASE typ
        WHEN 'bigint'           THEN 'int'
        WHEN 'boolean'          THEN 'bool'
        WHEN 'double precision' THEN 'float64'
        WHEN 'integer'          THEN 'int'
        WHEN 'numeric'          THEN 'int'
        WHEN 'real'             THEN 'float32'
        WHEN 'smallint'         THEN 'int'

        WHEN 'character varying'  THEN 'string'
        WHEN 'character'          THEN 'string'
        WHEN 'text'               THEN 'string'
        WHEN 'bytea'              THEN '[]byte'

        WHEN 'timestamp with time zone'    THEN 'time.Time'
        WHEN 'timestamp without time zone' THEN 'time.Time'
        WHEN 'date'                        THEN 'time.Time'
        WHEN 'time with time zone'         THEN 'time.Time'
        WHEN 'time without time zone'      THEN 'time.Time'

        ELSE 'NEED_GO_TYPE_FOR_' || replace(typ, ' ', '_')
      END
  END;
$$
LANGUAGE SQL
IMMUTABLE;

------------------------------------------------------------

WITH struct AS (
  WITH db_extract AS (
    SELECT table_name, column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public'
    ORDER BY table_schema, table_name, ordinal_position
  )
  SELECT name_pg2go(regexp_replace(table_name, '([^aeiou])s$', '\1'),
                    false) AS identifier,
         string_agg(E'\t' || name_pg2go(column_name, true) || ' '
                          || type_pg2go(data_type, is_nullable::boolean)
                          || ' `db:"' || column_name || '"'
                          || ' json:"'|| column_name || '"`',
                    E'\n') AS agg_fields
  FROM db_extract GROUP BY table_name
  ORDER BY identifier
)
SELECT 'type ' || identifier || E' struct {\n' || agg_fields || E'\n}\n'
FROM struct;

------------------------------------------------------------

DROP FUNCTION name_pg2go(text, boolean);
DROP FUNCTION type_pg2go(text, boolean);
