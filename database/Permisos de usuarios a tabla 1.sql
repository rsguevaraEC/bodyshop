DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema = 'bodyshop'
    LOOP
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE %I.%I TO appuser', r.table_schema, r.table_name);
    END LOOP;
END $$;
