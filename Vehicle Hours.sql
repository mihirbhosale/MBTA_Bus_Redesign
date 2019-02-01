-- Take all non-supplemental, non-shuttle bus routes
DROP TABLE IF EXISTS bus_routes;
CREATE TEMP TABLE bus_routes AS
SELECT DISTINCT route_id, route_desc FROM gtfs_routes
WHERE route_desc LIKE '%Bus%'
AND route_desc NOT LIKE '%Supplemental%'
AND route_id NOT LIKE '%Shuttle%';

-- Find all the trips made on each of the routes above on Weekdays
CREATE TEMP TABLE valid_wkd_trips AS
SELECT DISTINCT route_id, trip_id
FROM gtfs_trips
WHERE route_id IN (SELECT route_id FROM bus_routes)
AND service_id LIKE '%Weekday%';

-- Find all the trips made on each of the routes above on Saturdays
CREATE TEMP TABLE valid_sat_trips AS
SELECT DISTINCT route_id, trip_id
FROM gtfs_trips
WHERE route_id IN (SELECT route_id FROM bus_routes)
AND service_id LIKE '%Saturday%';

-- Find the start and end time for all the trips based on stop times
CREATE TEMP TABLE trip_start_end AS
SELECT trip_id, MIN(departure_time) AS start_time, MAX(arrival_time) AS end_time
FROM gtfs_stop_times
GROUP BY trip_id;
--SELECT * FROM trip_start_end LIMIT 100


-- WEEKDAY VEHICLE HOURS BY ROUTE_DESC
-- Find run times for each trip, and aggregate by type
SELECT route_desc, SUM(travel_time) AS travel_time
FROM	(SELECT v.route_id, r.route_desc
		, (split_part(tt.end_time,':',1)::FLOAT - split_part(tt.start_time,':',1)::FLOAT)
		+ (split_part(tt.end_time,':',2)::FLOAT - split_part(tt.start_time,':',2)::FLOAT)/60.0
		+ (split_part(tt.end_time,':',3)::FLOAT - split_part(tt.start_time,':',3)::FLOAT)/3600.0 AS travel_time
		FROM valid_wkd_trips AS v, bus_routes AS r, trip_start_end AS tt
		WHERE v.route_id = r.route_id
		AND v.trip_id = tt.trip_id) b
GROUP BY route_desc
		
-- SATURDAY VEHICLE HOURS BY ROUTE_DESC
-- Same as above
SELECT route_desc, SUM(travel_time) AS travel_time
FROM	(SELECT v.route_id, r.route_desc
		, (split_part(tt.end_time,':',1)::FLOAT - split_part(tt.start_time,':',1)::FLOAT)
		+ (split_part(tt.end_time,':',2)::FLOAT - split_part(tt.start_time,':',2)::FLOAT)/60.0
		+ (split_part(tt.end_time,':',3)::FLOAT - split_part(tt.start_time,':',3)::FLOAT)/3600.0 AS travel_time
		FROM valid_sat_trips AS v, bus_routes AS r, trip_start_end AS tt
		WHERE v.route_id = r.route_id
		AND v.trip_id = tt.trip_id) b
GROUP BY route_desc
