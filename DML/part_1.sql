-- Favourite movies insertion (Choose your top-3 favorite movies and add them to 'film' table. 
-- Fill rental rates with 4.99, 9.99 and 19.99 and rental durations with 1, 2 and 3 weeks respectively).
-- first CTE stores film data to avoid duplication in TO_TSVECTOR() function 
WITH new_films AS
(
       SELECT 'THE SHAWSHANK REDEMPTION'                                                                                                                            AS title1,
              'Two imprisoned men bond over a number of years, finding solace and eventual redemption through acts of common decency.'                              AS description1,
              'INTERSTELLAR'                                                                                                                                        AS title2,
              'A team of explorers travel through a wormhole in space in an attempt to ensure humanitys survival.'                                                  AS description2,
              'THE GREEN MILE'                                                                                                                                      AS title3,
              'The lives of guards on Death Row are affected by one of their charges: a black man accused of child murder and rape, yet who has a mysterious gift.' AS description3 ), 
-- all films are in English, so this CTE stores the language ID for this language
     lng       AS
(
       SELECT language_id
       FROM   language
       WHERE  UPPER(NAME) = 'ENGLISH' )
-- insertion part: column definition
INSERT INTO film
            (
	                         title,
	                         description,
	                         release_year,
	                         language_id,
	                         rental_duration,
	                         rental_rate,
	                         length,
	                         replacement_cost,
	                         rating,
	                         last_update,
	                         special_features,
	                         fulltext
            )
-- data definition; rating and special_features columns have custom data types (mpaa_rating and _text), so we use explicit type casting; 
-- to_tsvector parses a textual document into tokens, lists the lexemes together with their positions in the document;
SELECT title1,
       description1,
       1994 				 AS release_year,
       lng.language_id,
       7                     AS rental_duration,
       4.99                  AS rental_rate,
       142                   AS length,
       20.99                 AS replacement_cost,
       'R' :: mpaa_rating    AS rating,
       NOW()                 AS last_update,
       '{Trailers}' :: _text AS special_features,
       TO_TSVECTOR ( 'english', title1
           || ' '
           || description1 ) AS fulltext
FROM   new_films,
       lng
-- validating for the availability of inserted data       
WHERE NOT EXISTS (SELECT 1 FROM film WHERE UPPER(title) = new_films.title1 AND release_year = 1994)       
-- UNION operator joins multiple SELECT statements
UNION
SELECT title2,
       description2,
       2014 				 AS release_year,
       lng.language_id,
       14                    AS rental_duration,
       9.99                  AS rental_rate,
       169                   AS length,
       22.99                 AS replacement_cost,
       'PG-13'::mpaa_rating  AS rating,
       NOW()                 AS last_update,
       '{Commentaries, Behind the scenes}' :: _text 
       						 AS special_features,
       TO_TSVECTOR ( 'english', title2
           || ' '
           || description2 ) AS fulltext
FROM   new_films,
       lng
-- validating for the availability of inserted data        
WHERE NOT EXISTS (SELECT 1 FROM film WHERE UPPER(title) = new_films.title2 AND release_year = 2014)         
UNION
SELECT title3,
       description3,
       1999 				 AS release_year,
       lng.language_id,
       21                    AS rental_duration,
       19.99                 AS rental_rate,
       189                   AS length,
       24.99                 AS replacement_cost,
       'R' :: mpaa_rating    AS rating,
       NOW()                 AS last_update,
       '{Deleted Scenes, Behind the scenes}' :: _text 
       						 AS special_features,
       TO_TSVECTOR ( 'english', title3
           || ' '
           || description3 ) AS fulltext
FROM   new_films,
       lng
-- validating for the availability of inserted data 
WHERE NOT EXISTS (SELECT 1 FROM film WHERE UPPER(title) = new_films.title3 AND release_year = 1999)  
-- return the film data after insertion
RETURNING *;


