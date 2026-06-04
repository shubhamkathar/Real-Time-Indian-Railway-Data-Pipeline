Table 1 — Zone speed ranking
sql
CREATE TABLE railwaydb2.zone_speed_ranking
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
)
AS
SELECT
    zone,
    COUNT(DISTINCT train_number)                                              AS total_trains,
    ROUND(AVG(
        TRY_CAST(distance AS DOUBLE) / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)
    ), 2)                                                                     AS avg_speed_kmh,
    ROUND(MAX(
        TRY_CAST(distance AS DOUBLE) / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)
    ), 2)                                                                     AS fastest_speed_kmh,
    SUM(CASE WHEN
        TRY_CAST(distance AS DOUBLE) / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0) > 80
        THEN 1 ELSE 0 END)                                                    AS fast_trains,
    SUM(CASE WHEN
        TRY_CAST(distance AS DOUBLE) / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)
        BETWEEN 40 AND 80
        THEN 1 ELSE 0 END)                                                    AS medium_trains,
    SUM(CASE WHEN
        TRY_CAST(distance AS DOUBLE) / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0) < 40
        THEN 1 ELSE 0 END)                                                    AS slow_trains
FROM railwaydb2.railway_final
WHERE zone IS NOT NULL
  AND zone != ''
  AND TRY_CAST(duration_h AS DOUBLE) IS NOT NULL
  AND TRY_CAST(distance AS DOUBLE) IS NOT NULL
GROUP BY zone
ORDER BY avg_speed_kmh DESC;

Table 2 — Station halt analysis
sql
CREATE TABLE railwaydb2.station_halt_analysis
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
)
AS
SELECT
    station_code,
    station_name,
    state,
    TRY_CAST(latitude  AS DOUBLE)                                             AS latitude,
    TRY_CAST(longitude AS DOUBLE)                                             AS longitude,
    COUNT(DISTINCT train_number)                                              AS trains_stopping,
    ROUND(AVG(
        CASE
            WHEN arrival != departure
            THEN CAST(
                (HOUR(TRY_CAST(departure AS TIME)) * 3600
               + MINUTE(TRY_CAST(departure AS TIME)) * 60
               + SECOND(TRY_CAST(departure AS TIME)))
              - (HOUR(TRY_CAST(arrival AS TIME)) * 3600
               + MINUTE(TRY_CAST(arrival AS TIME)) * 60
               + SECOND(TRY_CAST(arrival AS TIME)))
            AS DOUBLE) / 60.0
            ELSE 0
        END
    ), 2)                                                                     AS avg_halt_minutes,
    SUM(CASE
        WHEN arrival != departure
         AND (
            (HOUR(TRY_CAST(departure AS TIME)) * 3600
           + MINUTE(TRY_CAST(departure AS TIME)) * 60
           + SECOND(TRY_CAST(departure AS TIME)))
          - (HOUR(TRY_CAST(arrival AS TIME)) * 3600
           + MINUTE(TRY_CAST(arrival AS TIME)) * 60
           + SECOND(TRY_CAST(arrival AS TIME)))
         ) / 60.0 >= 10
        THEN 1 ELSE 0
    END)                                                                      AS long_halt_trains
FROM railwaydb2.railway_final
WHERE arrival IS NOT NULL
  AND departure IS NOT NULL
  AND arrival != departure
GROUP BY station_code, station_name, state, latitude, longitude
ORDER BY avg_halt_minutes DESC;

Table 3 — Per-train class and comfort profile
sql
CREATE TABLE railwaydb2.train_class_profile
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
)
AS
SELECT
    train_number,
    train_name,
    from_station_code,
    to_station_code,
    type,
    zone,
    MAX(TRY_CAST(distance   AS DOUBLE))                                       AS route_km,
    MAX(TRY_CAST(duration_h AS DOUBLE))                                       AS duration_hrs,
    ROUND(
        MAX(TRY_CAST(distance AS DOUBLE))
        / NULLIF(MAX(TRY_CAST(duration_h AS DOUBLE)), 0)
    , 2)                                                                      AS speed_kmh,
    MAX(TRY_CAST(first_ac   AS INT))                                          AS has_1ac,
    MAX(TRY_CAST(second_ac  AS INT))                                          AS has_2ac,
    MAX(TRY_CAST(third_ac   AS INT))                                          AS has_3ac,
    MAX(TRY_CAST(sleeper    AS INT))                                          AS has_sleeper,
    MAX(TRY_CAST(chair_car  AS INT))                                          AS has_chair_car,
    MAX(
        TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
      + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
      + TRY_CAST(chair_car AS INT)
    )                                                                         AS total_classes,
    CASE
        WHEN MAX(
            TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
          + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
          + TRY_CAST(chair_car AS INT)
        ) >= 4                                                                THEN 'Fully Equipped'
        WHEN MAX(
            TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
          + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
          + TRY_CAST(chair_car AS INT)
        ) = 3                                                                 THEN 'Well Equipped'
        WHEN MAX(
            TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
          + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
          + TRY_CAST(chair_car AS INT)
        ) = 2                                                                 THEN 'Basic'
        ELSE                                                                       'Minimal'
    END                                                                       AS comfort_tier
