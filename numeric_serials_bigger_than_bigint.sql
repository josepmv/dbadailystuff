CREATE OR REPLACE FUNCTION numeric_serials_bigger_than_bigint(schema_name regnamespace)
/*
Checks for all NUMERIC greater than 18 digits if it's possible to convert them to bigint (said in column 'downcast_possible')

The function can check it in one schema or in all the database:
- SELECT * FROM numeric_serials_bigger_than_bigint('my_schema');
- SELECT * FROM numeric_serials_bigger_than_bigint(null);
*/
RETURNS TABLE (
		table_schema 		information_schema.sql_identifier, --regnamespace,
		table_name   		information_schema.sql_identifier, --regclass,
		column_name  		VARCHAR(1000),
		column_default 		VARCHAR(1000),
		is_nullable 		boolean,
		data_type 			VARCHAR(50), 
		numeric_precision 	INT, 
		numeric_scale		INT, 
		n_live_tup			NUMERIC(100),
		min_value			NUMERIC(100),
		max_value			NUMERIC(100),
		downcast_possible   boolean
	)
LANGUAGE plpgsql
AS $$
DECLARE
  min_return NUMERIC(100);
  max_return NUMERIC(100);
  serial_row RECORD;
BEGIN
	CREATE TEMPORARY TABLE serials (
		table_schema 		information_schema.sql_identifier NOT NULL,  --regnamespace NOT NULL,
		table_name   		information_schema.sql_identifier NOT NULL,  --regclass NOT NULL,
		column_name  		VARCHAR(1000) NOT NULL,
		column_default 		VARCHAR(1000) NOT NULL,
		is_nullable 		boolean NOT NULL,
		data_type 			VARCHAR(50) NOT NULL, 
		numeric_precision 	INT 		NOT NULL, 
		numeric_scale		INT 		NOT NULL, 
		n_live_tup			NUMERIC(100) NOT NULL,
		min_value			NUMERIC(100),
		max_value			NUMERIC(100),
		downcast_possible   boolean
	) ON COMMIT DROP;
	
	INSERT INTO serials (table_schema, table_name, column_name, column_default, is_nullable, data_type, 
			numeric_precision, numeric_scale, n_live_tup)
		SELECT c.table_schema, c.table_name, c.column_name, c.column_default, CAST (c.is_nullable AS boolean), c.data_type, 
				c.numeric_precision, c.numeric_scale, t.n_live_tup 
			FROM information_schema.columns c
			INNER JOIN pg_stat_user_tables t ON c.table_schema = t.schemaname AND c.table_name = t.relname
			WHERE c.data_type = 'numeric' AND c.numeric_precision > 18 AND c.column_default LIKE 'nextval(''%'
				AND c.table_schema = COALESCE(CAST(schema_name AS information_schema.sql_identifier), c.table_schema)
			ORDER BY c.table_catalog, c.table_schema, c.table_name, c.column_name;
	
	FOR serial_row IN
			SELECT s.table_schema, s.table_name, s.column_name, 
				'SELECT MIN(' || s.column_name || '), MAX(' || s.column_name || ') FROM ' || s.table_schema || '.' || s.table_name AS sql_code 
					FROM serials s
		LOOP
			EXECUTE serial_row.sql_code INTO min_return, max_return;
			UPDATE serials s SET min_value = min_return, max_value = max_return, downcast_possible = TRUE
				WHERE s.table_schema = serial_row.table_schema AND s.table_name = serial_row.table_name AND s.column_name = serial_row.column_name;
			
			UPDATE serials s SET downcast_possible = (s.numeric_precision > LOG(s.max_value))
				WHERE s.max_value IS NOT NULL;
	END LOOP;
	
	RETURN QUERY SELECT s.table_schema, s.table_name, s.column_name, s.column_default, s.is_nullable, s.data_type, 
				s.numeric_precision, s.numeric_scale, s.n_live_tup, s.min_value, s.max_value, s.downcast_possible FROM serials s;
END;
$$;