-- Actors insertion (Add actors who play leading roles in your favorite movies to 'actor' and 'film_actor' tables).
-- CTE for storing actors data
WITH names AS (
    SELECT 'Tim' AS first_name, 'Robbins' AS last_name
    UNION
    SELECT 'Morgan', 'Freeman'
    UNION
    SELECT 'Matthew', 'McConaughey'
    UNION
    SELECT 'Anne', 'Hathaway'
    UNION
    SELECT 'Tom', 'Hanks'
    UNION
    SELECT 'David', 'Morse'
),
-- CTE for actors insertion
actors AS
(
           INSERT INTO actor
                        (
                           first_name,
                           last_name,
                           last_update
                        )
			SELECT first_name, 
				   last_name, 
				   NOW()
			FROM names
-- data validation			
			WHERE NOT EXISTS (
    							SELECT 1 FROM actor
    							WHERE first_name = names.first_name AND 
    								  last_name = names.last_name
    						 )
RETURNING * )
-- insertion into the film_actor table            
INSERT INTO film_actor
      (
       actor_id,
       film_id,
       last_update
      )
-- select actors id from CTE;
-- CASE WHEN construction to define film_id from film table based on actors data
SELECT actors.actor_id, (
       CASE
              WHEN (actors.first_name, actors.last_name) IN (('Tim', 'Robbins'), 
              												 ('Morgan', 'Freeman')) 
              	THEN
                     (SELECT film_id
                      FROM   film
                      WHERE  UPPER(title) = 'THE SHAWSHANK REDEMPTION')
              WHEN (actors.first_name, actors.last_name) IN (('Matthew', 'McConaughey'),
              												 ('Anne', 'Hathaway')) 
              	THEN
                     (SELECT film_id
                      FROM   film
                      WHERE  UPPER(title) = 'INTERSTELLAR')
              WHEN (actors.first_name, actors.last_name) IN (('Tom','Hanks'),
                                                             ('David', 'Morse')) 
              	THEN
                     (SELECT film_id
                      FROM   film
                      WHERE  UPPER(title) = 'THE GREEN MILE')
       END) AS film_id,
       NOW()
FROM   actors
-- return all inserted data
RETURNING *;


-- Store's inventory update (Add your favorite movies to any store's inventory).
INSERT INTO inventory
      (
       film_id,
       store_id,
       last_update
      )
SELECT film_id,
-- add film data to store with ID 1
       1,
       NOW()
FROM   film
-- WHERE clause to select new films IDs
WHERE  UPPER(title) IN ('INTERSTELLAR',
                 		'THE GREEN MILE',
                 		'THE SHAWSHANK REDEMPTION') AND
                 		NOT EXISTS (SELECT 1 FROM inventory WHERE film_id = film.film_id and store_id = 1)
RETURNING  *;


-- Customer's table update (Alter any existing customer in the database who has at least 43 rental and 43 payment records. Change his/her personal data to yours).
-- first we need to update address table and corresponding ones (city and country tables as well)
-- use 2 CTE to update country and city tables
WITH country_upd AS
		   (
            INSERT INTO country
                        (
                         country,
                         last_update
                        )
            SELECT 'Georgia',
                   NOW()
            WHERE NOT EXISTS (SELECT 1 FROM country WHERE country = 'Georgia')       
            RETURNING * 
			), 
     city_upd AS
		   (
            INSERT INTO city
                        (
                         city,
                         country_id,
                         last_update
                        )
            SELECT 'Tbilisi',
                   country_upd.country_id,
                   NOW()
            FROM   country_upd
            WHERE NOT EXISTS (SELECT 1 FROM city WHERE country = 'Tbilisi')    
            RETURNING * 
			)
-- insert data to the address table with city_id from previoud CTE			
INSERT INTO address
            (
             address,
             district,
             city_id,
             postal_code,
             phone,
             last_update
            )
SELECT 		 '3/15, Kobuleti Street',
       		 'Isani-Samgori',
       		 city_upd.city_id,
       		 '0114',
       		 '+995555815254',
       		 NOW()
FROM   city_upd
WHERE NOT EXISTS (SELECT 1 FROM address WHERE address = '3/15, Kobuleti Street' AND phone = '+995555815254')      
RETURNING *;

