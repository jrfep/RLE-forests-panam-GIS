# 640 is Amazon Delta Swamp Forest 

source ~/proyectos/IUCN-RLE/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR
cp $GISDATA/vegetation/regional/IVC-EcoVeg/Americas/IVC_NS_v7_270m_robin.tif $WORKDIR
wget --continue "https://figshare.com/ndownloader/files/13874333" --output-document="MacrogroupsCountry.rda"

module load r/4.2.2 

Rscript --vanilla -e 'load("MacrogroupsCountry.rda"); write.csv(Macrogroups.Global,file="macrogroups_global.csv")'

module add gdal

# this only has information on the clasification
#ogr2ogr -f CSV query-IVC-nac \
#    $GISDATA/vegetation/regional/IVC-EcoVeg/NAC/commondata/raster_data/NorthAmerica_Caribbean_IVC_MacroGroups_potential_NatureServe_v5_270m.tif.vat.dbf \
#    -sql "SELECT Value,macrogroup,mg_hierarc,mg_key FROM \"NorthAmerica_Caribbean_IVC_MacroGroups_potential_NatureServe_v5_270m.tif.vat\""
#grep M${MCDG} query-IVC-sam/SouthAmerica_IVC_MacroGroups_potential_NatureServe_v7_270m.tif.vat.csv | awk -F "," '{ print $2}' 


mkdir -p vector-data-potential-dist
cd vector-data-potential-dist



for MCDG in 640 # 563 572
do
    IUCNCAT=$(awk  -vFPAT='([^,]*)|("[^"]+")' -vOFS=, '/'$MCDG'/{ print $5" AS mg_hierarc, "$22" as IUCN_CAT, "$23" as IUCN_BOUNDS, "$24" as IUCN_criteria" }' ../macrogroups_global.csv| sed -e s/NA/NULL/)

    gdal_calc.py -A $WORKDIR/IVC_NS_v7_270m_robin.tif \
    --outfile=M${MCDG}.tif \
    --calc="(A==${MCDG})*1" --format=GTiff \
    --format=GTiff --type=Byte --creation-option="NBITS=1" \
    --creation-option="COMPRESS=DEFLATE" --NoDataValue=0
    for res in 1 3
    do 
        gdalwarp -tr ${res}000 ${res}000 -r max -co "COMPRESS=DEFLATE" \
            M${MCDG}.tif M${MCDG}-${res}km.tif
        gdal_polygonize.py M${MCDG}-${res}km.tif M${MCDG}-${res}km.gpkg -f "GPKG"
        ogr2ogr M${MCDG}-${res}km-union.gpkg  M${MCDG}-${res}km.gpkg \
        -dialect sqlite -sql "SELECT 'M${MCDG}' AS mg_key, $IUCNCAT, ST_union(geom) AS geom FROM out " \
        -nln "rle_assessment" -t_srs "EPSG:4326" -mo CREATOR="JR Ferrer-Paris" \
        -mo CITATION="Ferrer-Paris, J. R., Zager, I., Keith, D. A., Oliveira-Miranda, M., Rodríguez, J. P., Josse, C., González-Gil, M., Miller, R. M., Zambrana-Torrelio, C., & Barrow, E. An ecosystem risk assessment of temperate and tropical forests of the Americas with an outlook on future conservation strategies. Conserv. Lett. 12.. https://doi.org/10.1111/conl.12623"
    done
done



