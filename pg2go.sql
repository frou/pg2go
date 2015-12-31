CREATE FUNCTION NAME_PG2GO(nm TEXT, exported BOOLEAN) RETURNS TEXT AS $$
  SELECT CASE
    WHEN LOWER(nm) IN ('id', 'uid') THEN
      CASE WHEN exported THEN UPPER(nm) ELSE LOWER(nm) END
    WHEN exported THEN
      -- snake_case -> PascalCase
      REPLACE(INITCAP(REPLACE(nm, '_', ' ')), ' ', '')
    ELSE
      -- snake_case -> camelCase
      LOWER(SUBSTRING(nm, 1, 1)) || SUBSTRING(NAME_PG2GO(nm, true), 2)
    END
$$
LANGUAGE SQL
IMMUTABLE;

CREATE FUNCTION TYPE_PG2GO(typ TEXT, nullable BOOLEAN) RETURNS TEXT AS $$
  SELECT CASE
    WHEN nullable THEN
      CASE typ
        WHEN 'BIGINT'           THEN 'sql.NullInt64'
        WHEN 'BOOLEAN'          THEN 'sql.NullBool'
        WHEN 'DOUBLE PRECISION' THEN 'sql.NullFloat64'
        WHEN 'INTEGER'          THEN 'sql.NullInt64'
        WHEN 'REAL'             THEN 'sql.NullFloat64'
        WHEN 'TEXT'             THEN 'sql.NullString'

        ELSE 'NEED_GO_TYPE_FOR_NULLABLE_' || REPLACE(typ, ' ', '_')
      END
    ELSE
      CASE typ
        WHEN 'BIGINT'           THEN 'int'
        WHEN 'BOOLEAN'          THEN 'bool'
        WHEN 'DOUBLE PRECISION' THEN 'float64'
        WHEN 'INTEGER'          THEN 'int'
        WHEN 'REAL'             THEN 'float32'
        WHEN 'TEXT'             THEN 'string'

        WHEN 'BYTEA'                       THEN '[]byte'
        WHEN 'TIMESTAMP WITH TIME ZONE'    THEN 'time.Time'
        WHEN 'TIMESTAMP WITHOUT TIME ZONE' THEN 'time.Time'

        ELSE 'NEED_GO_TYPE_FOR_' || REPLACE(typ, ' ', '_')
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
  SELECT NAME_PG2GO(table_name, false) AS identifier,
         STRING_AGG(E'\t' || NAME_PG2GO(column_name, true) || ' '
                          || TYPE_PG2GO(UPPER(data_type), is_nullable::BOOLEAN)
                          || ' `db:"' || column_name || '"'
                          || ' json:"'|| column_name || '"`',
                    E'\n') AS agg_fields
  FROM db_extract GROUP BY table_name
  ORDER BY identifier
)
SELECT 'type ' || identifier || E' struct {\n' || agg_fields || E'\n}\n'
FROM struct;

------------------------------------------------------------

DROP FUNCTION NAME_PG2GO(TEXT, BOOLEAN);
DROP FUNCTION TYPE_PG2GO(TEXT, BOOLEAN);