FROM railwaydb2.railway_final
WHERE train_number IS NOT NULL
GROUP BY train_number, train_name, from_station_code, to_station_code, type, zone
ORDER BY total_classes DESC;

Table 4 — Departure time analysis
sql
CREATE TABLE railwaydb2.departure_time_analysis
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
)
AS
SELECT
    HOUR(TRY_CAST(departure AS TIME))                                         AS departure_hour,
    CASE
        WHEN HOUR(TRY_CAST(departure AS TIME)) BETWEEN 5  AND 11              THEN 'Morning'
        WHEN HOUR(TRY_CAST(departure AS TIME)) BETWEEN 12 AND 16              THEN 'Afternoon'
        WHEN HOUR(TRY_CAST(departure AS TIME)) BETWEEN 17 AND 20              THEN 'Evening'
        ELSE                                                                       'Night'
    END                                                                       AS time_slot,
    COUNT(DISTINCT train_number)                                              AS trains_departing,
    ROUND(AVG(TRY_CAST(distance   AS DOUBLE)), 0)                             AS avg_route_km,
    ROUND(AVG(TRY_CAST(duration_h AS DOUBLE)), 1)                             AS avg_duration_hrs,
    ROUND(AVG(
        TRY_CAST(distance AS DOUBLE) / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)
    ), 2)                                                                     AS avg_speed_kmh,
    SUM(CASE
        WHEN TRY_CAST(third_ac  AS INT) = 1
          OR TRY_CAST(second_ac AS INT) = 1
          OR TRY_CAST(first_ac  AS INT) = 1
        THEN 1 ELSE 0
    END)                                                                      AS ac_trains_count
FROM railwaydb2.railway_final
WHERE station_code = from_station_code
  AND departure IS NOT NULL
  AND TRY_CAST(departure AS TIME) IS NOT NULL
GROUP BY
    HOUR(TRY_CAST(departure AS TIME)),
    CASE
        WHEN HOUR(TRY_CAST(departure AS TIME)) BETWEEN 5  AND 11              THEN 'Morning'
        WHEN HOUR(TRY_CAST(departure AS TIME)) BETWEEN 12 AND 16              THEN 'Afternoon'
        WHEN HOUR(TRY_CAST(departure AS TIME)) BETWEEN 17 AND 20              THEN 'Evening'
        ELSE                                                                       'Night'
    END
ORDER BY departure_hour ASC;

Table 5 — State connectivity
sql
CREATE TABLE railwaydb2.state_connectivity
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
)
AS
SELECT
    state,
    COUNT(DISTINCT station_code)                                              AS stations_in_state,
    COUNT(DISTINCT train_number)                                              AS trains_serving,
    COUNT(DISTINCT from_station_code)                                         AS origin_points,
    COUNT(DISTINCT to_station_code)                                           AS destination_points,
    ROUND(AVG(TRY_CAST(distance AS DOUBLE)), 0)                               AS avg_route_km,
    SUM(CASE
        WHEN TRY_CAST(first_ac  AS INT) = 1
          OR TRY_CAST(second_ac AS INT) = 1
        THEN 1 ELSE 0
    END)                                                                      AS premium_ac_count,
    SUM(CASE
        WHEN TRY_CAST(third_ac AS INT) = 1
        THEN 1 ELSE 0
    END)                                                                      AS third_ac_count
FROM railwaydb2.railway_final
WHERE state IS NOT NULL
  AND state != ''
GROUP BY state
ORDER BY trains_serving DESC;

