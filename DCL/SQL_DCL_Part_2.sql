-- Implement role-based authentication model for dvd_rental database:
-- create group roles (db_developer, backend_tester, customer)
DO $$
DECLARE
  role_name TEXT;
BEGIN	
  FOR role_name IN VALUES ('db_developer'), ('backend_tester'), ('customer')
  LOOP
    IF NOT EXISTS (SELECT * FROM pg_roles WHERE rolname = role_name) THEN
      EXECUTE 'CREATE ROLE ' || quote_ident(role_name);
    ELSE
      RAISE NOTICE 'Role "%"', role_name || '" already exists. Skipping.';
    END IF;
  END LOOP;
END
$$;
-- assign proper priveleges
-- privileges for db_developer may vary depending on the specific needs and requirements of an organization; 
-- here I granted all privileges on the public schema to this role;
GRANT ALL PRIVILEGES ON SCHEMA public TO db_developer;
-- all privileges on tables to operate with
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO db_developer;
-- privileges to insert data
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO db_developer;
-- check granted privileges
SELECT grantee, privilege_type, table_name, grantor 
FROM information_schema.role_table_grants
WHERE grantee = 'db_developer';

-- read-only privileges for backed_tester role
-- access to schema objects
GRANT USAGE ON SCHEMA public TO backend_tester;
-- read-only access to the tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backend_tester;
-- check privileges
SELECT grantee, privilege_type, table_name, grantor 
FROM information_schema.role_table_grants
WHERE grantee = 'backend_tester';
-- similar set of privileges can be granted via pg_read_all_date role,
-- but it gives read permissions on all schemas that might be undesirable;

-- read-only privileges on two tables for customer role
-- access to schema objects
GRANT USAGE ON SCHEMA public TO customer;
-- read-only access to the two tables only
GRANT SELECT ON film, actor TO customer;
-- check privileges
SELECT privilege_type, table_name 
FROM information_schema.role_table_grants
WHERE grantee = 'customer';

-- create 3 users for 3 roles
DO $$
DECLARE
  role_name TEXT;
BEGIN	
  FOR role_name IN VALUES ('dev'), ('tester'), ('cust')
  LOOP
    IF NOT EXISTS (SELECT * FROM pg_user WHERE usename = role_name) THEN
      EXECUTE 'CREATE USER ' || quote_ident(role_name) || ' WITH PASSWORD ''password''';
    ELSE
      RAISE NOTICE 'User "%"', role_name || '" already exists. Skipping.';
    END IF;
  END LOOP;
END
$$;

-- presonalized role (user)
-- function that creates a user for a random customer
CREATE OR REPLACE FUNCTION public.create_user_for_random_customer()
-- the function returns nothing, just creates a user
RETURNS void AS $$
DECLARE
  customer_first_name TEXT;
  customer_last_name TEXT;
  customer_username TEXT;
BEGIN
 -- this query selects customer data (first and last anme for user login)
  SELECT LOWER(c.first_name), LOWER(c.last_name)
  INTO customer_first_name, customer_last_name
  FROM customer c
  -- based on records existence in payment and rental tables
  WHERE c.customer_id IN (
    SELECT r.customer_id
    FROM rental AS r
    INTERSECT
    SELECT p.customer_id
    FROM payment AS p
  )
  -- select one random customer
  ORDER BY random()
  LIMIT 1;

 -- create user login from client prefix and customer data
  customer_username := 'client_' || customer_first_name || '_' || customer_last_name;
-- check for user existence
  IF NOT EXISTS (SELECT * FROM pg_user WHERE usename = customer_username) THEN
    EXECUTE 'CREATE USER ' || quote_ident(customer_username) || ' WITH PASSWORD ''password''';
    EXECUTE 'GRANT customer TO ' || quote_ident(customer_username);
  ELSE
    RAISE NOTICE 'User "%"', customer_username || '" already exists. Skipping.';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- run function
SELECT * FROM public.create_user_for_random_customer();

-- DROP USER dev;
-- DROP USER tester;
-- DROP USER cust;


-- assign roles to users
GRANT db_developer TO dev;
GRANT backend_tester TO tester;
GRANT customer TO cust;

--_________________TESTS PART_________________

--_____________USER DEV_____________
SET ROLE dev;
-- select some data
SELECT * FROM public.film LIMIT 5;
-- insert some data
INSERT INTO public.actor (first_name, last_name) VALUES ('JANE', 'DOE');
-- delete some data
DELETE FROM public.actor WHERE first_name = 'JANE' AND last_name = 'DOE';
-- call a function
SELECT * FROM public.rewards_report(1, 1);
-- reset
RESET ROLE;

--_____________USER TESTER_____________
SET ROLE tester;
-- read from table
SELECT * FROM public.film LIMIT 5;
SELECT * FROM public.payment LIMIT 5;
-- read from a  view
SELECT * FROM public.actor_info LIMIT 5;

-- this should get an error (no permissions)
--INSERT INTO public.actor (first_name, last_name) VALUES ('JANE', 'DOE');
--DELETE FROM public.actor WHERE actor_id =1;
-- reset
RESET ROLE;


--_____________USER CUST_____________
SET ROLE cust;
-- try to perform the following statements
SELECT * FROM public.film LIMIT 5;
SELECT * FROM public.actor LIMIT 5;
-- this should get an error (no permissions)
SELECT * FROM public.payment LIMIT 5;
-- reset
RESET ROLE;

-- this should get an error (no permissions)
-- INSERT INTO public.actor (first_name, last_name) VALUES ('JANE', 'DOE');
-- DELETE FROM public.actor WHERE actor_id =1;
