-- 1. What operations do the following functions perform: film_in_stock, film_not_in_stock, inventory_in_stock, get_customer_balance, 
-- inventory_held_by_customer, rewards_report, last_day?

-- inventory_in_stock
/* This function returns a boolean value indicating whether an item is in stock or not.
 * It takes one parameter, inventory_id, which is the ID of the inventory item. 
 * An item is considered in-stock if either there are no rows in the rental table for the item or all rows have a populated return_date.
 * The function first checks the number of rows for the item in question in the rental table. If there are no rows, it returns true. 
 * If there are rows in the rental table, the function counts the number of rows where the return_date for the item in question is null.
 * If there are no rows with a null return_date (count = 0), it returns true, meaning the item is in stock. Otherwise, it returns false, indicating the item is not in stock.
 */

-- film_in_stock
/* This function returns the number of actual in-stock copies of each film that are represented in the inventory table.
 * The inventory table has one row for each copy of a specific film in a particular store.
 * The function takes film_id and store_id as input parameters and returns a set of unique row identifiers, each representing a copy of the specified film in the specified store.
 * The WHERE clause includes a call to the inventory_in_stock function, which checks if the item is in stock and returns true in that case.
 */

-- film_not_in_stock
/* This function returns the copies of a specified film in a specified store that are not in stock. 
 * It takes the same input parameters as the previous function and returns unique row identifiers (inventory_id) for each not in stock copy of the film. 
 * Each row represents a not in stock copy of the film in question (that is rented at the moment).
 * The WHERE clause includes a call to the inventory_in_stock function with the NOT keyword, which checks if the item is in stock and returns true in that case.
 */

-- get_customer_balance
/* This function calculates the current balance of a customer given a customer ID and an effective date (input parameters).
 * It declares three variables: the sum of rental rates for rented films, the sum of overcharge payments, and the sum of payments made by the customer previously. 
 * The first variable stores the sum of rental rates for all films rented by the customer in question. 
 * The second variable stores the sum of payments where the actual rental duration exceeds the rental duration for a film and charges $1 for each additional day. 
 * 'IF A FILM IS MORE THAN RENTAL_DURATION * 2 OVERDUE, CHARGE THE REPLACEMENT_COST' - this rule is not implemented;
 * The third variable stores the sum of all payments made before the effective_date (an input parameter). 
 * The function returns the sum of rental fees plus overfees minus payments made by the customer, resulting in the balance.
 */

-- inventory_held_by_customer
/* This function returns the ID of a customer (output parameter) who currently holds an inventory item with the specified ID (input parameter).
 * The function declares a v_customer_id variable to store the customer ID.
 * The WHERE clause is used to select a record with a nullable return date. If no such record is found, the function returns NULL.
 */

-- rewards_report
/* The function generates a report of customers who have made more than a specified minimum value of monthly purchases 
 * and have spent more than a specified minimum dollar amount for the month three months ago. 
 * The function first validates the input parameters and raises an exception if one of them\or both are null. 
 * It then calculates the start date of the period (current date minus three months).
 * Then it creates the first day of the month from the start_date variable: extracts year + extracts month + 01 (the first day).
 * Then it selects the last day of this month into last_month_end variable (last_day function). 
 * A temporary table is created to store customer IDs with payment dates that fall within the specified period, 
 * and the purchases are filtered based on the minimum amount of purchases and minimum dollar amount. 
 * The function then returns all customer information for the matching customers (INNER JOIN temporary table and customers table),
 * and finally drops the temporary table to clean up.
 */

-- last_day
/* This function calculates the last day of a given month by taking a timestamp with time zone as an input parameter. 
 * It has an IMMUTABLE keyword, which means that it will always return the same result for the same input.
 * The function extracts the month from the input timestamp and calculates the last day of the month depending on whether the month is December or another month. 
 * If the month is December, the function calculates the last day of the month by subtracting one day from the first day of the following year.
 * If the month is not December, the function subtracts one day from the first day of the following month.
 */


-- 2. Why does ‘rewards_report’ function return 0 rows? Correct and recreate the function, so that it's able to return rows properly.
/* The function takes CURRENT_DATE for calculation and the data in the payment table is from 2017, so no rows will be returned.
 */
CREATE OR REPLACE FUNCTION rewards_report(min_monthly_purchases integer, min_dollar_amount_purchased numeric) RETURNS SETOF customer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
    last_month_start DATE;
    last_month_end DATE;
    max_date_available DATE;
rr RECORD;
tmpSQL TEXT;
BEGIN
	-- find max available date from the data
	SELECT MAX(payment_date) INTO max_date_available FROM payment;
    last_month_start := max_date_available - '3 month'::interval;
    last_month_start := to_date((extract(YEAR FROM last_month_start) || '-' || extract(MONTH FROM last_month_start) || '-01'),'YYYY-MM-DD');
    last_month_end := LAST_DAY(last_month_start);

    /*
    Create a temporary storage area for Customer IDs.
    */
    CREATE TEMPORARY TABLE tmpCustomer (customer_id INTEGER NOT NULL PRIMARY KEY);

    /*
    Find all customers meeting the monthly purchase requirements
    */

    tmpSQL := 'INSERT INTO tmpCustomer (customer_id)
        SELECT p.customer_id
        FROM payment AS p
        WHERE DATE(p.payment_date) BETWEEN '||quote_literal(last_month_start) ||' AND '|| quote_literal(last_month_end) || '
        GROUP BY customer_id
        HAVING SUM(p.amount) > '|| min_dollar_amount_purchased || '
        AND COUNT(customer_id) > ' ||min_monthly_purchases ;

    EXECUTE tmpSQL;

    /*
    Output ALL customer information of matching rewardees.
    Customize output as needed.
    */
    FOR rr IN EXECUTE 'SELECT c.* FROM tmpCustomer AS t INNER JOIN customer AS c ON t.customer_id = c.customer_id' LOOP
        RETURN NEXT rr;
    END LOOP;

    /* Clean up */
    tmpSQL := 'DROP TABLE tmpCustomer';
    EXECUTE tmpSQL;