-- edit customer information
UPDATE customer
-- as all films are stored in the same store (with ID 1), we select store_id based on the any of three film titles
SET    store_id =
       (
             SELECT     store_id
             FROM       inventory i
             INNER JOIN film f
             ON         f.film_id = i.film_id
             WHERE      UPPER(f.title) = 'INTERSTELLAR'),
       first_name = 'YULIYA',
       last_name = 'YEUSIYEVICH',
       email = 'YYESIYEVICH@GMAIL.COM',
-- select address_id based on address       
       address_id =
       (
              SELECT address_id
              FROM   address
              WHERE  address = '3/15, Kobuleti Street'
              AND    district = 'Isani-Samgori'),
       create_date = NOW()::DATE,
       last_update = NOW(),
       active = 1
-- select customer with at least 43 rental and 43 payment records (task condition)        
WHERE  customer_id IN
       (   
              SELECT   rental_counts.customer_id
-- customers with 43 rentals or more                  
              FROM     (
                         SELECT   customer_id
                         FROM     rental
                         GROUP BY customer_id
                         HAVING   COUNT(*) >= 43 ) rental_counts
-- use inner join to join two conditions                         
               INNER JOIN
-- customers with 43 payments or more                   
                         (
                         SELECT   customer_id
                         FROM     payment
                         GROUP BY customer_id
                         HAVING   COUNT(*) >= 43 ) payment_counts
                ON       rental_counts.customer_id = payment_counts.customer_id
-- random selection                
                ORDER BY RANDOM()
-- select only one customer                
                LIMIT 1) 
RETURNING *;


-- Records deletion (Remove any records related to you (as a customer) from all tables except 'Customer' and 'Inventory').
DELETE FROM payment
-- in the where clause is customer ID specified according inserted data
WHERE  payment.customer_id = (SELECT customer_id
                              FROM   customer
                              WHERE  UPPER(first_name) = 'YULIYA' AND
                                     UPPER(last_name) = 'YEUSIYEVICH');

DELETE FROM rental
WHERE  rental.customer_id = (SELECT customer_id
                             FROM   customer
                             WHERE  UPPER(first_name) = 'YULIYA' AND
                                    UPPER(last_name) = 'YEUSIYEVICH'); 
                                   
   
-- Rental data insertion (Rent you favorite movies from the store they are in and pay for them).
-- first we create a partition to insert payment dates for 2023
CREATE TABLE payment_2023
PARTITION OF payment
FOR VALUES FROM ('2023-01-01') TO ('2023-12-31');

-- index creation
CREATE INDEX payment_2023_date_cust_idx ON payment_2023 (payment_date, customer_id);

-- add fk
ALTER TABLE payment_2023
ADD CONSTRAINT payment_2023_rental_fk FOREIGN KEY (rental_id) REFERENCES rental(rental_id),
ADD CONSTRAINT payment_2023_staff_fk FOREIGN KEY (staff_id) REFERENCES staff(staff_id),
ADD CONSTRAINT payment_2023_customer_fk FOREIGN KEY (customer_id) REFERENCES customer(customer_id);


-- main query (first film)
/* In this part I decided to insert records in rental and payment tables simultaneously but for each film (3 records) separately.
 * Repeatable data such as staff and customer id (defined by their first and last name) are stored in the CTE (data_cte) 
 */
WITH data_cte AS
(
       SELECT c.customer_id,
              s.staff_id,
              i.inventory_id
       FROM   customer c
       JOIN   staff s
       ON     UPPER(s.first_name) = 'HANNA'
       AND    UPPER(s.last_name) = 'RAINBOW'
       JOIN   film f
       ON     UPPER(f.title) = 'THE SHAWSHANK REDEMPTION'
       JOIN   inventory i
       ON     i.film_id = f.film_id
       WHERE  UPPER(c.first_name) = 'YULIYA'
       AND    UPPER(c.last_name) = 'YEUSIYEVICH' 
),
-- rental insertion
	  rental_insert AS
