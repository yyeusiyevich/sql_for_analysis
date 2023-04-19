/* 1. Build the query to generate a report about the most significant customers (which have maximum sales) 
 * through various sales channels.
 * The 5 largest customers are required for each channel.
 * Column sales_percentage shows percentage of customer’s sales within channel sales. */

SELECT
  channel_desc,
  cust_last_name, 
  cust_first_name,
  amount_sold,
  -- calculate percentage as customer amout\channel amount, add '%' sign
  TO_CHAR(ROUND(100 * (amount_sold/channel_total), 5), '0.99999'||' %') AS sales_percentage
  -- subquery that ranks customers
FROM (
  SELECT
    *,
    -- customer ranking (because we need all customers that have trappen in top 5, I chose DENSE_RANK)
    DENSE_RANK () OVER (PARTITION BY channel_desc ORDER BY amount_sold DESC, cust_last_name) AS row_num,
    SUM(amount_sold) OVER (PARTITION BY channel_desc) AS channel_total
  FROM (
  -- subquery that calculates sales by customer
    SELECT
      ch.channel_desc,
      cu.cust_last_name, 
      cu.cust_first_name,
      -- sum of sales that will be grouped by customer
      SUM(s.amount_sold * s.quantity_sold) AS amount_sold
    FROM
      sh.sales AS s
      INNER JOIN sh.customers AS cu ON s.cust_id = cu.cust_id
      INNER JOIN sh.channels AS ch ON s.channel_id = ch.channel_id
    GROUP BY
      ch.channel_id,
      cu.cust_id
  ) sales_by_cust
) sales_ordered
WHERE
-- remain only top 5 customers
  row_num <= 5
ORDER BY
  channel_desc,
  amount_sold DESC;
 
-- 2. Compose query to retrieve data for report with sales totals for all products in Photo category in Asia (use data for 2000 year). 
-- Calculate report total (YEAR_SUM).
 
-- 1st option (using CASE WHEN) 
SELECT 
    p.prod_name,
    -- sum by quarters
    SUM(CASE 
            WHEN DATE_PART('QUARTER', s.time_id) = 1 THEN s.amount_sold
            ELSE 0
        END) AS q1,
    SUM(CASE 
            WHEN DATE_PART('QUARTER', s.time_id) = 2 THEN s.amount_sold
            ELSE 0
        END) AS q2,
    SUM(CASE 
            WHEN DATE_PART('QUARTER', s.time_id) = 3 THEN s.amount_sold
            ELSE 0
        END) AS q3,
    SUM(CASE 
            WHEN DATE_PART('QUARTER', s.time_id) = 4 THEN s.amount_sold
            ELSE 0
        END) AS q4,
        -- total sum for year
    SUM(s.amount_sold * s.quantity_sold) AS year_sum
FROM 
    sh.sales s 
    INNER JOIN sh.products p ON s.prod_id = p.prod_id 
    INNER JOIN sh.customers cust ON s.cust_id = cust.cust_id 
    INNER JOIN sh.countries ct ON cust.country_id = ct.country_id 
-- filtering    
WHERE 
    UPPER(p.prod_category) = 'PHOTO' AND 
    UPPER(ct.country_region)  = 'ASIA' AND 
    DATE_PART('YEAR', s.time_id) = 2000
-- grouping by products    
GROUP BY 
    p.prod_id, p.prod_name 
ORDER BY 
    p.prod_name;


-- 2. 2nd option (using CROSSTAB)
SELECT *, 
	   COALESCE(q1, 0) + COALESCE(q2, 0) + COALESCE(q3, 0) + COALESCE(q4, 0) AS sales_total
FROM crosstab(
  'SELECT p.prod_name:: TEXT,
		  -- create quarter rows that will be columns		 
           ''q'' || DATE_PART(''QUARTER'', s.time_id) AS quarter,
		  -- calculate sales by product and quarter
		  SUM(s.amount_sold)
	FROM 
	    sh.sales s 
	    INNER JOIN sh.products p ON s.prod_id = p.prod_id 
	    INNER JOIN sh.customers cust ON s.cust_id = cust.cust_id 
	    INNER JOIN sh.countries ct ON cust.country_id = ct.country_id 
	-- filtering
	WHERE
		UPPER(p.prod_category) = ''PHOTO'' AND 
		UPPER(ct.country_region)  = ''ASIA'' AND 
		DATE_PART(''YEAR'', s.time_id) = 2000
	GROUP BY p.prod_id, DATE_PART(''QUARTER'', s.time_id)
	ORDER BY p.prod_name, DATE_PART(''QUARTER'', s.time_id)'
) AS ct (
  prod_name TEXT, 
  q1 NUMERIC, 
  q2 NUMERIC, 
  q3 NUMERIC, 
  q4 NUMERIC
);



