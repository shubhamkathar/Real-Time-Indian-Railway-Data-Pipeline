SELECT
    *,
    
    ROUND(distance_km / duration_hours, 2) AS speed_kmh,

    CASE
        WHEN (distance_km / duration_hours) < 40 THEN 'Slow'
        WHEN (distance_km / duration_hours) BETWEEN 40 AND 80 THEN 'Medium'
        ELSE 'Fast'
    END AS speed_category,

    hour(date_parse(departure_time, '%H:%i')) AS departure_hour,

    CASE
        WHEN on_time_percentage >= 85 THEN 'Good'
        WHEN on_time_percentage BETWEEN 60 AND 84.99 THEN 'Average'
        ELSE 'Poor'
    END AS performance_flag,

    (ticket_price_2ac - ticket_price_sleeper) AS price_difference_2ac_sl,

    CASE
        WHEN distance_km < 500 THEN 'Short'
        WHEN distance_km BETWEEN 500 AND 1500 THEN 'Medium'
        ELSE 'Long'
    END AS journey_category

FROM indian_railways_cleaned;



-- Zone Performance
SELECT
   zone,
   COUNT(train_number) AS total_trains,
   ROUND(AVG(avg_delay_minutes), 2) AS avg_delay,
   ROUND(AVG(on_time_percentage), 2) AS avg_on_time_pct
FROM indian_railways_cleaned
WHERE zone IS NOT NULL
 AND zone <> 'Unknown'
GROUP BY zone
ORDER BY avg_delay DESC;

-- Busiest Source Stations
SELECT
   source_station,
   COUNT(train_number) AS total_trains_originated
FROM indian_railways_cleaned
WHERE source_station IS NOT NULL
GROUP BY source_station
ORDER BY total_trains_originated DESC
LIMIT 10;

-- Train Type Distribution
Athena-compatible version:
SELECT
   train_type,
   COUNT(train_number) AS total_trains,
   ROUND(
       COUNT(train_number) * 100.0 / SUM(COUNT(train_number)) OVER (),
       2
   ) AS percentage
FROM indian_railways_cleaned
WHERE train_type IS NOT NULL
 AND train_type <> 'Unknown'
GROUP BY train_type
ORDER BY total_trains DESC;

-- State Performance
SELECT
   state,
   ROUND(AVG(on_time_percentage), 2) AS avg_on_time_pct,
   COUNT(train_number) AS total_trains
FROM indian_railways_cleaned
WHERE state IS NOT NULL
 AND state <> 'Unknown'
GROUP BY state
ORDER BY avg_on_time_pct DESC;

-- Cancellation Trend
SELECT
   year,
   month,
   COUNT(train_number) AS total_trains,
   SUM(cancellation_flag) AS total_cancellations,
   ROUND(
       SUM(cancellation_flag) * 100.0 / COUNT(train_number),
       2
   ) AS cancellation_rate_pct
FROM indian_railways_cleaned
GROUP BY year, month
ORDER BY year ASC, month ASC;

-- Speed Zone Distribution
If you created gold base as Athena view:
SELECT
   zone,
   speed_category,
   COUNT(train_number) AS total_trains
FROM railway_gold_base
WHERE zone IS NOT NULL
 AND speed_category IS NOT NULL
GROUP BY zone, speed_category
ORDER BY zone ASC, speed_category ASC;

If not:
you must use subquery.

-- Expensive Routes
SELECT
   source_station,
   destination_station,
   ROUND(AVG(ticket_price_2ac), 2) AS avg_2ac_price,
   ROUND(AVG(distance_km), 2) AS avg_distance_km,
   COUNT(train_number) AS total_trains
FROM indian_railways_cleaned
WHERE ticket_price_2ac IS NOT NULL
 AND ticket_price_2ac > 0
GROUP BY source_station, destination_station
ORDER BY avg_2ac_price DESC
LIMIT 5;

-- Electrification Delay
SELECT
   electrified_route,
   ROUND(AVG(avg_delay_minutes), 2) AS avg_delay,
   ROUND(AVG(on_time_percentage), 2) AS avg_on_time_pct,
   COUNT(train_number) AS total_trains
FROM indian_railways_cleaned
WHERE electrified_route IN ('Yes', 'No')
GROUP BY electrified_route
ORDER BY avg_delay ASC;

-- Departure Delay Analysis
If gold base exists:
SELECT
   departure_hour,
   ROUND(AVG(avg_delay_minutes), 2) AS avg_delay,
   COUNT(train_number) AS total_trains,

   CASE
       WHEN departure_hour BETWEEN 5 AND 11 THEN 'Morning'
       WHEN departure_hour BETWEEN 12 AND 16 THEN 'Afternoon'
       WHEN departure_hour BETWEEN 17 AND 20 THEN 'Evening'
       ELSE 'Night'
   END AS time_slot

FROM railway_gold_base
WHERE departure_hour IS NOT NULL
GROUP BY departure_hour
ORDER BY departure_hour ASC;

-- Journey Pricing Analysis
If gold base exists:
SELECT
   journey_category,
   ROUND(AVG(ticket_price_sleeper), 2) AS avg_sleeper_price,
   ROUND(AVG(ticket_price_3ac), 2) AS avg_3ac_price,
   ROUND(AVG(ticket_price_2ac), 2) AS avg_2ac_price,
   ROUND(AVG(distance_km), 2) AS avg_distance_km,
   COUNT(train_number) AS total_trains
FROM railway_gold_base
WHERE journey_category IS NOT NULL
GROUP BY journey_category
ORDER BY avg_distance_km ASC;


