# 640 is Amazon Delta Swamp Forest   
mkdir vector-data-potential-dist
cd vector-data-potential-dist
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





gdal_polygonize.py M640_3km.tif M640_3km.gpkg -f "GPKG"




  gdal_calc.py -A IVC_NS_v7_270m_robin.tif --outfile=M${MCDG}.tif --calc="(A==${MCDG})*1" --format=GTiff --type=Byte --creation-option="NBITS=1" --creation-option="COMPRESS=DEFLATE" --NoDataValue=0
  gdal_polygonize.py M${MCDG}.tif M${MCDG}.shp -f "ESRI shapefile"
done
