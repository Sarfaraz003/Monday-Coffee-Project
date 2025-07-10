-- Monday Coffee SCHEMAS
CREATE DATABASE IF NOT EXISTS coffee_db; 
USE coffee_db;

CREATE TABLE city -- Creating different tables in coffee_db
(
	city_id	INT PRIMARY KEY,
	city_name VARCHAR(15),	
	population	BIGINT,
	estimated_rent	FLOAT,
	city_rank INT
);

CREATE TABLE customers
(
	customer_id INT PRIMARY KEY,	
	customer_name VARCHAR(25),	
	city_id INT,
	CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES city(city_id)
);

CREATE TABLE products
(
	product_id	INT PRIMARY KEY,
	product_name VARCHAR(35),	
	Price float
);

CREATE TABLE sales
(
	sale_id	INT PRIMARY KEY,
	sale_date	date,
	product_id	INT,
	customer_id	INT,
	total FLOAT,
	rating INT,
	CONSTRAINT fk_products FOREIGN KEY (product_id) REFERENCES products(product_id),
	CONSTRAINT fk_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id) 
);

-- Exploring different tables
SELECT * FROM city;
SELECT * FROM customers;
SELECT * FROM products;
SELECT * FROM sales;

-- Analyzing sales data and provide insights
-- Coffee consumers count
-- Q1) How many people in each city are estimated to consume coffee,given that 25% of the population does?
SELECT 
	city_name, 
	0.25*population AS est_coffee_consum  
FROM city 
GROUP BY city_name, est_coffee_consum 
ORDER BY est_coffee_consum DESC;

-- Total revenue from coffee sales
-- Q2) What is the total revenue generated from coffee sales across all cities in last qtr of 2023?
SELECT MIN(sale_date), MAX(sale_date) FROM sales;
WITH rev AS (SELECT * FROM sales WHERE sale_date BETWEEN '2023-10-01' AND '2023-12-31')
SELECT SUM(total) AS total_revenue FROM rev; -- Total revenue

SELECT  city_name, SUM(total) AS total_revenue
FROM sales 
JOIN customers USING(customer_id)
JOIN city USING(city_id)
WHERE sale_date BETWEEN '2023-10-01' AND '2023-12-31'
GROUP BY city_name
ORDER BY total_revenue DESC; 

-- Sales count for each product 
-- Q3) How many units of each coffee product have been sold?
SELECT product_name, COUNT(product_name) AS total_orders
FROM sales
LEFT JOIN products
	USING(product_id)
GROUP BY product_name
ORDER BY total_orders DESC;

-- Average sales amount per city
-- Q4) What is the average sales amount per customer in each city?
SELECT 
	city_name, 
    SUM(total) AS total_revenue,
    COUNT(DISTINCT customer_id) AS total_cx,
    ROUND(SUM(total)/COUNT(DISTINCT customer_id),2) AS avg_sale_per_cx
FROM sales
JOIN customers USING (customer_id)
JOIN city USING (city_id)
GROUP BY city_name
ORDER BY total_revenue DESC;

-- City population and coffee consumers 
-- Q5) Provide a list of cities along with their populations and estimated coffee customers.
WITH city_table AS (SELECT city_name, ROUND(0.25 * population/1000000,2) AS coffee_consumer_in_million 
					FROM city
                    ORDER BY coffee_consumer_in_million DESC
                    ),
     consumer_table AS (SELECT city_name, COUNT(DISTINCT customer_id) AS unique_cx
						FROM sales
                        JOIN customers USING (customer_id) 
                        JOIN city USING (city_id)
                        GROUP BY city_name
                        ORDER BY unique_cx DESC
						)
SELECT  city_table.city_name, city_table.coffee_consumer_in_million , consumer_table.unique_cx
FROM city_table
LEFT JOIN consumer_table
	USING (city_name);

