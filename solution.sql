/*
 * Revenue generated by the top 10 countries
 */

SELECT 
    c.country,
    COUNT(i.invoice_id) AS num_invoice,
    SUM(i.total) AS revenue,
    ROUND(AVG(i.total), 2) AS avg_value
FROM customer c
JOIN invoice i
ON c.customer_id = i.customer_id
GROUP BY c.country
ORDER BY revenue DESC
LIMIT 10;

/*
 * Top 10 artists in the USA based on the number of tracks sold and the revenue they generated
 */

SELECT
	ar.name,
	SUM(il.quantity) AS num_tracks,
    SUM(il.unit_price * il.quantity) AS revenue
FROM artist ar
JOIN album al
ON ar.artist_id = al.artist_id
JOIN track t
ON al.album_id = t.album_id
JOIN invoice_line il
ON t.track_id = il.track_id
JOIN invoice i
ON il.invoice_id = i.invoice_id
WHERE i.billing_country = 'USA'
GROUP BY ar.artist_id
ORDER BY num_tracks DESC
LIMIT 10;

/*
 * Most popular music genre in each country by analyzing the number of tracks sold
 */

WITH unranked AS (
    SELECT
		i.billing_country AS country,
		g.name AS genre,
        SUM(il.quantity) AS num_tracks
	FROM genre g
	JOIN track t ON g.genre_id = t.genre_id
	JOIN invoice_line il ON t.track_id = il.track_id
	JOIN invoice i ON il.invoice_id = i.invoice_id
	GROUP BY i.billing_country, g.name
),
ranked AS (
    SELECT
		*,
        ROW_NUMBER() OVER(PARTITION BY country ORDER BY num_tracks DESC) AS rn
	FROM unranked
)

SELECT
	country,
    genre
FROM ranked
WHERE rn = 1
ORDER BY num_tracks DESC;

/*
 * List of tracks, along with their album titles and artist names, 
 * that have not been purchased in the last 6 months
 */

SELECT DISTINCT
    t.name,
    al.title,
    ar.name
FROM track t
JOIN invoice_line il ON t.track_id = il.track_id
JOIN invoice i ON il.invoice_id = i.invoice_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
WHERE i.invoice_date < (SELECT MAX(invoice_date) FROM invoice) - INTERVAL '6' MONTH;

/*
 * List of the top 10 customers by revenue, including their customer ID, name, country,
 * number of invoices, and total revenue. 
 * This will help identify the most valuable customers based on their total spending.
 */

SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.country,
    COUNT(i.invoice_id) AS num_invoice,
    SUM(i.total) AS revenue 
FROM customer c
JOIN invoice i
ON c.customer_id = i.customer_id
GROUP BY c.customer_id
ORDER BY revenue DESC
LIMIT 10;

/*
 * Turnover rate by genre (average revenue generated per track)
 */

WITH Sales AS (
  SELECT g.genre_id, SUM(il.unit_price * il.quantity) AS total_sales
	FROM invoice_line il
	JOIN track t ON il.track_id = t.track_id
	JOIN genre g ON t.genre_id = g.genre_id
	GROUP BY g.genre_id
),
Inventory AS (
	SELECT g.genre_id, COUNT(t.track_id) AS num_tracks
	FROM track t
	JOIN genre g ON t.genre_id = g.genre_id
	GROUP BY g.genre_id
)

SELECT 
    g.name AS genre,
    s.total_sales,
    i.num_tracks,
    ROUND(s.total_sales/ i.num_tracks, 3) AS turnoverrate
FROM Sales s
JOIN Inventory i ON s.genre_id = i.genre_id
JOIN genre g ON s.genre_id = g.genre_id
ORDER BY turnoverrate DESC;

/*
 * Monthly Sales Trends with Rolling Average
 */

WITH MonthlySales AS (
    SELECT
        EXTRACT(YEAR FROM i.invoice_date) AS year,
        EXTRACT(MONTH FROM i.invoice_date) AS month,
        SUM(il.unit_price * il.quantity) AS total_sales
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY year, month
),
SalesWithRollingAverage AS (
    SELECT
        year,
        month,
        total_sales,
        AVG(total_sales) OVER (ORDER BY year, month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS rolling_avg
    FROM MonthlySales
)

SELECT
    year,
    month,
    total_sales,
    rolling_avg
FROM SalesWithRollingAverage
ORDER BY year, month;

/*
 * Customers who have not made any purchases in the last year
 */

SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name), 
    MAX(invoice_date) AS last_transaction
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
WHERE i.invoice_date < (SELECT MAX(invoice_date) FROM invoice) - INTERVAL '1' YEAR
GROUP BY c.customer_id;