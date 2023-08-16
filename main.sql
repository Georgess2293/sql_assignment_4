-- 1-Calculate the average rental duration and total revenue for each customer, along with their top 3 most rented film categories.

WITH CTE_rental_duration_revenue AS
(
SELECT se_customer.customer_id,
	   AVG(AGE(se_rental.return_date,se_rental.rental_date)) AS avg_rental_duration,
	   COALESCE(SUM(se_payment.amount),0) AS total_revenue
FROM public.customer AS se_customer
INNER JOIN public.rental AS se_rental
ON se_customer.customer_id=se_rental.customer_id
INNER JOIN public.payment AS se_payment
ON se_rental.rental_id=se_payment.rental_id
GROUP BY se_customer.customer_id
),

CTE_Customer_Category AS
(
SELECT se_customer.customer_id,
	   se_category.name,
	   COUNT(se_film.film_id) AS Category_count
FROM public.customer AS se_customer
INNER JOIN public.rental AS se_rental
ON se_customer.customer_id=se_rental.customer_id
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
INNER JOIN public.film AS se_film
ON se_inventory.film_id=se_film.film_id
INNER JOIN public.film_category AS se_film_category
ON se_film.film_id=se_film_category.film_id
INNER JOIN public.category AS se_category
ON se_film_category.category_id=se_category.category_id
GROUP BY se_customer.customer_id,
		 se_category.name
ORDER BY se_customer.customer_id, COUNT(se_film.film_id) DESC 
),

CTE_TOP3_Category AS
(
SELECT *
FROM (
    SELECT CTE_Customer_Category.customer_id,
	       CTE_Customer_Category.name, 
	ROW_NUMBER() 
	OVER 
	(PARTITION BY CTE_Customer_Category.customer_id 
	 ORDER BY CTE_Customer_Category.Category_count  DESC) AS Rank
    FROM CTE_Customer_Category
) AS x
WHERE Rank <= 3
)

SELECT CTE_TOP3_Category.customer_id,
	   CTE_TOP3_Category.name, 
	   CTE_rental_duration_revenue.avg_rental_duration,
	   CTE_rental_duration_revenue.total_revenue
FROM CTE_TOP3_Category
INNER JOIN CTE_rental_duration_revenue
ON CTE_TOP3_Category.customer_id=CTE_rental_duration_revenue.customer_id


--2- Identify customers who have never rented films but have made payments.

SELECT
	payment.customer_id
FROM public.payment
WHERE rental_id=NULL

--3- Find the correlation between customer rental frequency and the average rating of the rented films.

SELECT se_customer.customer_id,
	   se_film.rating,
	   COUNT(se_film.film_id) AS Rating_count
FROM public.customer AS se_customer
INNER JOIN public.rental AS se_rental
ON se_customer.customer_id=se_rental.customer_id
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
INNER JOIN public.film AS se_film
ON se_inventory.film_id=se_film.film_id
GROUP BY se_customer.customer_id,
		 se_film.rating
ORDER BY se_customer.customer_id, COUNT(se_film.film_id) DESC

-- 
--4 Determine the average number of films rented per customer, broken down by city

WITH CTE_Total_Rentals AS
(
SELECT
	se_customer.customer_id,
	se_city.city,
	COUNT(se_rental.rental_id) AS Total_Rentals
FROM public.customer AS se_customer
INNER JOIN public.rental AS se_rental
ON se_customer.customer_id=se_rental.customer_id
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
INNER JOIN public.store AS se_store
ON se_inventory.store_id=se_store.store_id
INNER JOIN public.address  AS se_address
ON se_store.address_id=se_address.address_id
INNER JOIN public.city AS se_city
ON se_address.city_id=se_city.city_id

GROUP BY se_city.city,
		se_customer.customer_id
)

SELECT CTE_Total_Rentals.city,
	   ROUND(AVG(Total_Rentals),2)
