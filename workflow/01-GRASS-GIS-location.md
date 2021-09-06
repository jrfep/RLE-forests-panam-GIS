---
title: GIS set-up
---

In this step we use _GRASS GIS_  and functions in the _GDAL_ library to create the spatial database for the analysis.

# Create GRASS GIS location and mapsets

Here we create a GRASS GIS location for the analysis

```sh
source $HOME/proyectos/IUCN/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR
conda deactivate

grass --text -c IVC_NS_v7_270m_robin.tif $GISDB/IVC
r.in.gdal input=IVC_NS_v7_270m_robin.tif output=IVC_NS_v7
r.stats IVC_NS_v7
r.colors map=IVC_NS_v7 color=random

# ogrinfo -al -geom=no /opt/gisdata/admin/TMWB/ | less
eval $(g.region -g)
p=$(g.proj -jf)
ogr2ogr -t_srs "${p}" -spat $w $s $e $n -spat_srs "${p}"   Countries.shp $GISDATA/admin/global/TMWB/TM_WORLD_BORDERS-0.3.shp

# -clipsrc spat_extent
# ogrinfo -al Countries.shp | less

v.in.ogr --overwrite -o input=Countries.shp output=Countries snap=1e-05
```

Focus on the Dry Forest macrogroups and reclassify the raster map:

```sh
source $HOME/proyectos/IUCN/RLE-forests-panam-GIS//env/project-env.sh
cd $WORKDIR
conda deactivate

grass --text $GISDB/IVC/PERMANENT

g.region n=3420276.75817 s=-3178511.8677 w=-3391921.6167 e=4905190.74598

 psql -h $DBHOST -d $DBNAME -U $DBUSER -Atn -c "select value, mg_key || ' ' || macrogroup from ivc_americas WHERE ivc_format='Tropical Seasonally Dry Forest'" > tmp
awk -F\| '{$(NF)=++i FS $(NF);}1' OFS=" = " tmp | sed -e "s/|M/ M/" > reclass-macrogroups
echo "* = NULL" >> reclass-macrogroups
r.reclass input=IVC_NS_v7@PERMANENT output=dryforest rules=reclass-macrogroups

r.colors map=dryforest color=random

r.out.gdal --overwrite input=dryforest output=Dry-Forest-Macrogroups.tif createopt="COMPRESS=LZW" nodata=0 type=Byte

```

We create mapsets for each step of the analysis

```sh

g.mapset -c criterionA
g.mapset -c criterionB
g.mapset -c criterionC
g.mapset -c GFC
g.mapset -c GWS
g.mapset -c Modis
g.mapset -c CGLS
g.mapset -c Earthstats
g.mapset -c GHSL

```

# Import datasets

## Global Forest Cover

From:

