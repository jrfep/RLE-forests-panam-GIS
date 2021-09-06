---
title: AOO grid
---

In this step we use _GRASS GIS_  and functions in the _GDAL_ library to create a regular grid over the extent of the potential vegetation map.

We use this 10x10km grid for calculation of Area of Occupancy (AOO) to inform criterion B and as a basis for disaggregating spatial analysis for other criteria.

```sh
source $HOME/proyectos/IUCN/RLE-forests-panam-GISenv/project-env.sh
cd $WORKDIR
conda deactivate
grass --text $GISDB/IVC/criterionB
v.mkgrid map=AOO_grid box=10000,10000
v.to.rast input=AOO_grid@PERMANENT output=AOO_rgrid use=cat memory=3000

r.stats -acn input=IVC_NS_v7@PERMANENT,AOO_rgrid output=AOOcalc.tab

v.out.ogr input=AOO_grid@PERMANENT output=AOO_grid format=ESRI_Shapefile

psql -d IUCN -c "CREATE SCHEMA ivc_rle"

ogr2ogr -f "PostgreSQL" PG:"host=$DBHOST user=$DBUSER dbname=""$DBNAME""" -lco SCHEMA=ivc_rle AOO_grid AOO_grid -nln aoo_grid


```

Add tables in postgis (`psql -h $DBHOST -d $DBNAME -U $DBUSER`) to add information on the AOO

```sql
-- ogc_fid (index) and cat have the same values
SELECT ogc_fid=cat as prb,count(*) FROM ivc_rle.aoo_grid group by prb;

ALTER TABLE ivc_americas ADD CONSTRAINT ivc_value_key UNIQUE(value) ;

CREATE TABLE ivc_rle.aoo_ivc(
   ivc_value integer ,
   aoo_cat integer ,
   area numeric,
   cells numeric,
   CONSTRAINT uid PRIMARY KEY (ivc_value,aoo_cat));
ALTER TABLE  ivc_rle.aoo_ivc ADD CONSTRAINT aoo_cat_fkey FOREIGN KEY(aoo_cat) REFERENCES ivc_rle.aoo_grid(ogc_fid) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE  ivc_rle.aoo_ivc ADD CONSTRAINT aoo_ivc_fkey FOREIGN KEY(ivc_value) REFERENCES ivc_americas(value) ON DELETE CASCADE ON UPDATE CASCADE;

```


```{r}
##R --vanilla
require(readr)
require(dplyr)
require(RPostgreSQL)

drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = iucn.dbinfo$database,
                 host = iucn.dbinfo$host, port = iucn.dbinfo$port,
                 user = iucn.dbinfo$user)

AOO <- read_delim("AOOcalc.tab",delim=" ",col_names=c("ivc_value","aoo_cat","area","cells"))
AOO %>% filter(ivc_value %in% 603 & area>1e6)

qry <- "SELECT distinct value from ivc_americas"
res <- dbGetQuery(con,qry)

AOO %>% filter( ivc_value %in% res$value ) -> AOO.slc

dbWriteTable(con,name=c("ivc_rle","aoo_ivc"),AOO.slc,row.names=F,append=T)

dbDisconnect(con)
```
