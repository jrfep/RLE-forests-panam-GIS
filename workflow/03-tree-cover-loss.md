## Criterio A

Add postgres table for results
```sql
CREATE TABLE ivc_rle.aoo_gfc (
   aoo_cat integer PRIMARY KEY,
   tree2000 numeric,
   tree2001 numeric,
   tree2002 numeric,
   tree2003 numeric,
   tree2004 numeric,
   tree2005 numeric,
   tree2006 numeric,
   tree2007 numeric,
   tree2008 numeric,
   tree2009 numeric,
   tree2010 numeric,
   tree2011 numeric,
   tree2012 numeric,
   tree2013 numeric,
   tree2014 numeric,
   tree2015 numeric,
   tree2016 numeric,
   tree2017 numeric,
   tree2018 numeric,
   tree2019 numeric
);
ALTER TABLE  ivc_rle.aoo_gfc ADD CONSTRAINT aoo_cat_fkey FOREIGN KEY(aoo_cat) REFERENCES ivc_rle.aoo_grid(ogc_fid) ON DELETE CASCADE ON UPDATE CASCADE;

```

We will test the calculation in a Grass GIS location

```sh
source $HOME/proyectos/IUCN/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR
conda deactivate
grass --text $GISDB/IVC/criterionA


v.extract input=AOO_grid@PERMANENT cats=609229 output=tmp001@criterionA
eval $(g.region vect=tmp001@criterionA -g)

export LOCALDIR=/opt/gisdb/extra-gisdata/sensores/Landsat
export VRS=GFC-2019-v1.7


VAR=treecover2000 # resample average

for VAR in lossyear gain treecover2000
do
   gdalwarp -t_srs "+proj=robin +lon_0=-80 +x_0=0 +y_0=0 +no_defs +a=6378137 +rf=298.257223563 +towgs84=0.000,0.000,0.000 +to_meter=1" -te $w $s $e $n $LOCALDIR/index_${VRS}_${VAR}.vrt  tmp_${VAR}.tif
   r.in.gdal -o --overwrite input=tmp_${VAR}.tif output=tmp001_${VAR}
done

v.out.ogr input=AOO_grid@PERMANENT output=AOO_grid format=ESRI_Shapefile

ogrinfo -al -geom=no -sql "SELECT * FROM AOO_grid WHERE cat=609229" AOO_grid/ | grep Extent


```


```{r}
for k in $(psql -Atn -h $DBHOST -d $DBNAME -U $DBUSER -c "select ivc_value from ivc_rle.macrogroups WHERE parent like '1.A.1%' AND mg_key IN (SELECT DISTINCT mg_key FROM ivc_rle.assessment WHERE country='global' AND ref_code='Ferrer-Paris et al. 2019') order by ivc_value")
do
   echo $k
  ##nohup Rscript --vanilla $SCRIPTDIR/inc/R/calculate-GFC-per-AOO-cat.R $k &
  Rscript --vanilla $SCRIPTDIR/inc/R/calculate-GFC-per-AOO-cat.R $k
  echo "LISTO"
done


```
