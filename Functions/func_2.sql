-- 2. Create a function that will return a list of films by part of the title in stock (for example, films with the word 'love' in the title).
-- the function takles a string with wildcards and the part of the film title as an input parameter
CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(string TEXT)
-- and returns the result in the table format
RETURNS TABLE(row_num BIGINT,			  
			  film_title TEXT, 
			  language CHAR(20),
			  customer_name TEXT,
			  rental_date TIMESTAMP WITH TIME ZONE
			 ) AS $$
BEGIN
-- the function returns the following query
	    RETURN QUERY
-- cte to get main information: title, language, customers, rental dates	    
		WITH get_info AS (
-- use disctinct on construction to select the first row of each group (grouped by inventory_id - film copy)
-- as the rows are ordered by rental date in descending order, the function will select the most recent customer of each film		
						SELECT DISTINCT ON (i.inventory_id) i.inventory_id,
							   f.title,
						       l.name AS lang,
						       -- if a film wasn't rented yet the column will be filled with this information
						       COALESCE(c.first_name || ' ' || c.last_name, 'NOT RENTED YET') AS customer,
						       r.rental_date AS rental,
						       r.return_date
						FROM            film f
						INNER JOIN      language l
						ON              f.language_id = l.language_id
						INNER JOIN      inventory i
						ON              f.film_id = i.film_id
						-- use left join to include not rented films (this fims will have nulls in rental and customer information)
						LEFT OUTER JOIN rental r
						ON              i.inventory_id = r.inventory_id
						LEFT OUTER JOIN customer c
						ON              r.customer_id = c.customer_id
						-- the function filters film by title according to the input string (case insensitive search)
						WHERE           f.title ILIKE string
						ORDER BY        i.inventory_id, 
						                r.rental_date DESC
		),
		-- remain only rows with no rented copies (customer - not rented yet) and rented + returned films
		filtering AS (
						SELECT * 
						FROM get_info 
						WHERE customer = 'NOT RENTED YET' OR 
							  return_date IS NOT NULL)
		-- window function implementation (self join)
		SELECT (SELECT COUNT(*)
        			   FROM   filtering t2
        			   WHERE  t2.inventory_id <= t1.inventory_id) AS row_num,
		       title,
		       lang,
		       customer,
		       rental
		FROM   filtering AS t1
		ORDER  BY t1.title; 
		-- if no rows are selected, the function returns a message
		IF NOT FOUND THEN
		      RAISE NOTICE 'a movie with that title was not found';
		    END IF;
END;
$$ LANGUAGE plpgsql;

-- test
-- SELECT * FROM public.films_in_stock_by_title('%academy%');
-- SELECT * FROM public.films_in_stock_by_title('%tefrvdri%');