Table 6 — Route difficulty score
sql
CREATE TABLE railwaydb2.route_difficulty
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
)
AS
SELECT
    train_number,
    train_name,
    from_station_code,
    to_station_code,
    zone,
    MAX(TRY_CAST(distance   AS DOUBLE))                                       AS distance_km,
    MAX(TRY_CAST(duration_h AS DOUBLE))                                       AS hours,
    ROUND(
        MAX(TRY_CAST(distance AS DOUBLE))
        / NULLIF(MAX(TRY_CAST(duration_h AS DOUBLE)), 0)
    , 2)                                                                      AS speed_kmh,
    MAX(
        TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
      + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
      + TRY_CAST(chair_car AS INT)
    )                                                                         AS classes_available,
    MAX(CASE WHEN TRY_CAST(day AS INT) > 1 THEN 1 ELSE 0 END)                AS is_multiday,
    ROUND(
          MAX(TRY_CAST(duration_h AS DOUBLE)) * 10
        - MAX(TRY_CAST(distance AS DOUBLE)
              / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)) * 0.5
        - MAX(TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
            + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
            + TRY_CAST(chair_car AS INT)) * 5
        + MAX(CASE WHEN TRY_CAST(day AS INT) > 1 THEN 20 ELSE 0 END)
    , 1)                                                                      AS difficulty_score,
    CASE
        WHEN ROUND(
              MAX(TRY_CAST(duration_h AS DOUBLE)) * 10
            - MAX(TRY_CAST(distance AS DOUBLE)
                  / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)) * 0.5
            - MAX(TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
                + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
                + TRY_CAST(chair_car AS INT)) * 5
            + MAX(CASE WHEN TRY_CAST(day AS INT) > 1 THEN 20 ELSE 0 END)
        , 1) > 200                                                            THEN 'Very Hard'
        WHEN ROUND(
              MAX(TRY_CAST(duration_h AS DOUBLE)) * 10
            - MAX(TRY_CAST(distance AS DOUBLE)
                  / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)) * 0.5
            - MAX(TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
                + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
                + TRY_CAST(chair_car AS INT)) * 5
            + MAX(CASE WHEN TRY_CAST(day AS INT) > 1 THEN 20 ELSE 0 END)
        , 1) BETWEEN 100 AND 200                                              THEN 'Hard'
        WHEN ROUND(
              MAX(TRY_CAST(duration_h AS DOUBLE)) * 10
            - MAX(TRY_CAST(distance AS DOUBLE)
                  / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)) * 0.5
            - MAX(TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
                + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
                + TRY_CAST(chair_car AS INT)) * 5
            + MAX(CASE WHEN TRY_CAST(day AS INT) > 1 THEN 20 ELSE 0 END)
        , 1) BETWEEN 50 AND 99                                                THEN 'Moderate'
        ELSE                                                                       'Easy'
    END                                                                       AS difficulty_label
FROM railwaydb2.railway_final
WHERE train_number IS NOT NULL
GROUP BY train_number, train_name, from_station_code, to_station_code, zone
ORDER BY difficulty_score DESC;

Table 7 — Nearby stations
sql
CREATE TABLE railwaydb2.nearby_stations
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
)
AS
SELECT
    a.station_code                                                            AS station_a,
    a.station_name                                                            AS name_a,
    b.station_code                                                            AS station_b,
    b.station_name                                                            AS name_b,
    ROUND(
        6371 * ACOS(
            LEAST(1.0,
                COS(RADIANS(TRY_CAST(a.latitude AS DOUBLE)))
              * COS(RADIANS(TRY_CAST(b.latitude AS DOUBLE)))
              * COS(RADIANS(TRY_CAST(b.longitude AS DOUBLE))
                  - RADIANS(TRY_CAST(a.longitude AS DOUBLE)))
              + SIN(RADIANS(TRY_CAST(a.latitude AS DOUBLE)))
              * SIN(RADIANS(TRY_CAST(b.latitude AS DOUBLE)))
            )
        )
    , 1)                                                                      AS distance_between_km
FROM (
    SELECT DISTINCT station_code, station_name, latitude, longitude
    FROM railwaydb2.railway_final
    WHERE latitude  IS NOT NULL AND latitude  != ''
      AND longitude IS NOT NULL AND longitude != ''
      AND TRY_CAST(latitude  AS DOUBLE) IS NOT NULL
      AND TRY_CAST(longitude AS DOUBLE) IS NOT NULL
) a
JOIN (
    SELECT DISTINCT station_code, station_name, latitude, longitude
    FROM railwaydb2.railway_final
    WHERE latitude  IS NOT NULL AND latitude  != ''
      AND longitude IS NOT NULL AND longitude != ''
      AND TRY_CAST(latitude  AS DOUBLE) IS NOT NULL
      AND TRY_CAST(longitude AS DOUBLE) IS NOT NULL
) b ON a.station_code < b.station_code
WHERE ROUND(
        6371 * ACOS(
            LEAST(1.0,
                COS(RADIANS(TRY_CAST(a.latitude AS DOUBLE)))
              * COS(RADIANS(TRY_CAST(b.latitude AS DOUBLE)))
              * COS(RADIANS(TRY_CAST(b.longitude AS DOUBLE))
                  - RADIANS(TRY_CAST(a.longitude AS DOUBLE)))
              + SIN(RADIANS(TRY_CAST(a.latitude AS DOUBLE)))
              * SIN(RADIANS(TRY_CAST(b.latitude AS DOUBLE)))
            )
        )
    , 1) < 50