FROM CTE_Total_Rentals
GROUP BY CTE_Total_Rentals.city

--5 Identify films that have been rented more than the average number of times and are currently not in inventory.

WITH CTE_Total_rentals AS
(
SELECT
se_film.film_id,
se_film.title,
COUNT(se_rental.rental_id) AS Total_rentals
FROM public.rental AS se_rental
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
INNER JOIN public.film AS se_film
ON se_inventory.film_id=se_film.film_id
GROUP BY se_film.title,
		 se_film.film_id
),

CTE_Average_rentals AS
(
SELECT
AVG(CTE_Total_rentals.Total_rentals) AS average_rentals
FROM CTE_Total_rentals
),

CTE_Higher_rentals AS
(
SELECT 
	CTE_Total_rentals.film_id,
	CTE_Total_rentals.title
FROM CTE_Total_rentals,CTE_Average_rentals
WHERE  CTE_Total_rentals.Total_rentals>CTE_Average_rentals.average_rentals
)

SELECT CTE_Higher_rentals.title,
	   se_inventory.inventory_id
FROM CTE_Higher_rentals
LEFT JOIN public.inventory AS se_inventory
ON CTE_Higher_rentals.film_id=se_inventory.film_id
WHERE se_inventory.inventory_id=NULL


--6 Calculate the replacement cost of lost films for each store, considering the rental history.

WITH CTE_Replacement AS
(
SELECT
DISTINCT(se_inventory.inventory_id),
se_film.replacement_cost AS Total_cost,
se_store.store_id
FROM public.rental AS se_rental
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
INNER JOIN public.film AS se_film
ON se_inventory.film_id=se_film.film_id
INNER JOIN public.store AS se_store
ON se_inventory.store_id=se_store.store_id
)

SELECT 
CTE_Replacement.store_id,
SUM(CTE_Replacement.Total_cost)
FROM CTE_Replacement
GROUP BY CTE_Replacement.store_id
ORDER BY CTE_Replacement.store_id

--7 Create a report that shows the top 5 most rented films in each category, along with their corresponding rental counts and revenue.

WITH CTE_Total_rentals_category AS
(
SELECT
se_category.name,
se_film.title,
COUNT(se_rental.rental_ID) AS Total_rentals,
se_film.rental_rate* (COUNT(se_rental.rental_ID)) AS Revenue
FROM public.rental AS se_rental
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
INNER JOIN public.film AS se_film
ON se_inventory.film_id=se_film.film_id
INNER JOIN public.film_category AS se_film_category
ON se_film.film_id=se_film_category.film_id
INNER JOIN public.category AS se_category
ON se_film_category.category_id=se_category.category_id
GROUP BY se_category.name,
		 se_film.title,
		 se_film.rental_rate
ORDER BY se_category.name, COUNT(se_rental.rental_ID) DESC
)


SELECT *
FROM (
    SELECT CTE_Total_rentals_category.name,
	       CTE_Total_rentals_category.title, 
		   CTE_Total_rentals_category.Total_rentals,
	       CTE_Total_rentals_category.Revenue,
	ROW_NUMBER() 
	OVER 
	(PARTITION BY CTE_Total_rentals_category.name
	 ORDER BY CTE_Total_rentals_category.Total_rentals  DESC) AS RANK
     FROM CTE_Total_rentals_category
) AS x
WHERE RANK <= 5

-- 8 Develop a query that automatically updates the top 10 most frequently rented films, considering a rolling 3-month window.

SELECT
se_film.title,
COUNT(se_rental.rental_ID) AS Total_rentals
FROM public.rental AS se_rental
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
INNER JOIN public.film AS se_film
ON se_inventory.film_id=se_film.film_id
WHERE EXTRACT(MONTH FROM se_rental.last_update)-EXTRACT(MONTH FROM se_rental.rental_date)<3
GROUP BY se_film.title
ORDER BY COUNT(se_rental.rental_ID) DESC
LIMIT 10


