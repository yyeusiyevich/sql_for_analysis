-- 1. Analyze annual sales by channels and regions. Build the query to generate the report.

-- this CTE filters regions and years and calculates total sales and percentage by channels using window function
WITH prep AS (
    SELECT 
        c.country_region, 
        t.calendar_year,
        -- add ranking
        DENSE_RANK() OVER (ORDER BY t.calendar_year) AS ranking,
        ch.channel_desc, 
        -- total sales by channel (for region and year in question)
        TO_CHAR(ROUND(SUM(s.amount_sold), 0), '9,999,999 $') AS amount_sold, 
        -- percentage by channel
        ROUND(SUM(s.amount_sold) * 100.0 / 
        	  SUM(SUM(s.amount_sold)) OVER (PARTITION BY c.country_region, t.calendar_year), 2) AS percent_by_channels
    FROM 
        sh.sales AS s
        INNER JOIN sh.times AS t ON s.time_id = t.time_id
        INNER JOIN sh.channels AS ch ON s.channel_id = ch.channel_id
        INNER JOIN sh.customers AS cust ON s.cust_id = cust.cust_id
        INNER JOIN sh.countries AS c ON cust.country_id = c.country_id
    WHERE 
        UPPER(c.country_region) IN ('AMERICAS', 'ASIA', 'EUROPE') AND 
        -- add filtering in the first CTE
        t.calendar_year IN (1998, 1999, 2000, 2001)
    GROUP BY 
        c.country_region, 
        t.calendar_year, 
        ch.channel_desc
),
-- this CTE calculates number for the same channel in the previous year and difference, formatting is applied
    prev_and_diff AS (
    SELECT 
        country_region,
        calendar_year,
        ranking,
        channel_desc,
        amount_sold,
        -- formatting
        CONCAT(percent_by_channels, ' %') AS "% BY CHANNELS",
        -- previous year value (for the same channel) + formatting
        CONCAT(FIRST_VALUE(percent_by_channels) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year
        ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), ' %') AS "% PREVIOUS PERIOD",
        -- difference and formatting
        CONCAT(percent_by_channels - FIRST_VALUE(percent_by_channels) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), ' %') AS "% DIFF"
    FROM 
        prep 
    ORDER BY 
        country_region ASC, 
        calendar_year ASC, 
        channel_desc ASC
    )
SELECT 
    country_region,
    calendar_year,
    channel_desc,
    amount_sold,
    "% BY CHANNELS",
    "% PREVIOUS PERIOD",
    "% DIFF"
FROM 
    prev_and_diff
-- filtering 1998 (I cannot filter it out in the previous CTE because in this case rows for 1998 will be excluded before calculating the previous value)
WHERE ranking > 1;

-- 2. Build the query to generate a sales report for the 49th, 50th and 51st weeks of 1999.

-- CTE that calculates sales total and cumulative sum for 49, 50 and 51 weeks
WITH weekly_sales AS (
  SELECT 
    t.calendar_week_number,
    s.time_id,
    t.day_name,
    -- week sales sum
    SUM(s.amount_sold) AS sales,
    -- cumulative sum for week
    SUM(SUM(s.amount_sold)) OVER (PARTITION BY t.calendar_week_number ORDER BY s.time_id) AS cum_sum
  FROM sh.sales AS s
  INNER JOIN sh.times AS t ON s.time_id = t.time_id
  -- time filtering
  WHERE 
    t.calendar_year = 1999 AND
    t.calendar_week_number IN (49, 50, 51)
  GROUP BY 
    t.calendar_week_number, 
    s.time_id, 
    t.day_name
)
SELECT 
  *,
  -- here we calculate the centered moving average based on the day according to the task conditon
  CASE 
    WHEN UPPER(day_name) = 'MONDAY' THEN 
      ROUND(AVG(sales) OVER (ORDER BY time_id ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING), 2)
    WHEN UPPER(day_name) = 'FRIDAY' THEN 
      ROUND(AVG(sales) OVER (ORDER BY time_id ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING), 2)
    ELSE 
      ROUND(AVG(sales) OVER (ORDER BY time_id ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING), 2)
  END AS centered_3_day_avg
FROM 
  weekly_sales;

-- 3. Prepare 3 examples of using window functions with a frame clause (RANGE, ROWS, and GROUPS modes).
 
-- Using ROWS mode: suppose we want to calculate the rolling 7-day average sales for each product in 2000. 
/* We calculate the average of a fixed number of rows (7) for each product, regardless of the time period covered by these rows that's why
 * ROWS frame is used.*/
 
 SELECT 
  time_id, 
  prod_id, 
  SUM(amount_sold) AS sales, 
  -- calculating the average sales for the current row and the 6 preceding rows for each product
  AVG(SUM(amount_sold)) OVER (
    PARTITION BY prod_id 
    ORDER BY time_id 
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7day_avg_sales
FROM 
  sh.sales
WHERE 
  EXTRACT (YEAR FROM time_id) = 2000
GROUP BY 
  time_id, 
  prod_id
ORDER BY 
  time_id, 
  prod_id;
 
 -- Using RANGE mode: suppose we want to calculate the cumulative sum of sales by months for each product category in 2000 
 -- within a 3-month window.
 
 /* The use of the RANGE frame is appropriate in this case because it calculates the cumulative sum based on a time interval, 
  * rather than a fixed number of rows. This means that the result is not affected by gaps in the data or variations in the number 
  * of rows in each group. */
 
SELECT 
  DATE_TRUNC('MONTH', s.time_id) AS month, 
  p.prod_category, 
  SUM(s.amount_sold) AS sales, 
  SUM(SUM(s.amount_sold)) OVER (
    PARTITION BY p.prod_category 
    ORDER BY DATE_TRUNC('MONTH', s.time_id) 
    RANGE BETWEEN INTERVAL '3 MONTH' PRECEDING AND CURRENT ROW
  ) AS cumulative_sum_sales 
FROM 
  sh.sales AS s
  INNER JOIN sh.products AS p ON s.prod_id = p.prod_id 
WHERE 
  EXTRACT (YEAR FROM s.time_id) = 2000
GROUP BY 
  month,
  p.prod_category
ORDER BY 
  month,
  p.prod_category;

 -- Using GROUPS mode: suppose we want to calculate the sum of order totals for customer with ID 2 and 3 across adjacent orders 
 -- (in terms of the order month), current month is not included;
 
 /* The GROUPS BETWEEN clause is used to specify the window frame for the SUM function. 
  * In this case, it specifies a window of one preceding and one following group, and the EXCLUDE GROUP clause is used to 
  * exclude the current row from the window frame. This means that the rolling sum will include the sum of the previous 
  * and next month's sales, but not the sales for the current month.*/
 
SELECT 
  c.cust_id, 
  c.cust_first_name || ' ' || c.cust_last_name AS customer_fullname,
  t.calendar_month_desc, 
  SUM(SUM(amount_sold)) OVER (
    PARTITION BY c.cust_id 
    ORDER BY t.calendar_month_desc
    GROUPS BETWEEN 1 PRECEDING AND 1 FOLLOWING EXCLUDE GROUP
  ) AS sum_orders_in_group
FROM 
  sh.sales AS s
  INNER JOIN sh.times AS t ON s.time_id = t.time_id 
  INNER JOIN sh.customers AS c ON s.cust_id = c.cust_id 
WHERE 
  s.cust_id IN (2, 3)
GROUP BY 
  c.cust_id, 
  t.calendar_month_desc
ORDER BY 
  c.cust_id, 
  t.calendar_month_desc;



 