-- Top selling products by city
-- Q6) What are the top 3 selling products in each city based on sales volume?
USE coffee_db;
SELECT * 
FROM -- table
(
	SELECT 
		city_name,
		product_name,
		COUNT(sale_id) as total_orders,
		DENSE_RANK() OVER(PARTITION BY city_name ORDER BY COUNT(sale_id) DESC) AS product_rank
	FROM sales
	JOIN products USING (product_id)
	JOIN customers USING (customer_id)
	JOIN city USING (city_id)
	GROUP BY city_name, product_name
) AS t1
WHERE product_rank <= 3;

-- Customer segmentation by city
-- Q7) How many unique customers are there in each city who have purchased coffee products?
SELECT city_name, COUNT(DISTINCT customer_id) AS unique_cx
FROM city
LEFT JOIN customers USING (city_id)
JOIN sales USING (customer_id)
WHERE product_id IN (1,2,3,4,5,6,7,8,9,10,11,12,13,14)
GROUP BY city_name;

-- Impact of estimated rent on sales
-- Q8) Find each city and their average sale per customer and avg rent per customer.
SELECT 
	city_name, estimated_rent,
    COUNT(DISTINCT customer_id) AS total_cx,
    ROUND(SUM(total)/COUNT(DISTINCT customer_id),2) AS avg_sale_per_cx,
    ROUND(estimated_rent/COUNT(DISTINCT customer_id),2) AS avg_rent_per_cx
FROM city
LEFT JOIN customers USING (city_id)
JOIN sales USING (customer_id)
GROUP BY city_name, estimated_rent
ORDER BY avg_sale_per_cx DESC;

-- Q9)
-- Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city 
WITH monthly_sales AS
			(SELECT 
				city_name, 
				EXTRACT(YEAR FROM sale_date) AS year, 
				EXTRACT(MONTH FROM sale_date) AS month,
				SUM(total) AS total_sale
			FROM city
			JOIN customers USING (city_id)
			JOIN sales USING (customer_id)
			GROUP BY city_name, year, month
			ORDER BY city_name, year, month),
	growth_ratio AS
			(SELECT 
				city_name,
                year,
                month,
                total_sale AS cr_month_sale,
                LAG(total_sale,1) OVER(PARTITION BY city_name ORDER BY year, month) AS last_month_sale
			 FROM monthly_sales)
SELECT
	city_name,
    year,
    month,
    cr_month_sale,
    last_month_sale,
    ROUND((cr_month_sale-last_month_sale)/last_month_sale * 100,2) AS growth_ratio 
FROM growth_ratio
WHERE last_month_sale IS NOT NULL;

-- Q10)
-- Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name,
-- total sale, total rent, total customers, estimated coffee consumer
WITH market_table AS
(SELECT 
	city_name, 
    estimated_rent AS total_rent, 
    ROUND(0.25 * population / 1000000,3) AS est_coffee_consumer_in_million,
    SUM(total) AS total_sale, 
    COUNT(DISTINCT customer_id) AS total_customers
FROM city
JOIN customers USING (city_id)
JOIN sales USING (customer_id)
GROUP BY city_name, estimated_rent, est_coffee_consumer_in_million
ORDER BY total_sale DESC)
SELECT 
	city_name,
    total_rent,
    est_coffee_consumer_in_million,
    total_sale,
    total_customers,
    ROUND(total_sale/total_customers,2) AS avg_sale_pr_cx,
    ROUND(total_rent/total_customers,2) AS avg_rent_pr_cx
FROM market_table;

-- Recomendation
-- City 1: Pune
-- 	1.Average rent per customer is very low.
-- 	2.Highest total revenue (sale).
-- 	3.Average sales per customer is also high.

-- City 2: Delhi
-- 	1.Highest estimated coffee consumers at 7.75 million.
-- 	2.Second highest total number of customers, which is 68.
-- 	3.Average rent per customer is 330 (still under 500).

-- City 3: Jaipur
-- 	1.Highest number of customers, which is 69.
-- 	2.Average rent per customer is very low at 156.
-- 	3.Average sales per customer is better at 11.6k. 