/* 3. Build the query to generate a report about customers who were included into TOP 300 (based on the amount of sales) 
 * in 1998, 1999 and 2001. This report should separate clients by sales channels, and, at the same time, 
 * channels should be calculated independently (i.e. only purchases made on selected channel are relevant).*/

SELECT 
  channel_desc, 
  cust_id, 
  cust_last_name, 
  cust_first_name, 
  SUM(amount_sold) AS amount_sold
FROM (
  -- ranking subquery
  SELECT 
    ch.channel_desc, 
    c.cust_id, 
    c.cust_last_name, 
    c.cust_first_name, 
    EXTRACT(YEAR FROM s.time_id) AS calendar_year,
    SUM(s.amount_sold) AS amount_sold,
    -- customer ranking: we need exactly top 300, so I use ROW_NUMBER
    ROW_NUMBER () OVER (PARTITION BY EXTRACT(YEAR FROM s.time_id), ch.channel_id ORDER BY SUM(s.amount_sold) DESC) AS ranking
  FROM 
    sh.sales s 
    INNER JOIN sh.customers c ON s.cust_id = c.cust_id
    INNER JOIN sh.channels ch ON s.channel_id = ch.channel_id 
  -- time filtering  
  WHERE 
    EXTRACT(YEAR FROM s.time_id) IN (1998, 1999, 2001)
  GROUP BY 
    ch.channel_id, 
    c.cust_id, 
    calendar_year
) t
-- ranking filtering
WHERE 
  t.ranking <= 300
GROUP BY
  channel_desc,
  cust_id,
  cust_last_name,
  cust_first_name
-- remain customers that were in top 300 in each year (98, 99, 01)  
HAVING COUNT(DISTINCT calendar_year) = 3
ORDER BY  
  amount_sold DESC; 

-- 4. Build the query to generate the report about sales in America and Europe.

-- 1st option with CASE WHEN
SELECT 
  t.calendar_month_desc, 
  p.prod_category, 
  -- sum sales by regions
  ROUND(SUM(CASE WHEN UPPER(co.country_region) = 'AMERICAS' THEN s.amount_sold END), 0) AS "Americas SALES", 
  ROUND(SUM(CASE WHEN UPPER(co.country_region) = 'EUROPE' THEN s.amount_sold END), 0) AS "Europe SALES"
FROM 
  sh.sales s 
  INNER JOIN sh.products p ON s.prod_id = p.prod_id
  INNER JOIN sh.times t ON s.time_id = t.time_id
  INNER JOIN sh.customers c ON s.cust_id = c.cust_id
  INNER JOIN sh.countries co ON c.country_id = co.country_id
  -- time filtering
WHERE 
  t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03')  
GROUP BY 
  t.calendar_month_desc, 
  p.prod_category
ORDER BY 
  t.calendar_month_desc, 
  p.prod_category;
 
 -- 2nd option with FILTER
SELECT 
  t.calendar_month_desc, 
  p.prod_category, 
  ROUND(SUM(s.amount_sold) FILTER (WHERE UPPER(co.country_region) = 'AMERICAS'), 0) AS "Americas SALES", 
  ROUND(SUM(s.amount_sold) FILTER (WHERE UPPER(co.country_region) = 'EUROPE'), 0) AS "Europe SALES"
FROM 
  sh.sales s 
  INNER JOIN sh.products p ON s.prod_id = p.prod_id
  INNER JOIN sh.times t ON s.time_id = t.time_id
  INNER JOIN sh.customers c ON s.cust_id = c.cust_id
  INNER JOIN sh.countries co ON c.country_id = co.country_id
WHERE 
  t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03')  
GROUP BY 
  t.calendar_month_desc, 
  p.prod_category
ORDER BY 
  t.calendar_month_desc, 
  p.prod_category;

