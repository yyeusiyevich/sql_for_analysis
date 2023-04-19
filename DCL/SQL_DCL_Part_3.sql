-- 3. Configure row-level security for your database, so that the customer can only access 
-- his own data in "rental" and "payment" tables (verify using the personalized role you previously created).
-- enable row level security on the table
ALTER TABLE rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer ENABLE ROW LEVEL SECURITY;

-- policy creation; 
/* I assumed that all clients would have the same login pattern, like in the first task requirement (client_firstname_lastname), 
 * so I set all access and policies accordingly. Additionally, to give access to the rental and payment tables 
 * based on the customer's first and last name (and customer_id), I needed to grant access and create an appropriate policy 
 * for the customer table.
 */

-- read access and policy for customer table
GRANT SELECT ON public.customer TO customer;
-- create customer policy
DO $$
BEGIN
  IF EXISTS (SELECT * FROM pg_policy WHERE polname = 'customer_policy' AND polrelid = 'public.customer'::regclass) THEN
    ALTER POLICY customer_policy ON public.customer
      -- extract customer data from current user
      USING (CONCAT(first_name, '_', last_name) = UPPER(SUBSTRING(CURRENT_USER, 8)));
  ELSE
    CREATE POLICY customer_policy ON public.customer
      USING (CONCAT(first_name, '_', last_name) = UPPER(SUBSTRING(CURRENT_USER, 8)));
  END IF;
END
$$;

-- read access and policy for rental and payment tables
GRANT SELECT ON public.rental TO customer;
GRANT SELECT ON public.payment TO customer;

-- create policy for rental
DO $$
BEGIN
  IF EXISTS (SELECT * FROM pg_policy WHERE polname = 'customer_policy' AND polrelid = 'public.rental'::regclass) THEN
    ALTER POLICY customer_policy ON public.rental
      -- extract customer data from current user
        USING (customer_id = (
		  SELECT customer_id FROM public.customer 
		  WHERE CONCAT(first_name, '_', last_name) = UPPER(SUBSTRING(CURRENT_USER, 8))
));
  ELSE
    CREATE POLICY customer_policy ON public.rental
      USING (customer_id = (
		  SELECT customer_id FROM public.customer 
		  WHERE CONCAT(first_name, '_', last_name) = UPPER(SUBSTRING(CURRENT_USER, 8))
));
  END IF;
END
$$;
-- and payment tables 
DO $$
BEGIN
  IF EXISTS (SELECT * FROM pg_policy WHERE polname = 'customer_policy' AND polrelid = 'public.payment'::regclass) THEN
    ALTER POLICY customer_policy ON public.payment
      -- extract customer data from current user
        USING (customer_id = (
		  SELECT customer_id FROM public.customer 
		  WHERE CONCAT(first_name, '_', last_name) = UPPER(SUBSTRING(CURRENT_USER, 8))
));
  ELSE
    CREATE POLICY customer_policy ON public.payment
      USING (customer_id = (
		  SELECT customer_id FROM public.customer 
		  WHERE CONCAT(first_name, '_', last_name) = UPPER(SUBSTRING(CURRENT_USER, 8))
));
  END IF;
END
$$;
 
-- DROP POLICY customer_policy ON public.rental;
-- DROP POLICY customer_policy ON public.payment;
-- DROP POLICY customer_policy ON public.customer;


-- check all privileges granted
SELECT grantee, privilege_type, table_name, grantor 
FROM information_schema.role_table_grants
WHERE grantee = 'customer';

-- create policy for developers and testers to manipulate/read data in RLS tables
-- the second option was to create tester and dev roles with BYPASSRLS option (but I think it's not a preferrable one)

-- I created additional policies because when I altered tables and enabled RLS my dev and tester roles see no rows in affected tables.
-- I concluded that I should either re-grant them their privileges (like in the second task) or create an additional policies for them.
DO $$
BEGIN
  IF EXISTS (SELECT * FROM pg_policy WHERE polname = 'dev_all' AND polrelid = 'public.customer'::regclass) THEN
    ALTER POLICY dev_all ON public.customer
        USING(true) WITH CHECK (true);
  ELSE
    CREATE POLICY dev_all ON public.customer
      USING(true) WITH CHECK (true);
  END IF;
END
$$;
DO $$
BEGIN
  IF EXISTS (SELECT * FROM pg_policy WHERE polname = 'dev_all' AND polrelid = 'public.rental'::regclass) THEN
    ALTER POLICY dev_all ON public.rental
        USING(true) WITH CHECK (true);
  ELSE
    CREATE POLICY dev_all ON public.rental
      USING(true) WITH CHECK (true);
  END IF;
END
$$;
DO $$
BEGIN
  IF EXISTS (SELECT * FROM pg_policy WHERE polname = 'dev_all' AND polrelid = 'public.payment'::regclass) THEN
    ALTER POLICY dev_all ON public.payment
        USING(true) WITH CHECK (true);
  ELSE
    CREATE POLICY dev_all ON public.payment
      USING(true) WITH CHECK (true);
  END IF;
END
$$;
-- tester policies
DO $$
BEGIN
  IF EXISTS (SELECT * FROM pg_policy WHERE polname = 'tester' AND polrelid = 'public.customer'::regclass) THEN
    ALTER POLICY tester ON public.customer
        USING(true) WITH CHECK (true);
  ELSE
    CREATE POLICY tester ON public.customer
      USING(true) WITH CHECK (true);
  END IF;
END
$$;
DO $$
BEGIN
  IF EXISTS (SELECT * FROM pg_policy WHERE polname = 'tester' AND polrelid = 'public.rental'::regclass) THEN
    ALTER POLICY tester ON public.rental
        USING(true) WITH CHECK (true);
  ELSE
    CREATE POLICY tester ON public.rental
      USING(true) WITH CHECK (true);
  END IF;
END
$$;
DO $$
BEGIN
  IF EXISTS (SELECT * FROM pg_policy WHERE polname = 'tester' AND polrelid = 'public.payment'::regclass) THEN
    ALTER POLICY tester ON public.payment
        USING(true) WITH CHECK (true);
  ELSE
    CREATE POLICY tester ON public.payment
      USING(true) WITH CHECK (true);
  END IF;
END
$$;
-- list of policies
SELECT * FROM pg_policy;

--_________________TESTS PART_________________


--_____________CONNECT TO THE DATABASE AS USER_____________
-- username: client_mary_smith, password: password;
-- try to perform the following statements: client_mary_smith should see only rows with appropriate customer_id (1);
-- developers and tester can still see all rows;
SELECT * FROM public.rental;
SELECT * FROM public.payment;
SELECT * FROM public.customer;