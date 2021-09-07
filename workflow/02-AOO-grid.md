---
title: AOO grid
---

In this step we use _GRASS GIS_  and functions in the _GDAL_ library to create a regular grid over the extent of the potential vegetation map.

We use this 10x10km grid for calculation of Area of Occupancy (AOO) to inform criterion B and as a basis for disaggregating spatial analysis for other criteria.

```sh
source $HOME/proyectos/IUCN/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR
conda deactivate
grass --text $GISDB/IVC/criterionB
v.mkgrid map=AOO_grid box=10000,10000
v.to.rast input=AOO_grid@PERMANENT output=AOO_rgrid use=cat memory=3000

r.stats -acn input=IVC_NS_v7@PERMANENT,AOO_rgrid output=AOOcalc.tab

v.out.ogr input=AOO_grid@PERMANENT output=AOO_grid format=ESRI_Shapefile

# will give an error with old gdal version and new postgis version
# works with GDAL 3.2.0, released 2020/10/26 and postgres 13.3
# does not work with GDAL 2.2.3, released 2017/11/20
ogr2ogr -f "PostgreSQL" PG:"host=$DBHOST user=$DBUSER dbname=""$DBNAME""" -lco SCHEMA=ivc_rle AOO_grid AOO_grid -nln aoo_grid


```

Add tables in postgis (`psql -h $DBHOST -d $DBNAME -U $DBUSER`) to add information on the AOO

```sql
-- ogc_fid (index) and cat have the same values
-- SELECT ogc_fid=cat as prb,count(*) FROM ivc_rle.aoo_grid group by prb;

-- ALTER TABLE ivc_rle.macrogroups ADD CONSTRAINT ivc_value_key UNIQUE(value) ;

CREATE TABLE ivc_rle.aoo_ivc(
   ivc_value integer ,
   aoo_cat integer ,
   area numeric,
   cells numeric,
   CONSTRAINT uid PRIMARY KEY (ivc_value,aoo_cat));
ALTER TABLE  ivc_rle.aoo_ivc ADD CONSTRAINT aoo_cat_fkey FOREIGN KEY(aoo_cat) REFERENCES ivc_rle.aoo_grid(ogc_fid) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE  ivc_rle.aoo_ivc ADD CONSTRAINT aoo_ivc_fkey FOREIGN KEY(ivc_value) REFERENCES ivc_rle.macrogroups(ivc_value) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE ivc_rle.aoo_grid ADD COLUMN area_ivc numeric;
--ALTER TABLE ivc_rle.aoo_ivc DROP COLUMN area_ivc;
ALTER TABLE ivc_rle.aoo_grid ADD COLUMN area_1A numeric;
ALTER TABLE ivc_rle.aoo_grid ADD COLUMN area_1B numeric;

```

Read the output from Grass to populate a table in the database:

```{r}
##R --vanilla
require(readr)
require(dplyr)
require(RPostgreSQL)

drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = Sys.getenv("DBNAME"),
                 host = Sys.getenv("DBHOST"), port = Sys.getenv("DBPORT"),
                 user = Sys.getenv("DBUSER"))

AOO <- read_delim("AOOcalc.tab",delim=" ",col_names=c("ivc_value","aoo_cat","area","cells"))
AOO %>% filter(ivc_value %in% 603 & area>1e6)

qry <- "SELECT distinct ivc_value from ivc_rle.macrogroups"
res <- dbGetQuery(con,qry)

AOO %>% filter( ivc_value %in% res$ivc_value ) -> AOO.slc

dbWriteTable(con,name=c("ivc_rle","aoo_ivc"),AOO.slc,row.names=F,append=T)

dbDisconnect(con)
```

We can now create a map of the full extent of the distribution (using AOO grid cells) in `psql -h $DBHOST -d $DBNAME -U $DBUSER`. First we update info in the aoo_grid table:

```sql
UPDATE ivc_rle.aoo_grid SET area_ivc=NULL,area_1A=NULL,area_1B=NULL;

INSERT INTO ivc_rle.aoo_grid (ogc_fid,area_ivc)
(SELECT aoo_cat,SUM(area) FROM ivc_rle.aoo_ivc GROUP BY aoo_cat)
ON CONFLICT (ogc_fid) DO UPDATE SET area_ivc=EXCLUDED.area_ivc;

INSERT INTO ivc_rle.aoo_grid (ogc_fid,area_1A)
(SELECT aoo_cat,SUM(area) FROM ivc_rle.aoo_ivc
LEFT JOIN ivc_rle.macrogroups USING(ivc_value)
WHERE parent like '1.A%'
GROUP BY aoo_cat)
ON CONFLICT (ogc_fid) DO UPDATE SET area_1A=EXCLUDED.area_1A;

INSERT INTO ivc_rle.aoo_grid (ogc_fid,area_1B)
(SELECT aoo_cat,SUM(area) FROM ivc_rle.aoo_ivc
LEFT JOIN ivc_rle.macrogroups USING(ivc_value)
WHERE parent like '1.B%'
GROUP BY aoo_cat)
ON CONFLICT (ogc_fid) DO UPDATE SET area_1B=EXCLUDED.area_1B;
```

