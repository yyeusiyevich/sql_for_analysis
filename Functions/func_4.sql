-- DROP FUNCTION public.get_client_info;
CREATE OR REPLACE FUNCTION public.get_client_info (
-- input parameters: customer_id and boundaries as timestamps
  client_id INTEGER,
  left_time_boundary TIMESTAMP,
  right_time_boundary TIMESTAMP
)
-- output as a table with two columns of text type (because we will have different data types in the output)
RETURNS TABLE (
  metric_name TEXT,
  metric_value TEXT
)
AS $$
DECLARE
-- store all info we will get into variables
  customer_info VARCHAR(100);
  num_films INTEGER;
  rented_films TEXT;
  num_payments INTEGER;
  total_amount NUMERIC(10,2);
BEGIN
  -- check client id for existence
  IF NOT EXISTS (SELECT * FROM public.customer WHERE customer_id = client_id) THEN
  RAISE NOTICE 'Client not found';
  RETURN;
  END IF;
  -- calculate all data we need for the client
  SELECT
  	-- create string for customer data
    CONCAT(first_name, ' ', last_name, ', ', email),
    COUNT(r.rental_id),
    -- remain only unique films rented
    STRING_AGG(DISTINCT f.title, ', '),
    COUNT(p.payment_id),
    SUM(p.amount)
  INTO
  -- put values into our variables
    customer_info, 
    num_films, 
    rented_films, 
    num_payments, 
    total_amount
  FROM film AS f 
  -- I'm not sure if number of payments can be greater than number of rentals; 
  -- In our test data, they are equal, but I used a right join just in case they won't be equal;
  -- Theoretically, a customer could make multiple payments for the same rental, 
  -- such as paying in parts or first paying for the rental and then for a replacement;
  INNER JOIN inventory i ON f.film_id = i.film_id 
  INNER JOIN rental AS r ON r.inventory_id = i.inventory_id 
  INNER JOIN customer AS c ON c.customer_id = r.customer_id
  RIGHT OUTER JOIN payment AS p ON p.customer_id  = c.customer_id 
  -- date and customer filtering
  WHERE c.customer_id = client_id AND 
  		p.payment_date BETWEEN left_time_boundary AND right_time_boundary AND 
  		r.rental_date BETWEEN left_time_boundary AND right_time_boundary
  GROUP BY c.first_name, c.last_name, c.email;
 
 -- create our table
 -- if no filns were rented - return message;
  IF num_films IS NULL THEN
    RETURN QUERY SELECT 'No films was rented within specified period for this client.' AS metric_name, '' AS metric_value;
  ELSE
  RETURN QUERY
  SELECT 
    'Payments'' amount' AS t_metric_name, 
    -- transform all values to text format
    total_amount::TEXT AS t_metric_value
  UNION
  SELECT 
    'Number of payments', 
    num_payments::TEXT
  UNION
  SELECT 
    'Rented films'' titles', 
    rented_films::TEXT 
  UNION
  SELECT 
    'Number of films rented', 
    num_films::TEXT 
  UNION
  SELECT 
    'Customer''s_info', 
    customer_info::TEXT
  ORDER BY t_metric_name;
  END IF;
END;
$$
LANGUAGE plpgsql;


-- test
SELECT * FROM public.get_client_info(193, '2017-01-01', '2017-12-31');
SELECT * FROM public.get_client_info(550, '2017-01-01', '2017-12-31');
SELECT * FROM public.get_client_info(15, '2017-01-01', '2017-12-31');
-- no films rented
SELECT * FROM public.get_client_info(1, '2017-01-01', '2017-12-31');
-- no client
SELECT * FROM public.get_client_info(11156, '2017-01-01', '2017-12-31');
-- was an error
SELECT * FROM public.get_client_info(56,'2017-01-01','2017-05-01');