RETURN;
END
$_$;

--test
-- SELECT * FROM rewards_report(1, 1)


-- 3. Is there any function that can potentially be removed from the dvd_rental codebase? If so, which one and why?
-- probably, last day function functionality can we implementd into rewards_report function;
-- film_in_stock and film_not_in_stock can be united into one function:
-- we add an additional parameter p_status that can be 'in_stock' or 'not_in_stock'
CREATE OR REPLACE FUNCTION item_check(p_film_id integer, p_store_id integer, p_status TEXT, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
    SELECT inventory_id
     FROM inventory
     WHERE film_id = $1
     AND store_id = $2
     AND ((p_status = 'in_stock' AND inventory_in_stock(inventory_id)) OR 
     	  (p_status = 'not_in_stock' AND NOT inventory_in_stock(inventory_id))
		 );
    $_$;
   
-- test   
 SELECT * FROM item_check (1, 2, 'not_in_stock');


-- 4. The ‘get_customer_balance’ function describes the business requirements for calculating the client balance. Unfortunately, not all of 
-- them are implemented in this function. Try to change function using the requirements from the comments.
-- 'IF A FILM IS MORE THAN RENTAL_DURATION * 2 OVERDUE, CHARGE THE REPLACEMENT_COST' - is not implemented in the function;
CREATE OR REPLACE FUNCTION public.get_customer_balance(p_customer_id integer, p_effective_date timestamp with time zone)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_rentfees DECIMAL(5,2); 
    v_overfees INTEGER;      
    v_payments DECIMAL(5,2);
BEGIN
    SELECT COALESCE(SUM(film.rental_rate),0) INTO v_rentfees
    FROM film, inventory, rental
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    SELECT COALESCE(SUM(CASE 
                           WHEN (rental.return_date - rental.rental_date) > (film.rental_duration * '1 day'::interval)
                           THEN EXTRACT(epoch FROM ((rental.return_date - rental.rental_date) - (film.rental_duration * '1 day'::interval)))::INTEGER / 86400 
                           WHEN (rental.return_date - rental.rental_date) > 2*(film.rental_duration * '1 day'::interval)
                           THEN replacement_cost
                           ELSE 0
                        END),0) 
    INTO v_overfees
    FROM rental, inventory, film
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    SELECT COALESCE(SUM(payment.amount),0) INTO v_payments
    FROM payment
    WHERE payment.payment_date <= p_effective_date
    AND payment.customer_id = p_customer_id;

    RETURN v_rentfees + v_overfees - v_payments;
END
$function$
;

-- 5. * How do ‘group_concat’ and ‘_group_concat’ functions work? (database creation script might help) Where are they used?
/* _group_concat function takes two input parameters type text and concatenates tham into a single string, separated by a delimiter such as a comma and a space.
 * If one of the inputs is NULL, then the output is equal to the non-NULL input. 
 * If neither input parameter is NULL, then the output is equal to the concatenation of the first and the second input parameters.
 */

/* group_concat is an aggregate function takes one input parameter of text type and and concatenates it with a comma and a space. 
 * The state transition function SFUNC is previously defined _group_concat function, which is used to implement the aggregate behavior.
 * The aggregate function is used to concatenate multiple rows of text into one string and return the concatenated string.
 */
-- This function used in views to concatenate first, last names etc.

-- 6. What does ‘last_updated’ function do? Where is it used? 
/* This function creates a trigger that will automatically update the last_update field to the current timestamp 
 * when the update is performed on the table, associated with the trigger.
 * The trigger is associsted with many tables in the db (that have last_updated filed).
 */

-- 7. What is tmpSQL variable for in ‘rewards_report’ function? Can this function be recreated without EXECUTE statement and dynamic SQL? Why?
/* The tmpSQL variable is used to store a string of SQL code that will be executed later in the function (after the EXECUTE statement). 
 * The use of dynamic SQL can be necessary when the exact table or column names are not known until runtime, or when the query needs to return a varying number of columns.
 * Nevertheless, I tried to recreate this function without dynamic SQL and temporary table.  
*/
CREATE OR REPLACE FUNCTION test(min_monthly_purchases integer, min_dollar_amount_purchased numeric) 
RETURNS TABLE 
(p_customer_id INTEGER,
store_id SMALLINT,
first_name TEXT,
last_name TEXT,
email TEXT,
address_id SMALLINT,
activebool boolean,
create_date date,
last_update timestamp WITH time ZONE,
active INTEGER)
    AS $_$
DECLARE
    last_month_start DATE;
    last_month_end DATE;
BEGIN
    last_month_start := '2017-02-01'::DATE - '1 month'::interval;
    last_month_start := to_date((extract(YEAR FROM last_month_start) || '-' || extract(MONTH FROM last_month_start) || '-01'),'YYYY-MM-DD');
    last_month_end := LAST_DAY(last_month_start);
RETURN QUERY
SELECT * FROM customer WHERE customer_id IN (
        SELECT customer_id
        FROM payment AS p
        WHERE DATE(p.payment_date) BETWEEN last_month_start AND last_month_end
        GROUP BY customer_id
        HAVING SUM(p.amount) > min_dollar_amount_purchased
        AND COUNT(p.customer_id) >  min_monthly_purchases);
END;
$_$ LANGUAGE plpgsql;

-- tests
-- old function
SELECT * FROM rewards_report(1, 1);
-- new function
SELECT * FROM test(1, 1);