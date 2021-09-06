---
title: GIS set-up
---

In this step we use functions in the _GDAL_ library and other programs to read the spatial raster data with the vegetation map from NatureServe

# International Vegetation Classification (IVC or EcoVeg)

The IUCN Red List of Ecosystem assessment of forest macrogroups in the Americas was based on the IVC classification documented here:

https://www.natureserve.org/conservation-tools/projects/international-vegetation-classification


## North America and South America

Data set description in:
http://hub.arcgis.com/datasets/b25fa8f7673749fc85e0ba7980374c5f
http://hub.arcgis.com/datasets/Natureserve::southamerica-ivc-macrogroups-potential-natureserve-v1

 The original files of the potential distribution of the Macrogroups in geotiff format were delivered by NatureServe, files were encoded in .lpk format, I extracted them using the 7z extraction command.

```sh

source ~/proyectos/IUCN/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR
cp $GISDATA/ecosistemas/NatureServe/*potential*tif.lpk $WORKDIR
7z x SouthAmerica_IVC_MacroGroups_potential_NatureServe_v7_270m_tif.lpk
7z x NorthAmerica_Caribbean_IVC_MacroGroups_potential_NatureServe_v5_270m_tif.lpk
```
The layer package contains different files, raster are located in folder `commondata/raster_data/`. Original projections: files differed in the original projection.

```sh
gdalinfo commondata/raster_data/NorthAmerica_Caribbean_IVC_MacroGroups_potential_NatureServe_v5_270m.tif

gdalinfo commondata/raster_data/SouthAmerica_IVC_MacroGroups_potential_NatureServe_v7_270m.tif | less
```

### Reprojection

In order to combine both layers in one file with a common projection, I used gdalwarp and chose the robin projection for the whole continent. Output file is IVC_NS_v7_270m_robin.tif. Create option `COMPRESS=LZW` allows for lossless data compression

```sh

gdalwarp -co "COMPRESS=LZW" -t_srs '+proj=robin +lon_0=-80 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +ellps=WGS84 +towgs84=0,0,0' commondata/raster_data/NorthAmerica_Caribbean_IVC_MacroGroups_potential_NatureServe_v5_270m.tif commondata/raster_data/SouthAmerica_IVC_MacroGroups_potential_NatureServe_v7_270m.tif IVC_NS_v7_270m_robin.tif

rm -r commondata/ esriinfo/ v10 v103/

rm *lpk

```

### Attribute tables

Some information on the units of the EcoVeg classification are stored in an access database:

```sh
 mdb-tables -d ";" gisdata/ecosistemas/Natureserve/IUCN/Docs/IUCN\ data.accdb
mdb-export gisdata/ecosistemas/Natureserve/IUCN/Docs/IUCN\ data.accdb "Ecosystem" | head

```

Other information is available in the attribute table from the GeoTiff raster files (in `dbf` format). We can use `R` for extracting this data and translating to the PostgreSQL database, but there are inconsistencies in names and values.

```{r}
##R --vanilla
require(dplyr)
require(foreign)
work.dir <- Sys.getenv("WORKDIR")
setwd(work.dir)
## make sure to have the NatureServe files extracted here
## inc/gdal/merge_input_to_IVC_raster.sh

tmp1 <- read.dbf("commondata/raster_data/NorthAmerica_Caribbean_IVC_MacroGroups_potential_NatureServe_v5_270m.tif.vat.dbf")
tmp2 <- read.dbf("commondata/raster_data/SouthAmerica_IVC_MacroGroups_potential_NatureServe_v7_270m.tif.vat.dbf")
total.cols <- colnames(tmp1)[colnames(tmp1) %in% colnames(tmp2)]
tmp <- rbind(tmp1[,total.cols],
  tmp2[,total.cols])

dim(tmp)
unique(tmp$mg_key)
with(tmp,aggregate(Count,list(Value,mg_key),sum))


IVC_eco = tmp %>%
  filter(!is.na(mg_key)) %>%
    group_by_at(names(tmp)[-grep("Count", names(tmp))]) %>%
      summarise(total = sum(Count, na.rm = TRUE))

#dbWriteTable(con,"tmptable3",IVC_eco,overwrite=T,row.names = FALSE)
#qry <- "INSERT INTO ivc_americas SELECT * FROM tmptable3 ON CONFLICT (mg_key) DO NOTHING"
#dbSendQuery(con,qry)
#qry <- "DROP TABLE tmptable3"
#dbSendQuery(con,qry)

```