(
            INSERT INTO rental
                        (
                         rental_date,
                         inventory_id,
                         customer_id,
                         return_date,
                         staff_id,
                         last_update
                        )
            SELECT NOW() - INTERVAL '6 days' AS rental_date,
                   inventory_id,
                   customer_id,
                   NOW() - INTERVAL '3 days' AS return_date,
                   staff_id,
                   NOW()
            FROM   data_cte
            UNION
            SELECT NOW() - INTERVAL '4 days' AS rental_date,
                   inventory_id,
                   customer_id,
                   NOW() - INTERVAL '2 days' AS return_date,
                   staff_id,
                   NOW()
            FROM   data_cte
            UNION
            SELECT NOW() - INTERVAL '2 days' AS rental_date,
                   inventory_id,
                   customer_id,
                   NOW() - INTERVAL '1 days' AS return_date,
                   staff_id,
                   NOW()
            FROM   data_cte
-- return inserted data to use it further in payment part
            RETURNING customer_id,
                   	  staff_id,
                      rental_id,
                      return_date,
                      rental_date 
)
-- payment insertion
INSERT INTO payment
            (
              customer_id,
              staff_id,
              rental_id,
              amount,
              payment_date
            )
SELECT customer_id,
       staff_id,
       rental_id,
-- amount calculation: when actual rental duration exceeds rental_rate in the film table, a customer pays 1$ for each additional day
       (      SELECT
                    CASE
-- if actual rental duration within rental_duration in film table - a customer pays rental_rate                  
                            WHEN EXTRACT(DAY FROM (return_date - rental_date)) <= f.rental_duration 
                            	THEN f.rental_rate
-- if actual rental duration exceeds rental_duration in film table, but is less than rental_duration * 2,
-- a customer pays 1$ for each additional day (requirement from the original script of rental db)                             	
            				WHEN EXTRACT(DAY FROM (return_date - rental_date)) <= f.rental_duration * 2 
            					THEN f.rental_rate + 1 * (EXTRACT(DAY FROM (return_date - rental_date)) - f.rental_duration)
-- in other cases (no return date (NULL), actual rental duration exceeds rental_duration * 2 etc. - a customer pays replacement_cost             					
            				ELSE f.replacement_cost
                     END
              FROM   film f
-- specify rental_rate and rental_duration for the film in question
              WHERE  UPPER(title) = 'THE SHAWSHANK REDEMPTION'
       ) AS amount,
-- set payment date as return date (let's suppose that customer always pays for rent on return date)
       return_date
FROM   rental_insert 
RETURNING *;


-- second film insertion
WITH data_cte AS
(
       SELECT c.customer_id,
              s.staff_id,
              i.inventory_id
       FROM   customer c
       JOIN   staff s
       ON     UPPER(s.first_name) = 'HANNA'
       AND    UPPER(s.last_name) = 'RAINBOW'
       JOIN   film f
       ON     UPPER(f.title) = 'INTERSTELLAR'
       JOIN   inventory i
       ON     i.film_id = f.film_id
       WHERE  UPPER(c.first_name) = 'YULIYA'
       AND    UPPER(c.last_name) = 'YEUSIYEVICH' 
), 
	  rental_insert AS
(
            INSERT INTO rental
                        (
                         rental_date,
                         inventory_id,
                         customer_id,
                         return_date,
                         staff_id,
                         last_update
                        )
            SELECT NOW() - INTERVAL '10 days' AS rental_date,
                   inventory_id,
                   customer_id,
                   NOW() - INTERVAL '1 days' AS return_date,
                   staff_id,
                   NOW()
            FROM   data_cte
            UNION
            SELECT NOW() - INTERVAL '8 days' AS rental_date,
                   inventory_id,
                   customer_id,
                   NOW() - INTERVAL '2 days' AS return_date,
                   staff_id,
                   NOW()
            FROM   data_cte
            UNION
            SELECT NOW() - INTERVAL '6 days' AS rental_date,
                   inventory_id,
                   customer_id,
                   NOW() - INTERVAL '3 days' AS return_date,
                   staff_id,
                   NOW()
            FROM   data_cte 
            RETURNING customer_id,
                   	  staff_id,
                      rental_id,
                      return_date,
                      rental_date 
)
INSERT INTO payment
            (
              customer_id,
              staff_id,
              rental_id,
              amount,
              payment_date
            )
SELECT customer_id,
       staff_id,
       rental_id,
       (      SELECT
                     CASE
-- if actual rental duration within rental_duration in film table - a customer pays rental_rate                  
                            WHEN EXTRACT(DAY FROM (return_date - rental_date)) <= f.rental_duration 
                            	THEN f.rental_rate
-- if actual rental duration exceeds rental_duration in film table, but is less than rental_duration * 2,
-- a customer pays 1$ for each additional day (requirement from the original script of rental db)                             	
            				WHEN EXTRACT(DAY FROM (return_date - rental_date)) <= f.rental_duration * 2 
            					THEN f.rental_rate + 1 * (EXTRACT(DAY FROM (return_date - rental_date)) - f.rental_duration)
-- in other cases (no return date (NULL), actual rental duration exceeds rental_duration * 2 etc. - a customer pays replacement_cost             					
            				ELSE f.replacement_cost
                     END
              FROM   film f
              WHERE  UPPER(title) = 'INTERSTELLAR'
       ) AS amount,
       return_date
FROM   rental_insert 
RETURNING *;


-- third film insertion
WITH data_cte AS
(
       SELECT c.customer_id,
              s.staff_id,
              i.inventory_id
       FROM   customer c
       JOIN   staff s
       ON     UPPER(s.first_name) = 'HANNA'
       AND    UPPER(s.last_name) = 'RAINBOW'
       JOIN   film f
       ON     UPPER(f.title) = 'THE GREEN MILE'
       JOIN   inventory i
       ON     i.film_id = f.film_id
       WHERE  UPPER(c.first_name) = 'YULIYA'
       AND    UPPER(c.last_name) = 'YEUSIYEVICH' 
), 
	  rental_insert AS
(
            INSERT INTO rental
                        (
                         rental_date,
                         inventory_id,
                         customer_id,
                         return_date,
                         staff_id,
                         last_update
                        )
            SELECT NOW() - INTERVAL '9 days' AS rental_date,
                   inventory_id,
                   customer_id,
                   NOW() - INTERVAL '4 days' AS return_date,
                   staff_id,
                   NOW()
            FROM   data_cte
            UNION
            SELECT NOW() - INTERVAL '5 days' AS rental_date,
                   inventory_id,
                   customer_id,
                   NOW() - INTERVAL '3 days' AS return_date,
                   staff_id,
                   NOW()
            FROM   data_cte
            UNION
            SELECT NOW() - INTERVAL '3 days' AS rental_date,
                   inventory_id,
                   customer_id,
                   NOW() - INTERVAL '1 days' AS return_date,
                   staff_id,
                   NOW()
            FROM   data_cte 
            RETURNING customer_id,
                   	  staff_id,
                      rental_id,
                      return_date,
                      rental_date 
)
INSERT INTO payment
            (
              customer_id,
              staff_id,
              rental_id,
              amount,
              payment_date
            )
SELECT customer_id,
       staff_id,
       rental_id,
       (      SELECT
                     CASE
-- if actual rental duration within rental_duration in film table - a customer pays rental_rate                  
                            WHEN EXTRACT(DAY FROM (return_date - rental_date)) <= f.rental_duration 
                            	THEN f.rental_rate
-- if actual rental duration exceeds rental_duration in film table, but is less than rental_duration * 2,
-- a customer pays 1$ for each additional day (requirement from the original script of rental db)                             	
            				WHEN EXTRACT(DAY FROM (return_date - rental_date)) <= f.rental_duration * 2 
            					THEN f.rental_rate + 1 * (EXTRACT(DAY FROM (return_date - rental_date)) - f.rental_duration)
-- in other cases (no return date (NULL), actual rental duration exceeds rental_duration * 2 etc. - a customer pays replacement_cost             					
            				ELSE f.replacement_cost
                     END
              FROM   film f
              WHERE  UPPER(title) = 'THE GREEN MILE'
       ) AS amount,
       return_date
FROM   rental_insert 
RETURNING *;


