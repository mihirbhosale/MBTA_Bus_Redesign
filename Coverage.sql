---------------------------------------------------------------------------------
----- INITIALIZE
---------------------------------------------------------------------------------
-- MBTA Service Area: Union of the two areas
-- area_primary is the inner service area shapefile,
-- area_secondary is the outer one
DROP TABLE IF EXISTS service_area;
CREATE TABLE service_area AS
SELECT 	ST_UNION((SELECT ST_TRANSFORM(ST_SetSRID(geom, 4326),2163) FROM area_primary) 
				,(SELECT ST_TRANSFORM(ST_SetSRID(geom, 4326),2163) FROM area_secondary)) AS geom
	--Test
	--SELECT ST_TRANSFORM(ST_SetSRID(geom, 4326),2136) FROM area_primary

--Blocks only within MBTA Service Area
--block_groups is the block group shapefile
--This might take some time		
DROP TABLE IF EXISTS service_area_blocks;

CREATE TEMP TABLE service_area_blocks AS
SELECT gid, aland10, awater10, poptotal, geom
FROM block_groups AS b
WHERE ST_INTERSECTS(ST_TRANSFORM(ST_SetSRID(b.geom,4326),2163),(SELECT geom FROM service_area));
	--Query returned successfully in 6 min 40 secs.
															
	--Test
	--SELECT geom FROM service_area_blocks UNION SELECT * FROM mbta_buffer

--Trim above table to exact only service area
--Also takes some time to run
CREATE TEMP TABLE service_area_blocks_trimmed AS
SELECT 	gid, aland10, awater10, poptotal
		, ST_INTERSECTION(ST_TRANSFORM(ST_SetSRID(b.geom,4326),2163),(SELECT geom FROM service_area)) AS geom
FROM	service_area_blocks b
	--Query returned successfully in 9 min 17 secs.

---------------------------------------------------------------------------------
----- BASE COVERAGE
---------------------------------------------------------------------------------
--Get all bus, rapid transit, commuter rail, ferry stops
--(As per the service policy, all modes are to be included)
DROP TABLE IF EXISTS all_stops;

CREATE TABLE all_stops AS
SELECT DISTINCT s.stop_name, s.the_geom
FROM 	gtfs_routes AS r, gtfs_trips AS t, gtfs_stop_times AS st, gtfs_stops AS s
WHERE 	(route_desc LIKE '%Bus%' OR route_desc IN ('Ferry', 'Commuter Rail', 'Rapid Transit'))
	AND route_desc NOT LIKE '%Supplemental%'
	AND r.route_id = t.route_id
	AND t.trip_id = st.trip_id
	AND st.stop_id = s.stop_id;
	
-- Make buffer zone around all stops
DROP TABLE IF EXISTS service_buffer;
CREATE TEMP TABLE service_buffer AS
SELECT	ST_UNION(ST_BUFFER(ST_TRANSFORM(the_geom, 2163),804.672)) AS the_geom
FROM all_stops;	
	--Test					   
	--SELECT ST_TRANSFORM(the_geom,4326) FROM service_buffer

--Clip Buffer Area only within MBTA Service Area
CREATE TEMP TABLE mbta_buffer AS
SELECT 	ST_INTERSECTION((SELECT geom FROM service_area)
				 	   ,(SELECT the_geom FROM service_buffer)) AS geom
	--Test
	--SELECT ST_TRANSFORM(geom, 4326) FROM mbta_buffer

--Intersect with trimmed service blocks
DROP TABLE IF EXISTS mbta_base_coverage;
CREATE TEMP TABLE mbta_base_coverage AS
SELECT 	gid, aland10, awater10, poptotal, b.geom
		, ST_INTERSECTION(b.geom,(SELECT geom FROM mbta_buffer)) AS served_geom
FROM	service_area_blocks_trimmed b 
--Query returned successfully in 5 min 22 secs.

--Base Coverage Table
--This holds the geometries of block groups, and proportion served
--Proportion is calculated by area of block group intersecting 
--with buffer around all stops
DROP TABLE IF EXISTS base_coverage;
CREATE TABLE base_coverage AS
SELECT gid, poptotal, poptotal*ST_AREA(served_geom)/aland10 AS servedpop, 100*ST_AREA(served_geom)/aland10 AS servedpopprop, geom
FROM mbta_base_coverage
WHERE aland10 > 0
	--SELECT SUM(servedpop)/SUM(poptotal)*100 FROM base_coverage
	--^^This gives the overall percentage of base coverage

---------------------------------------------------------------------------------
----- FREQUENT COVERAGE
---------------------------------------------------------------------------------
--Get all key bus route and rapid transit stops
--(As per the service policy, all modes are to be included)
DROP TABLE IF EXISTS freq_stops;
CREATE TABLE freq_stops AS
SELECT DISTINCT s.stop_name, s.the_geom
FROM 	gtfs_routes AS r, gtfs_trips AS t, gtfs_stop_times AS st, gtfs_stops AS s
WHERE 	(route_desc LIKE '%Key Bus%' OR route_desc = 'Rapid Transit')
	AND route_desc NOT LIKE '%Supplemental%'
	AND r.route_id = t.route_id
	AND t.trip_id = st.trip_id
	AND st.stop_id = s.stop_id;
	--Test
	-- SELECT * FROM freq_stops

-- Make buffer zone around frequent stops
DROP TABLE IF EXISTS frequent_buffer;
CREATE TEMP TABLE frequent_buffer AS
SELECT	ST_UNION(ST_BUFFER(ST_TRANSFORM(the_geom, 2163),804.672)) AS the_geom
FROM freq_stops;	
	--Test					   
	--SELECT ST_TRANSFORM(the_geom,4326) FROM frequent_buffer

--Buffer Area only within MBTA Service Area
CREATE TEMP TABLE freq_mbta_buffer AS
SELECT 	ST_INTERSECTION((SELECT geom FROM service_area)
				 	   ,(SELECT the_geom FROM frequent_buffer)) AS geom
	--Test
	--SELECT ST_TRANSFORM(geom, 4326) FROM freq_mbta_buffer

-- Intersect with with trimmed service blocks
DROP TABLE IF EXISTS mbta_freq_coverage;
CREATE TEMP TABLE mbta_freq_coverage AS
SELECT 	gid, aland10, awater10, poptotal, b.geom
		, ST_INTERSECTION(b.geom,(SELECT geom FROM freq_mbta_buffer)) AS served_geom
FROM	service_area_blocks_trimmed b
	--Query returned successfully in 25 secs 115 msec.
	--SELECT * FROM mbta_freq_coverage

-- Find block density in service area and proportion in only dense areas
CREATE TABLE mbta_dense_coverage AS
SELECT 	b.gid, b.aland10, b.awater10, b.poptotal, mb.geom, mb.served_geom
FROM	service_area_blocks_trimmed AS b
LEFT JOIN mbta_freq_coverage AS mb ON 	b.gid = mb.gid
WHERE	b.aland10 > 0 
AND 	b.poptotal/(b.aland10*3.861*POWER(10.0,-7)) > 7000

--Freq Coverage Table
DROP TABLE IF EXISTS freq_coverage;
CREATE TABLE freq_coverage AS
SELECT gid, poptotal, poptotal*ST_AREA(served_geom)/aland10 AS servedpop, 100*ST_AREA(served_geom)/aland10 AS servedpopprop, geom
FROM mbta_dense_coverage
	--SELECT SUM(servedpop)/SUM(poptotal)*100 FROM base_coverage
	--SELECT SUM(poptotal) FROM base_coverage
	--This gives the overall percentage of base coverage