Then we extract these grids and merge them:
```sql
-- DROP TABLE ivc_rle.assessment_dist;

CREATE TABLE ivc_rle.assessment_dist AS
SELECT 'Full extent of ivc map' as description,ST_UNION(wkb_geometry) AS wkb_geometry
FROM ivc_rle.aoo_grid
WHERE area_ivc IS NOT NULL AND area_ivc>0;

INSERT INTO ivc_rle.assessment_dist
SELECT 'Extent of 1.A formation' as description,ST_UNION(wkb_geometry) AS wkb_geometry
FROM ivc_rle.aoo_grid
WHERE area_1A IS NOT NULL AND area_1A>0;

INSERT INTO ivc_rle.assessment_dist
SELECT 'Extent of 1.B formation' as description,ST_UNION(wkb_geometry) AS wkb_geometry
FROM ivc_rle.aoo_grid
WHERE area_1B IS NOT NULL AND area_1B>0;

SELECT description,st_area(wkb_geometry)/1e6 as area_km2 FROM ivc_rle.assessment_dist;

```

Now we create a table with the extent of each macrogroup:

```sql

SELECT mg_key,parent,name,count(distinct aoo_cat) as n_cells,sum(area) as pot_area,st_union(wkb_geometry) as full_geom FROM ivc_rle.macrogroups LEFT JOIN ivc_rle.aoo_ivc USING (ivc_value) INNER JOIN ivc_rle.aoo_grid ON aoo_cat=cat GROUP BY mg_key,parent,name;

-- DROP TABLE ivc_rle.mg_dist;

CREATE TABLE ivc_rle.mg_dist AS
SELECT mg_key,parent,name,count(distinct aoo_cat) as n_cells,sum(area) as pot_area,st_union(wkb_geometry) as full_geom FROM ivc_rle.macrogroups LEFT JOIN ivc_rle.aoo_ivc USING (ivc_value) INNER JOIN ivc_rle.aoo_grid ON aoo_cat=cat GROUP BY mg_key,parent,name;

-- Check results:
SELECT parent || '.' || (SUBSTR(mg_key,2,4)::integer) || ' - ' || name as eco_name,
ROUND(pot_area/1e6) AS occurrence_area,
st_area(full_geom)/1e6 AS grid_area,
ST_AsText(ST_Transform(ST_PointOnSurface(full_geom),4326))
FROM ivc_rle.mg_dist;


```

Now we can read these in R with sf:

```{r}
##R --vanilla
require(dplyr)
require(sf)
require(RPostgreSQL)

source(sprintf("%s/proyectos/IUCN/RLE-forests-panam-GIS/env/project-env.R",Sys.getenv("HOME")))

drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = rle.dbinfo[['database']],
                 host = rle.dbinfo[['host']], port = rle.dbinfo[['port']],
                 user = rle.dbinfo[['user']])


qry <- "SELECT ST_Simplify(ST_Transform(wkb_geometry,4326),0.15)
FROM ivc_rle.assessment_dist"

asmarea.mgs <- read_sf(con,query=qry)
plot(asmarea.mgs %>% slice(1)) # good
plot(asmarea.mgs %>% slice(2)) # good
plot(asmarea.mgs %>% slice(3)) # good


qry <- "SELECT parent || '.' || (SUBSTR(mg_key,2,4)::integer) || ' - ' || name as eco_name, ROUND(pot_area/1e6) AS occurrence_area, st_area(full_geom)/1e6 AS grid_area,ST_Transform(full_geom,4326)
FROM ivc_rle.mg_dist
WHERE parent like '1.B.1%'
"

mgs <- read_sf(con,query=qry)
 mgs %>% st_drop_geometry
plot(mgs['occurrence_area'])


qry <- "SELECT parent || '.' || (SUBSTR(mg_key,2,4)::integer) || ' - ' || name as eco_name, ROUND(pot_area/1e6) AS occurrence_area, st_area(full_geom)/1e6 AS grid_area, category[1] as overall,threat_criteria,ST_Transform(full_geom,4326)
FROM ivc_rle.mg_dist
LEFT JOIN ivc_rle.assessment USING (mg_key)
WHERE parent like '1.A.1%' AND country ='global' AND ref_code='Ferrer-Paris et al. 2019'
"

mgs.asm <- read_sf(con,query=qry)

plot(mgs.asm['overall'])
plot(st_union(mgs.asm))
plot(st_point_on_surface(mgs.asm),add=T,pch=19,col=2)

dbDisconnect(con)
```