ORDER BY distance_between_km ASC;
Note: LEAST(1.0, ...) added to prevent ACOS from crashing on floating point rounding errors — common with coordinate math in Athena.

Table 8 — Train type profile
sql
CREATE TABLE railwaydb2.train_type_profile
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
)
AS
SELECT
    type                                                                      AS train_type,
    COUNT(DISTINCT train_number)                                              AS total_trains,
    ROUND(
        COUNT(DISTINCT train_number) * 100.0
        / SUM(COUNT(DISTINCT train_number)) OVER ()
    , 2)                                                                      AS pct_share,
    ROUND(AVG(
        TRY_CAST(distance AS DOUBLE) / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)
    ), 2)                                                                     AS avg_speed_kmh,
    ROUND(AVG(TRY_CAST(distance   AS DOUBLE)), 0)                             AS avg_distance_km,
    ROUND(AVG(TRY_CAST(duration_h AS DOUBLE)), 1)                             AS avg_duration_hrs,
    SUM(CASE
        WHEN TRY_CAST(first_ac  AS INT) = 1
          OR TRY_CAST(second_ac AS INT) = 1
        THEN 1 ELSE 0
    END)                                                                      AS with_premium_ac,
    SUM(CASE WHEN TRY_CAST(third_ac AS INT) = 1 THEN 1 ELSE 0 END)           AS with_3ac,
    SUM(CASE WHEN TRY_CAST(sleeper  AS INT) = 1 THEN 1 ELSE 0 END)           AS with_sleeper
FROM railwaydb2.railway_final
WHERE type IS NOT NULL
  AND type != ''
GROUP BY type
ORDER BY avg_speed_kmh DESC;

Table 9 — Underserved stations
sql
CREATE TABLE railwaydb2.underserved_stations
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
)
AS
SELECT
    station_code,
    station_name,
    state,
    zone,
    TRY_CAST(latitude  AS DOUBLE)                                             AS latitude,
    TRY_CAST(longitude AS DOUBLE)                                             AS longitude,
    COUNT(DISTINCT train_number)                                              AS trains_available,
    MAX(
        TRY_CAST(first_ac  AS INT)
      + TRY_CAST(second_ac AS INT)
      + TRY_CAST(third_ac  AS INT)
    )                                                                         AS ac_options,
    MAX(TRY_CAST(sleeper AS INT))                                             AS has_sleeper,
    CASE
        WHEN COUNT(DISTINCT train_number) <= 2
         AND MAX(
             TRY_CAST(first_ac  AS INT)
           + TRY_CAST(second_ac AS INT)
           + TRY_CAST(third_ac  AS INT)
         ) = 0                                                                THEN 'Critically Underserved'
        WHEN COUNT(DISTINCT train_number) <= 4                                THEN 'Underserved'
        ELSE                                                                       'Adequate'
    END                                                                       AS connectivity_status
FROM railwaydb2.railway_final
WHERE station_code IS NOT NULL
GROUP BY station_code, station_name, state, zone, latitude, longitude
HAVING COUNT(DISTINCT train_number) <= 4
ORDER BY trains_available ASC;

Table 10 — Journey stop density
sql
CREATE TABLE railwaydb2.journey_stop_density
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
)
AS
SELECT
    train_number,
    train_name,
    from_station_code,
    to_station_code,
    zone,
    type,
    COUNT(DISTINCT station_code)                                              AS total_stops,
    MAX(TRY_CAST(distance   AS DOUBLE))                                       AS total_km,
    MAX(TRY_CAST(duration_h AS DOUBLE))                                       AS total_hrs,
    ROUND(
        MAX(TRY_CAST(distance AS DOUBLE))
        / NULLIF(COUNT(DISTINCT station_code), 0)
    , 1)                                                                      AS avg_km_between_stops,
    MAX(TRY_CAST(day AS INT))                                                 AS days_span,
    CASE
        WHEN ROUND(
            MAX(TRY_CAST(distance AS DOUBLE))
            / NULLIF(COUNT(DISTINCT station_code), 0)
        , 1) > 100                                                            THEN 'Express'
        WHEN ROUND(
            MAX(TRY_CAST(distance AS DOUBLE))
            / NULLIF(COUNT(DISTINCT station_code), 0)
        , 1) BETWEEN 50 AND 100                                               THEN 'Semi-express'
        ELSE                                                                       'Local'
    END                                                                       AS stop_pattern
