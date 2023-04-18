-- All comedy movies released between 2000 and 2004, alphabetical;
SELECT film.title
FROM   film
--selecting all rows from the film_category where the film_id column matches the film_id column in the film table
WHERE  EXISTS (SELECT 0
               FROM   film_category f_cat
               WHERE  f_cat.film_id = film.film_id
-- including rows in the category table that have a category_id that matches the category_id of the film_category row 
-- and a name column with the value 'COMEDY'               
                      AND EXISTS (SELECT 0
                                  FROM   category cat
                                  WHERE  f_cat.category_id = cat.category_id
                                         AND UPPER(cat.name) = 'COMEDY'))
-- filter only films with a release year between 2000 and 2004 (inclusive)                                         
       AND film.release_year BETWEEN 2000 AND 2004
-- sorting alphabetically       
ORDER  BY film.title; 


-- Revenue of every rental store for year 2017;
-- combining two address fileds into a single column
SELECT CONCAT(adr.address, ' ', adr.address2) AS address, 
       SUM(pm.amount)                         AS revenue
FROM   payment pm
       INNER JOIN rental rnt
               ON pm.rental_id = rnt.rental_id
       INNER JOIN inventory inv
               ON rnt.inventory_id = inv.inventory_id
       INNER JOIN store str
               ON inv.store_id = str.store_id
       INNER JOIN address adr
               ON str.address_id = adr.address_id
-- filtering the results to include only payments made in the year 2017                
WHERE  EXTRACT(year FROM pm.payment_date) = 2017
GROUP  BY adr.address,
          adr.address2; 


-- Top-3 actors by number of movies they took part in, sorted by number_of_movies in descending order);
SELECT actor.first_name,
       actor.last_name,
-- calculating the number of movies for each actor       
       COUNT(*) AS number_of_movies
FROM   actor
       INNER JOIN film_actor
               ON actor.actor_id = film_actor.actor_id
GROUP  BY actor.actor_id
-- sorting the results in descending order by the number of movies for each actor
ORDER  BY number_of_movies DESC
-- return only the top 3 actors
LIMIT  3;


-- Number of comedy, horror and action movies per year, sorted by release year in descending order
WITH movies_per_year
     AS (SELECT film.release_year,
                -- calculating the number of action, horror, and comedy movies for each year (0 - no movies in this category)
                SUM(CASE
                      WHEN UPPER(cat.NAME) = 'ACTION' THEN 1
                      ELSE 0
                    END) AS number_of_action_movies,
                SUM(CASE
                      WHEN UPPER(cat.NAME) = 'HORROR' THEN 1
                      ELSE 0
                    END) AS number_of_horror_movies,
                SUM(CASE
                      WHEN UPPER(cat.NAME) = 'COMEDY' THEN 1
                      ELSE 0
                    END) AS number_of_comedy_movies
         FROM   film
                INNER JOIN film_category f_cat
                        ON film.film_id = f_cat.film_id
                INNER JOIN category cat
                        ON f_cat.category_id = cat.category_id
         GROUP  BY film.release_year)
SELECT *
FROM   movies_per_year AS mov_year
--  excluding years with empty results
WHERE  mov_year.number_of_action_movies
       + mov_year.number_of_horror_movies
       + mov_year.number_of_comedy_movies > 0
-- sorting the results in descending order by the 'release_year' column
ORDER  BY mov_year.release_year DESC; 


-- Staff members made the highest revenue for each store and deserve a bonus for 2017 year;
-- CTE to calculate the total revenue made by each staff member in each store
WITH revenue_per_staff
     AS (SELECT stf.store_id,
 -- -- combining two fileds (first and last name) into a single column    
                stf.first_name
                || ' '
                || stf.last_name AS staff_name,
                SUM(pm.amount)   AS total_revenue
         FROM   staff stf
                INNER JOIN payment pm
                        ON stf.staff_id = pm.staff_id
-- filter payments only for 2017                        
         WHERE  EXTRACT(year FROM pm.payment_date) = 2017
         GROUP  BY stf.store_id,
                   stf.staff_id)
SELECT CONCAT(adr.address, ' ', adr.address2) AS address,
       rps.staff_name,
       rps.total_revenue
FROM   revenue_per_staff rps
INNER JOIN store ON rps.store_id = store.store_id
INNER JOIN address adr ON store.address_id = adr.address_id
-- subquery that returns the maximum revenue value for each store
WHERE  rps.total_revenue = (SELECT MAX(rps2.total_revenue)
                            FROM   revenue_per_staff rps2
                            WHERE  rps2.store_id = rps.store_id);



--  5 movies were rented more than others and what's expected audience age for those movies;
SELECT film.title, 
       (CASE film.rating
            WHEN 'G' THEN 'All ages'
            WHEN 'PG' THEN 'All ages'
            WHEN 'PG-13' THEN '13+'
            WHEN 'R' THEN '17+'
            WHEN 'NC-17' THEN '18+'
            ELSE 'Unknown'
        END) AS expected_age,
-- count the number of rentals for each film      
       COUNT(*) AS rental_count
FROM   rental rnt
       INNER JOIN inventory inv
               ON rnt.inventory_id = inv.inventory_id
       INNER JOIN film
               ON inv.film_id = film.film_id
GROUP  BY film.film_id
-- sort the results in descending order by rental count
ORDER  BY rental_count DESC
-- return only the top 5 films
LIMIT  5; 


-- Actors/actresses didn't act for a longer period of time than others
-- this CTE find the maximum gap between two films for each actor
WITH actor_gap
     AS (SELECT a.actor_id,
                a.first_name,
                a.last_name,
-- function is used to find the maximum value of the max_gap column for each group (actor)                
                MAX(max_gap) AS max_gap
         FROM   actor a
-- subquery to find the previous release year for each film
                INNER JOIN (SELECT fa.actor_id,
-- subtracting the previous release year from the current release year for each row                
                                   ( f.release_year -
                                     (SELECT MAX(f2.release_year)
                                      FROM   film_actor fa2
                                             JOIN film f2
                                               ON fa2.film_id =
                                                  f2.film_id
-- clause to find previous release year for each row                                                  
                                      WHERE
                                     fa2.actor_id = fa.actor_id
                                     AND f2.release_year <
                                         f.release_year) ) AS
                                     max_gap
                            FROM   film_actor fa
                                   JOIN film f
                                     ON fa.film_id = f.film_id) t
                        ON a.actor_id = t.actor_id
         GROUP  BY a.actor_id,
                   a.first_name,
                   a.last_name)
SELECT first_name
       || ' '
       || last_name AS actor_name,
       max_gap
FROM   actor_gap
GROUP  BY actor_name,
          max_gap
-- filtering the results to include only actors who have the maximum gap among all actors          
HAVING max_gap = (SELECT MAX(max_gap)
                  FROM   actor_gap)
ORDER  BY actor_name; 


