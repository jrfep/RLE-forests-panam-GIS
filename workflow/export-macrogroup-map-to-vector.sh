# 640 is Amazon Delta Swamp Forest 

source ~/proyectos/IUCN-RLE/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR
cp $GISDATA/vegetation/regional/IVC-EcoVeg/Americas/IVC_NS_v7_270m_robin.tif $WORKDIR

mkdir vector-data-potential-dist
cd vector-data-potential-dist

module add gdal 

for MCDG in 640 563 572
do
    gdal_calc.py -A $WORKDIR/IVC_NS_v7_270m_robin.tif \
    --outfile=M${MCDG}.tif \
    --calc="(A==${MCDG})*1" --format=GTiff \
    --format=GTiff --type=Byte --creation-option="NBITS=1" \
    --creation-option="COMPRESS=DEFLATE" --NoDataValue=0
    for res in 1 3
    do 
        gdalwarp -tr ${res}000 ${res}000 -r max M${MCDG}.tif M${MCDG}-${res}km.tif
        gdal_polygonize.py M${MCDG}-${res}km.tif M${MCDG}-${res}km.gpkg -f "GPKG"
        ogr2ogr M${MCDG}-${res}km-union.gpkg  M${MCDG}-${res}km.gpkg \
        -dialect sqlite -sql "SELECT ST_union(geom) AS geom FROM out " \
        -nln "macrogroups" -t_srs "EPSG:4326"
    done
done
#gdal_polygonize.py M640.tif M640.gpkg -f "GPKG"


