-- 1. Create a function that will return the most popular film for each country (where country is an input paramenter)
-- this function takes a country list as an input
CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(IN country_list anyarray)
-- this function will return a table that will unite the results for each country
RETURNS TABLE(country TEXT, 
			  film TEXT,
			  rating public.mpaa_rating, 
			  language CHAR(20), 
			  length SMALLINT, 
			  release_year public.year) AS $$
BEGIN
	    RETURN QUERY
-- CTE with rental information abount countries	    
WITH rent_by_cust AS (
    SELECT co.country,f.title, f.rating, l.name, f.length, f.release_year, COUNT(r.rental_id) AS rental_num
	FROM   film f
		   INNER JOIN language l ON f.language_id = l.language_id
		   INNER JOIN inventory i ON f.film_id = i.film_id
		   INNER JOIN rental r  ON i.inventory_id = r.inventory_id
		   INNER JOIN customer c  ON r.customer_id = c.customer_id
		   INNER JOIN address a ON c.address_id = a.address_id
		   INNER JOIN city ci ON ci.city_id = a.city_id
		   INNER JOIN country co  ON ci.country_id = co.country_id
		   -- case insensitive search 
	WHERE  UPPER(co.country) IN (SELECT UPPER(u_country) FROM UNNEST(country_list) u_country)
	GROUP  BY co.country_id,co.country, f.title,f.rating, l.name, f.length,f.release_year
					)
SELECT filtering.country, filtering.title, filtering.rating, filtering.name, filtering.length, filtering.release_year
FROM (
  SELECT *,
  -- the only way I managed get results about all countries without a loop is to use a window function
         DENSE_RANK() OVER (PARTITION BY rent_by_cust.country ORDER BY rent_by_cust.rental_num DESC) AS rank
  FROM rent_by_cust
) filtering
-- select only films with max rental number for each country
WHERE rank = 1
ORDER BY filtering.country, filtering.title;   
END;
$$ LANGUAGE plpgsql;

-- test
-- SELECT * FROM public.most_popular_films_by_countries(array['Afghanistan','Brazil','United States']);