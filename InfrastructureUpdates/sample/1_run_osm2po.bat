@echo off

:: ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::  OSM data conversion with OSM2PO (http://osm2po.de/)
::  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
set PG_ID=apichon
set PGPASSWORD=thinkpad
set PG_DB=osmsrilanka
set PG_HOST=localhost
set PG_PORT=5433	
set OSM_SCHEMA=srilanka
set TEMP_DIR=D:\git\CDR-analysis-tools-std\InfrastructureUpdates\tmp
set PG_BIN_PATH=D:\PostgreSQL\9.6\bin

::  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::  run osm2po to convert OSM pbf data into SQL
::  * need to respond license agreement firstly. 
::  * when customizing conversion setting, modify file osm2po.config 
::  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo  osm2po to convert OSM pbf data into SQL...

java -Xmx5G -jar osm2po-core-5.0.0-signed.jar cmd=tjsp prefix=%OSM_SCHEMA% %OSM_SCHEMA%-latest.osm.pbf


::  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::  create raw network table
::  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo  create raw network table...

psql -U %PG_ID% -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -q -c "create schema %OSM_SCHEMA%"
psql -U %PG_ID% -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -q -c "drop table if exists %OSM_SCHEMA%.osm_road"
psql -U %PG_ID% -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -q -f %OSM_SCHEMA%/%OSM_SCHEMA%_2po_4pgr.sql
psql -U %PG_ID% -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -q -c "alter table %OSM_SCHEMA%_2po_4pgr rename to osm_road"
psql -U %PG_ID% -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -q -c "alter table osm_road set schema %OSM_SCHEMA%"

psql -U %PG_ID% -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -q -c "create index idx_%OSM_SCHEMA%_osm_road_source   on %OSM_SCHEMA%.osm_road using btree(source)"
psql -U %PG_ID% -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -q -c "create index idx_%OSM_SCHEMA%_osm_road_target   on %OSM_SCHEMA%.osm_road using btree(target)"
psql -U %PG_ID% -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -q -c "create index idx_%OSM_SCHEMA%_osm_road_geom_way on %OSM_SCHEMA%.osm_road using Gist(geom_way)"

psql -U %PG_ID% -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -q -c "select count(*) as N,sum(ST_length(Geography(geom_way))/1000.0) as km from %OSM_SCHEMA%.osm_road"


::  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::  dump data
::  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::  export road data as tsv File
echo  export road data as tsv File...
mkdir tmp
mkdir dump\tsv
psql -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -q -c "copy %OSM_SCHEMA%.osm_road to '%TEMP_DIR%\%OSM_SCHEMA%.osm_road.tsv'  (delimiter E'\t',format csv,encoding 'UTF-8',header true)"
copy %TEMP_DIR%\%OSM_SCHEMA%.osm_road.tsv dump\tsv\

:: dump road data as sql File
mkdir  dump\sql
pg_dump -d %PG_DB% -h %PG_HOST% -p %PG_PORT% -t %OSM_SCHEMA%.osm_road > dump\sql\%OSM_SCHEMA%.osm_road.sql 

:: extract road data as shape data
mkdir dump\shape\shp_osm_road
%PG_BIN_PATH%\pgsql2shp  -h %PG_HOST% -p %PG_PORT% -f dump\shape\shp_osm_road\%OSM_SCHEMA%_osm_road.shp %PG_DB% %OSM_SCHEMA%.osm_road