> Hansen, M. C., P. V. Potapov, R. Moore, M. Hancher, S. A. Turubanova, A. Tyukavina, D. Thau, S. V. Stehman, S. J. Goetz, T. R. Loveland, A. Kommareddy, A. Egorov, L. Chini, C. O. Justice, and J. R. G. Townshend. 2013. *High-Resolution Global Maps of 21st-Century Forest Cover Change.* **Science** 342 (15 November): 850–53. [Data available on-line](http://earthenginepartners.appspot.com/science-2013-global-forest).

We downloaded data from:
http://www.earthenginepartners.appspot.com/science-2013-global-forest/download.html

And we use functions from the GDAL library to project from the virtual raster tiles to the geotiff format:

```sh
source $HOME/proyectos/IUCN/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR
conda deactivate

export LOCALDIR=/opt/gisdb/extra-gisdata/sensores/Landsat
export VRS=GFC-2019-v1.7


VAR=treecover2000 # resample average
if [ ! -e ${VRS}.Americas.${VAR}.tif ]
then
   # Too large TIFF for original resolution
   gdalwarp -t_srs "+proj=robin +lon_0=-80 +x_0=0 +y_0=0 +no_defs +a=6378137 +rf=298.257223563 +towgs84=0.000,0.000,0.000 +to_meter=1" -te -4395624.05347525 -5976709.20900703 4635737.23598334 6839814.73820371 -tr  248.72931119 248.72931119  -tap -r average -co "COMPRESS=LZW" $LOCALDIR/index_${VRS}_${VAR}.vrt  ${VRS}.Americas.${VAR}.tif
fi



VAR=lossyear # use min for this, to use the year deforestation started
if [ ! -e ${VRS}.Americas.${VAR}.tif ]
then
   gdalwarp -t_srs "+proj=robin +lon_0=-80 +x_0=0 +y_0=0 +no_defs +a=6378137 +rf=298.257223563 +towgs84=0.000,0.000,0.000 +to_meter=1" -te -4395624.05347525 -5976709.20900703 4635737.23598334 6839814.73820371 -tr  248.72931119 248.72931119  -tap -r min -co "COMPRESS=LZW" $LOCALDIR/index_${VRS}_${VAR}.vrt  ${VRS}.Americas.${VAR}.tif
fi


VAR=gain # here we use max (to include all 1=gain)
if [ ! -e ${VRS}.Americas.${VAR}.tif ]
then
      gdalwarp -t_srs "+proj=robin +lon_0=-80 +x_0=0 +y_0=0 +no_defs +a=6378137 +rf=298.257223563 +towgs84=0.000,0.000,0.000 +to_meter=1" -te -4395624.05347525 -5976709.20900703 4635737.23598334 6839814.73820371 -tr  248.72931119 248.72931119  -tap -r max -co "COMPRESS=LZW" $LOCALDIR/index_${VRS}_${VAR}.vrt  ${VRS}.Americas.${VAR}.tif
fi


for VAR in lossyear gain treecover2000
do
   grass $GISDB/IVC/GFC --exec r.in.gdal -o input=${VRS}.Americas.${VAR}.tif output=${VAR}
done

grass $GISDB/IVC/GFC --exec r.colors map=treecover2000 color=green
grass $GISDB/IVC/GFC --exec r.colors map=lossyear color=rainbow

```


## Copernicus Global Land Service: Land Cover 100m

From:

> Buchhorn, M. ; Smets, B. ; Bertels, L. ; Lesiv, M. ; Tsendbazar, N. - E. ; Herold, M. ; Fritz, S. Copernicus Global Land Service: Land Cover 100m: epoch 2015: Globe. Dataset of the global component of the Copernicus Land Monitoring Service 2019. DOI 10.5281/zenodo.3243509

And we use functions from the GDAL library to project the landcover layer:

```sh
source $HOME/proyectos/IUCN/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR
conda deactivate
grass --text $GISDB/IVC/CGLS

gdalwarp -t_srs "+proj=robin +lon_0=-80 +x_0=0 +y_0=0 +no_defs +a=6378137 +rf=298.257223563 +towgs84=0.000,0.000,0.000 +to_meter=1" -te -4395624.05347525 -5976709.20900703 4635737.23598334 6839814.73820371 -co "COMPRESS=LZW" $GISDATA/landcover/CGLS/v3.0.1/PROBAV_LC100_global_v3.0.1_2019-nrt_Discrete-Classification-map_EPSG-4326.tif CGLS.Americas.v3.0.1.Discrete-Classification-map.tif
r.in.gdal -o input=CGLS.Americas.v3.0.1.Discrete-Classification-map.tif output=PROBAV_LC100_global_v3

r.stats -acn input=IVC_NS_v7@PERMANENT,PROBAV_LC100_global_v3 output=LC-IVC.tab

```


## Cropland and pature data from Earthstats

From:

> Ramankutty, N., A.T. Evan, C. Monfreda, and J.A. Foley (2008), Farming the planet: 1. Geographic distribution of global agricultural lands in the year 2000. Global Biogeochemical Cycles 22, GB1003, doi:10.1029/2007GB002952.

We downloaded data from: http://www.earthstat.org/cropland-pasture-area-2000/

And we use functions from the GDAL library to project the original data to the Robinson projection:

```sh
source $HOME/proyectos/IUCN/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR
conda deactivate
grass --text $GISDB/IVC/Earthstats
unzip -n $GISDATA/antroposphere/global/Earthstats/CroplandPastureArea2000_Geotiff.zip
for VAR in Cropland2000 Pasture2000
do
   gdalwarp -t_srs "+datum=WGS84 +proj=robin +lon_0=-80 +x_0=0 +y_0=0 +no_defs +a=6378137 +rf=298.257223563 +to_meter=1" -te -4395624.05347525 -5976709.20900703 4635737.23598334 6839814.73820371 -co "COMPRESS=LZW" CroplandPastureArea2000_Geotiff/${VAR}_5m.tif ${VAR}_5m_Americas.tif

   r.in.gdal input=${VAR}_5m_Americas.tif  output=${VAR}
done

```

## Urban infrastructure (built area) from GHSL

From:

> Pesaresi, Martino; Florczyk, Aneta; Schiavina, Marcello; Melchiorri, Michele; Maffenini, Luca (2019): GHS settlement grid, updated and refined REGIO model 2014 in application to GHS-BUILT R2018A and GHS-POP R2019A, multitemporal (1975-1990-2000-2015), R2019A. European Commission, Joint Research Centre (JRC) [Dataset] doi:10.2905/42E8BE89-54FF-464E-BE7B-BF9E64DA5218 PID: http://data.europa.eu/89h/42e8be89-54ff-464e-be7b-bf9e64da5218

We downloaded data from: https://ghsl.jrc.ec.europa.eu/dataToolsOverview.php

And we use functions from the GDAL library to reproject the raster data:

```sh
source $HOME/proyectos/IUCN/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR
conda deactivate
grass --text $GISDB/IVC/GHSL
unzip -n $GISDATA/antroposphere/global/GHSL/GHS_BUILT_LDS2000_GLOBE_R2018A_54009_1K_V2_0.zip
unzip -n $GISDATA/antroposphere/global/GHSL/GHS_SMOD_POP2000_GLOBE_R2019A_54009_1K_V2_0.zip

gdalwarp -t_srs "+datum=WGS84 +proj=robin +lon_0=-80 +x_0=0 +y_0=0 +no_defs +a=6378137 +rf=298.257223563 +to_meter=1" -te -4395624.05347525 -5976709.20900703 4635737.23598334 6839814.73820371 -co "COMPRESS=LZW" GHS_BUILT_LDS2000_GLOBE_R2018A_54009_1K_V2_0.tif GHS_BUILT_LDS2000_Americas.tif

gdalwarp -t_srs "+datum=WGS84 +proj=robin +lon_0=-80 +x_0=0 +y_0=0 +no_defs +a=6378137 +rf=298.257223563 +to_meter=1" -te -4395624.05347525 -5976709.20900703 4635737.23598334 6839814.73820371 -co "COMPRESS=LZW" GHS_SMOD_POP2000_GLOBE_R2019A_54009_1K_V2_0.tif   GHS_SMOD_POP2000_Americas.tif

r.in.gdal input=GHS_BUILT_LDS2000_Americas.tif   output=BUILT_LDS2000
r.in.gdal input=GHS_SMOD_POP2000_Americas.tif   output=SMOD_POP2000

r.mapcalc expression="allpopulated=if(SMOD_POP2000>11,1,0)"
r.stats -acN dryforest,allpopulated

```
