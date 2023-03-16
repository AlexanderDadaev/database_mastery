--calculate the active user retention

SELECT

EXTRACT(MONTH FROM curr_month.event_date) AS mth

,COUNT(DISTINCT curr_month.user_id) AS monthly_active_users

FROM user_actions AS curr_month

WHERE EXISTS

(

  SELECT last_month.user_id

  FROM user_actions AS last_month

  WHERE 1=1

  AND last_month.user_id = curr_month.user_id

  AND EXTRACT(MONTH FROM last_month.event_date) = EXTRACT(MONTH FROM curr_month.event_date - interval '1 month')

)

AND EXTRACT(MONTH FROM curr_month.event_date) = 7

AND EXTRACT(YEAR FROM curr_month.event_date) = 2022

GROUP BY EXTRACT(MONTH FROM curr_month.event_date)


--year-on-year growth rate for the total spend of each product for each year.

WITH

year_spend AS

(

  SELECT

  EXTRACT(YEAR FROM transaction_date) AS year,

  product_id,

  spend AS curr_year_spend

  FROM user_transactions

),

year_variance AS

(

  SELECT

    year_spend.*,

  LAG(curr_year_spend, 1) OVER (PARTITION BY product_id ORDER BY product_id, year) AS prev_year_spend

  FROM year_spend

)

SELECT

year,

product_id,

curr_year_spend,

prev_year_spend,

ROUND(100 * (curr_year_spend - prev_year_spend)/ prev_year_spend,2) AS yoy_rate

FROM year_variance


--SQL query to find the number of prime and non-prime items that can be stored in the 500,000 square feet warehouse

WITH summary AS

( 

  SELECT 

  item_type, 

  SUM(square_footage) AS total_sqft, 

  COUNT(*) AS item_count 

  FROM inventory 

  GROUP BY item_type

),

prime_items AS

( 

  SELECT 

  DISTINCT item_type,

  total_sqft,

  TRUNC(500000/total_sqft,0) AS prime_item_combo,

  (TRUNC(500000/total_sqft,0) * item_count) AS prime_item_count

  FROM summary 

  WHERE item_type = 'prime_eligible'

),

non_prime_items AS

( 

  SELECT DISTINCT

  item_type,

  total_sqft, 

  TRUNC

  (

  (500000 - (SELECT prime_item_combo * total_sqft FROM prime_items)) 

    / total_sqft, 0

  ) * item_count AS non_prime_item_count 

  FROM summary

  WHERE item_type = 'not_prime'

)

SELECT

  item_type, 

  prime_item_count AS item_count 

FROM prime_items 

UNION ALL 

SELECT 

  item_type, 

  non_prime_item_count AS item_count 

FROM non_prime_items


--a query to report the median of searches made by a user
WITH search_exp AS

(

  SELECT searches

  FROM search_frequency

  GROUP BY

  searches,

  GENERATE_SERIES(1, num_users)

)

SELECT

ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY searches)::DECIMAL, 1) AS  median

FROM search_exp
