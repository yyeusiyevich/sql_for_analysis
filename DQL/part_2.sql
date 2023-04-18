-- Top-3 most selling movie categories of all time and total dvd rental income for each category. 
-- Only consider dvd rental customers from the USA.
-- this CTE extracts all customer_id from customers table that are from United States
WITH usa_customers AS (
  SELECT 
    customer_id 
  FROM 
    customer 
-- join necessary tables to get country information    
    INNER JOIN address ON customer.address_id = address.address_id 
    INNER JOIN city ON address.city_id = city.city_id 
    INNER JOIN country ON city.country_id = country.country_id 
-- USA clients filtering    
  WHERE 
    UPPER(country.country) = 'UNITED STATES'
)
-- main query
SELECT 
  category.name, 
  SUM(payment.amount) AS total_income 
-- join necessary tables to connect film categories with payments
FROM 
  rental 
  INNER JOIN inventory ON rental.inventory_id = inventory.inventory_id 
  INNER JOIN film ON inventory.film_id = film.film_id 
  INNER JOIN film_category ON film.film_id = film_category.film_id 
  INNER JOIN category ON film_category.category_id = category.category_id 
  INNER JOIN payment ON rental.rental_id = payment.rental_id
-- join cte on customers id (only USA payments will be included)  
  INNER JOIN usa_customers ON payment.customer_id = usa_customers.customer_id
-- grouping to get the total amount by category   
GROUP BY
  category.category_id
-- sorting by income to get top 3
-- additional sorting by category name to get the same results if several categories would have the same income  
ORDER BY 
  total_income DESC, 
  category.name 
LIMIT 
  3;

-- For each client, display a list of horrors that he had ever rented (in one column, separated by commas), 
-- and the amount of money that he paid for it;
-- CTE to extract all film_id from films that are of horror category
 WITH horror_films AS (
  SELECT 
    film_id 
  FROM 
    film_category
-- join category table for filtering    
    INNER JOIN category ON film_category.category_id = category.category_id 
  WHERE 
    UPPER(category.name) = 'HORROR'
)
-- main part
SELECT 
  customer.first_name || ' ' || customer.last_name AS customer_name,
-- remain only distinct titles, aggregate them as string, separated by commas  
  array_to_string(
    array_agg(DISTINCT film.title), 
    ', '
  ) AS horror_films,
-- total payments amount calculating  
  SUM(payment.amount) AS total_paid 
FROM 
  customer
-- join necessary tables to connect customers with their payments
  INNER JOIN rental ON customer.customer_id = rental.customer_id 
  INNER JOIN inventory ON rental.inventory_id = inventory.inventory_id
-- remain only horror films from cte above  
  INNER JOIN horror_films ON horror_films.film_id = inventory.film_id 
  INNER JOIN film ON inventory.film_id = film.film_id 
  INNER JOIN payment ON rental.rental_id = payment.rental_id 
-- grouping by unique field - customer id
GROUP BY 
  customer.customer_id,
  customer_name
-- sorting by customers, alphabetical  
ORDER BY 
  customer_name;

