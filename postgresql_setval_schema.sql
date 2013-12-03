/*
SETVAL for all sequences in a schema

In PostgreSQL, when you’re working with sequences, if you insert a future value due to the incrementing values, you will get an error
 when that value is going to be inserted. I like much more how SQL Server handles autoincrement columns with its IDENTITY property, 
 that would be like the sequences linked to a table like SERIAL, but it’s much more restrictive and by default you cannot INSERT a register
 specifying the value of this column as you can do with PostgreSQL.

The PostgreSQL setval() function, explained in Sequence Manipulation Functions (http://www.postgresql.org/docs/current/interactive/functions-sequence.html), 
is the way that PostgreSQL has to change the value of a sequence. But only accepts one table as a parameter. 
So, if you need to set all the sequences in a schema to the max(id) of every table, 
you can do can use the following script, based on Updating sequence values from table select (http://wiki.postgresql.org/wiki/Fixing_Sequences).

*/

CREATE OR REPLACE FUNCTION setval_schema(schema_name name, raise_notice boolean = false)
  RETURNS VOID AS
-- Sets all the sequences in the schema "schema_name" to the max(id) of every table
$BODY$

DECLARE
    row_data RECORD;
    sql_code TEXT;
    
BEGIN
	IF ((SELECT COUNT(*) FROM pg_namespace WHERE nspname = schema_name) = 0) THEN
		RAISE EXCEPTION 'The schema "%" does not exist', schema_name;
	END IF;
	
	--select COUNT(*) from pg_class;
	FOR sql_code IN 
		SELECT 'SELECT SETVAL(' ||quote_literal(N.nspname || '.' || S.relname)|| ', MAX(' ||quote_ident(C.attname)|| ') ) FROM ' || quote_ident(N.nspname) || '.' || quote_ident(T.relname)|| ';' AS sql_code
		FROM pg_class AS S
		INNER JOIN pg_depend AS D ON S.oid = D.objid
		INNER JOIN pg_class AS T ON D.refobjid = T.oid
		INNER JOIN pg_attribute AS C ON D.refobjid = C.attrelid AND D.refobjsubid = C.attnum
		INNER JOIN pg_namespace N ON N.oid = S.relnamespace
		WHERE S.relkind = 'S' AND N.nspname = schema_name
		ORDER BY S.relname
	LOOP
		IF (raise_notice) THEN
			RAISE NOTICE 'sql_code: %', sql_code;
		END IF;
		EXECUTE sql_code;
	END LOOP;	

END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE;


-- Execution example:

-- Example to execute setval to all sequences in a schema
SELECT setval_schema('public');

-- Example to execute setval to all sequences in all user schemas in the database
-- Showing the sentences that are being executed
SELECT setval_schema(nspname, true)
FROM pg_namespace
WHERE nspname !~ '^pg_.*' AND nspname <> 'information_schema';




/* 
Full example

In this example, a table is created and some registers are inserted. The 3rd insert 'Third Value - Jumping' is forced to id = 7 instead of using the 
 sequence. But the sequence hasn't been modified so when it would arrive to 7 it would get an error because the value already exists.
*/

CREATE TABLE public.test_setval
(
  id serial NOT NULL,
  info text NOT NULL,
  CONSTRAINT test_setval_pkey PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);

INSERT INTO public.test_setval (info) VALUES ('First Value');
INSERT INTO public.test_setval (info) VALUES ('Second Value');
INSERT INTO public.test_setval (id, info) VALUES (7,'Third Value - Jumping');
INSERT INTO public.test_setval (info) VALUES ('Forth Value');

-- 'Forth Value' is inserted with id = 3
SELECT * FROM public.test_setval;

SELECT setval_schema('public', true);

INSERT INTO public.test_setval (info) VALUES ('Fifth Value - after setval');


-- You can see how the data has been inserted in the same sequencial order
SELECT * FROM public.test_setval;

-- or sortering it
SELECT * FROM public.test_setval ORDER BY id;