-- 9- Identify stores where the revenue from film rentals exceeds the revenue from payments for all customers.

WITH CTE_Revenue_film AS
(
SELECT 
	se_film.film_id,
	se_film.title,
	se_store.store_id,
	COUNT(se_rental.rental_id) AS Total_rentals,
	se_film.rental_rate,
	se_film.rental_rate*COUNT(se_rental.rental_id) AS Revenue_per_film
FROM public.rental AS se_rental
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
INNER JOIN public.film AS se_film
ON se_inventory.film_id=se_film.film_id
INNER JOIN public.store AS se_store
ON se_inventory.store_id=se_store.store_id
GROUP BY se_film.title,
		 se_film.film_id,
		 se_store.store_id,
		 se_film.rental_rate
),

CTE_Total_Revenue_film AS(
SELECT
CTE_Revenue_film.store_id,
SUM(CTE_Revenue_film.revenue_per_film) AS Total_revenue
FROM CTE_Revenue_film
GROUP BY CTE_Revenue_film.store_id
),

CTE_Revenue_Payment AS
(
SELECT se_payment.payment_id,
	   se_payment.amount,
	   se_inventory.store_id
FROM public.payment AS se_payment
INNER JOIN public.rental AS se_rental
ON se_payment.rental_id=se_rental.rental_id
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
),

CTE_Total_Revenue_Payment AS(
SELECT
CTE_Revenue_Payment.store_id,
SUM(CTE_Revenue_Payment.amount) AS Total_amount
FROM CTE_Revenue_Payment
GROUP BY CTE_Revenue_Payment.store_id
)

SELECT
CTE_Total_Revenue_film.store_id,
CTE_Total_Revenue_film.Total_revenue,
CTE_Total_Revenue_Payment.Total_amount
FROM CTE_Total_Revenue_film
INNER JOIN CTE_Total_Revenue_Payment
ON CTE_Total_Revenue_film.store_id=CTE_Total_Revenue_Payment.store_id
WHERE CTE_Total_Revenue_film.Total_revenue>CTE_Total_Revenue_Payment.Total_amount
ORDER BY CTE_Total_Revenue_film.store_id

-- 10- Determine the average rental duration and total revenue for each store, considering different payment methods.

WITH CTE_Total_Rentals AS 
(
SELECT se_rental.rental_id,
	   AGE(se_rental.return_date,se_rental.rental_date) AS rental_duration,
	   se_payment.amount
FROM public.rental AS se_rental
INNER JOIN public.payment AS se_payment
ON se_rental.rental_id=se_payment.rental_id
)

SELECT
se_inventory.store_id,
AVG(CTE_Total_Rentals.rental_duration) AS AVG_Duration,
SUM(CTE_Total_Rentals.amount) AS Revenue
FROM CTE_Total_Rentals
INNER JOIN public.rental AS se_rental
ON CTE_Total_Rentals.rental_id=se_rental.rental_id
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
GROUP BY se_inventory.store_id


-- 11 Analyze the seasonal variation in rental activity and payments for each store.

SELECT
	EXTRACT(MONTH FROM se_rental.rental_date) as month,
	se_inventory.store_id,
	COUNT(se_rental.rental_id) AS total_rentals,
	COALESCE(SUM(se_payment.amount),0) AS Total_amount
FROM public.rental AS se_rental
LEFT JOIN public.payment AS se_payment
ON se_rental.rental_id=se_payment.rental_id
INNER JOIN public.inventory AS se_inventory
ON se_rental.inventory_id=se_inventory.inventory_id
GROUP BY EXTRACT(MONTH FROM se_rental.rental_date),
				se_inventory.store_id

--- For both stores the season with the most rental activity was during July and August along with the revenues.
--  The lowest activity is during february
--  From february till August the rental activity seems to go up progressively
-- However there were rentals in May where was no amount paid for the rented movies