FROM railwaydb2.railway_final
WHERE train_number IS NOT NULL
GROUP BY train_number, train_name, from_station_code, to_station_code, zone, type
ORDER BY total_stops DESC;

Table 11 — Busiest source stations
sql
CREATE TABLE railwaydb2.busiest_source_stations
WITH (
    format = 'PARQUET',
    external_location = 's3://link'
AS
SELECT
    from_station_code                                                         AS source_station,
    COUNT(DISTINCT train_number)                                              AS trains_originated,
    COUNT(DISTINCT to_station_code)                                           AS unique_destinations,
    COUNT(DISTINCT zone)                                                      AS zones_covered,
    ROUND(AVG(TRY_CAST(distance AS DOUBLE)), 0)                               AS avg_route_km,
    SUM(CASE
        WHEN TRY_CAST(first_ac  AS INT) = 1
          OR TRY_CAST(second_ac AS INT) = 1
        THEN 1 ELSE 0
    END)                                                                      AS premium_trains,
    SUM(CASE
        WHEN TRY_CAST(sleeper AS INT) = 1
        THEN 1 ELSE 0
    END)                                                                      AS sleeper_trains
FROM railwaydb2.railway_final
WHERE from_station_code IS NOT NULL
  AND from_station_code != ''
GROUP BY from_station_code
ORDER BY trains_originated DESC
LIMIT 20;

Table 12 — Train recommendation leaderboard
sql
CREATE TABLE railwaydb2.train_recommendation
WITH (
    format = 'PARQUET',
    external_location = 's3://link
)
AS
SELECT
    train_number,
    train_name,
    from_station_code,
    to_station_code,
    zone,
    type,
    MAX(TRY_CAST(distance   AS DOUBLE))                                       AS km,
    MAX(TRY_CAST(duration_h AS DOUBLE))                                       AS hrs,
    ROUND(
        MAX(TRY_CAST(distance AS DOUBLE))
        / NULLIF(MAX(TRY_CAST(duration_h AS DOUBLE)), 0)
    , 1)                                                                      AS speed_kmh,
    MAX(
        TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
      + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
      + TRY_CAST(chair_car AS INT)
    )                                                                         AS classes,
    MAX(CASE WHEN TRY_CAST(day AS INT) > 1 THEN 1 ELSE 0 END)                AS is_multiday,
    ROUND(
          MAX(TRY_CAST(distance AS DOUBLE)
              / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)) * 0.4
        + MAX(TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
            + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
            + TRY_CAST(chair_car AS INT)) * 5.0
        - MAX(CASE WHEN TRY_CAST(day AS INT) > 1 THEN 10 ELSE 0 END)
    , 1)                                                                      AS recommendation_score,
    CASE
        WHEN ROUND(
              MAX(TRY_CAST(distance AS DOUBLE)
                  / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)) * 0.4
            + MAX(TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
                + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
                + TRY_CAST(chair_car AS INT)) * 5.0
            - MAX(CASE WHEN TRY_CAST(day AS INT) > 1 THEN 10 ELSE 0 END)
        , 1) >= 50                                                            THEN 'Highly Recommended'
        WHEN ROUND(
              MAX(TRY_CAST(distance AS DOUBLE)
                  / NULLIF(TRY_CAST(duration_h AS DOUBLE), 0)) * 0.4
            + MAX(TRY_CAST(first_ac  AS INT) + TRY_CAST(second_ac AS INT)
                + TRY_CAST(third_ac  AS INT) + TRY_CAST(sleeper   AS INT)
                + TRY_CAST(chair_car AS INT)) * 5.0
            - MAX(CASE WHEN TRY_CAST(day AS INT) > 1 THEN 10 ELSE 0 END)
        , 1) BETWEEN 30 AND 49.9                                              THEN 'Good Option'
        ELSE                                                                       'Consider Alternatives'
    END                                                                       AS verdict
FROM railwaydb2.railway_final
WHERE train_number IS NOT NULL
GROUP BY train_number, train_name, from_station_code, to_station_code, zone, type
ORDER BY recommendation_score DESC;

