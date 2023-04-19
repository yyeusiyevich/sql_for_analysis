-- 1. What is the customer retention rate for each cohort year and purchase year, and how does it change over time?
/* Users are grouped into cohorts based on the year of their first order (using the time_id field).
 * Retention determined based on the presence of orders in the current year. */

-- create 'user profiles': id, cohort date (based on the date of the first purchase) and number of users in this cohort
WITH profiles AS (SELECT s.cust_id,
									DATE_TRUNC('YEAR', MIN(s.time_id) :: TIMESTAMP) AS cohort_dt,
									COUNT(s.cust_id) OVER (PARTITION BY DATE_TRUNC('YEAR', MIN(s.time_id)):: TIMESTAMP) AS cohort_users_cnt
FROM sh.sales AS s
GROUP BY s.cust_id),
-- get all purchases for each customer, grouped by year
		purchases AS (SELECT DISTINCT s.cust_id,
									DATE_TRUNC('YEAR', s.time_id :: TIMESTAMP) AS purchase_date
									FROM sh.sales AS s
									GROUP BY s.cust_id, purchase_date)
-- join all info and calculate retention: divide number of customers who made a purchase by cohort size									
SELECT cohort_dt, 
	   purchase_date, 
	   COUNT(p.cust_id) AS users_cnt,
	   cohort_users_cnt,
	   ROUND(COUNT(p.cust_id) * 100.0 / cohort_users_cnt, 2) AS retention_rate
FROM profiles p
INNER JOIN purchases pur ON p.cust_id = pur.cust_id
-- grouping by dates and cohor user number
GROUP BY cohort_dt, purchase_date, cohort_users_cnt
ORDER BY cohort_dt, purchase_date;

-- 2. What are the top 10 products in terms of average revenue per paying user (ARPPU)?
/* This query calculates the number of paying users, total revenue and ARPPU for each product, 
 * and then sorts the results in descending order by ARPPU, with ties broken by the product name. 
 * Finally, it limits the output to the top 10 products. */

SELECT p.prod_name,
       COUNT(DISTINCT s.cust_id) AS paying_users, 
       SUM(s.amount_sold * s.quantity_sold) AS total_revenue,
       -- calculate the number of paying users and total revenue for each product, and divide the total revenue by the number of paying users
       SUM(s.amount_sold * s.quantity_sold) / COUNT(DISTINCT s.cust_id) AS arppu
FROM sh.sales s
INNER JOIN sh.products p ON s.prod_id = p.prod_id
GROUP BY p.prod_id, p.prod_name
ORDER BY arppu DESC, prod_name
LIMIT 10;


-- 3. What is the monthly conversion rate, and how many unique customers have made a purchase before the current month?
/* For each month from July 1996 to May 1998, the query calculates the conversion rate as a percentage.
 * It finds the number of unique customers who placed orders in the current month.
 * Then it divides this by the total number of customers who have placed at least one order during the entire previous period, 
 * including the current month.
 */ 

-- calculate the first purchase date of each customer and assign a row number to each purchase
WITH enumerate_users AS
  (SELECT DATE_TRUNC('MONTH', s.time_id) :: DATE AS first_purchase,
          cust_id,
          ROW_NUMBER() OVER (PARTITION BY s.cust_id) AS rows_num
   FROM sh.sales AS s),
   -- calculate the number of customers who made a purchase in each month
     total_customers AS
  (SELECT DATE_TRUNC('MONTH', s.time_id) :: DATE AS month,
          COUNT(DISTINCT s.cust_id) AS customers_this_month
   FROM sh.sales AS s
   GROUP BY month
   ORDER BY month)
-- select the month 
SELECT month,
-- the number of customers who made a purchase in the current month
       customers_this_month,
-- and the total number of unique customers who have made a purchase prior to the current month         
	  (SELECT COUNT(DISTINCT cust_id)
	   FROM enumerate_users
	   WHERE first_purchase <= month) AS total_customers,
-- the conversion rate is calculated by dividing the number of customers who made a purchase in the current month 
       ROUND((customers_this_month :: REAL /
       -- by the total number of unique customers who have made a purchase prior to the current month
                (SELECT COUNT(DISTINCT cust_id)
                 FROM enumerate_users
                 -- multiplied by 100 and rounded to two decimal places
                 WHERE first_purchase <= month) * 100) :: NUMERIC, 2) AS conversion
FROM total_customers;
