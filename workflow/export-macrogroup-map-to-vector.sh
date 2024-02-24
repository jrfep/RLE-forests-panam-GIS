# 640 is Amazon Delta Swamp Forest 

source ~/proyectos/IUCN-RLE/RLE-forests-panam-GIS/env/project-env.sh
cd $WORKDIR

cp $GISDATA/vegetation/regional/IVC-EcoVeg/Americas/IVC_NS_v7_270m_robin.tif $WORKDIR
wget --continue "https://figshare.com/ndownloader/files/13874333" --output-document="MacrogroupsCountry.rda"

module load r/4.2.2 

Rscript --vanilla -e 'load("MacrogroupsCountry.rda"); write.csv(Macrogroups.Global,file="macrogroups_global.csv")'

module add gdal

# this only has information on the clasification
ogr2ogr -f CSV query-IVC-nac \
    $GISDATA/vegetation/regional/IVC-EcoVeg/NAC/commondata/raster_data/NorthAmerica_Caribbean_IVC_MacroGroups_potential_NatureServe_v5_270m.tif.vat.dbf \
    -sql "SELECT Value,macrogroup,mg_hierarc,mg_key FROM \"NorthAmerica_Caribbean_IVC_MacroGroups_potential_NatureServe_v5_270m.tif.vat\""
ogr2ogr -f CSV query-IVC-sam \
    $GISDATA/vegetation/regional/IVC-EcoVeg/SAM/commondata/raster_data/SouthAmerica_IVC_MacroGroups_potential_NatureServe_v7_270m.tif.vat.dbf \
    -sql "SELECT Value,macrogroup,mg_hierarc,mg_key FROM \"SouthAmerica_IVC_MacroGroups_potential_NatureServe_v7_270m.tif.vat\""

#grep M${MCDG} query-IVC-sam/SouthAmerica_IVC_MacroGroups_potential_NatureServe_v7_270m.tif.vat.csv | awk -F "," '{ print $2}' 


mkdir -p $WORKDIR/raster-data-potential-dist
mkdir -p $WORKDIR/vector-data-potential-dist

cd $WORKDIR
awk -F "," '/1.B.[1-4]/{print $4}' query-IVC-sam/SouthAmerica_IVC_MacroGroups_potential_NatureServe_v7_270m.tif.vat.csv | sed -e s/\"//g > list.mcdgs
awk -F "," '/1.B.[1-4]/{print $4}' query-IVC-nac/NorthAmerica_Caribbean_IVC_MacroGroups_potential_NatureServe_v5_270m.tif.vat.csv | sed -e s/\"//g >> list.mcdgs
awk -F "," '/1.A.[1-4]/{print $4}' query-IVC-nac/NorthAmerica_Caribbean_IVC_MacroGroups_potential_NatureServe_v5_270m.tif.vat.csv | sed -e s/\"//g >> list.mcdgs
awk -F "," '/1.A.[1-4]/{print $4}' query-IVC-sam/SouthAmerica_IVC_MacroGroups_potential_NatureServe_v7_270m.tif.vat.csv | sed -e s/\"//g >> list.mcdgs

cd $WORKDIR/raster-data-potential-dist


for MCDG in $(uniq $WORKDIR/list.mcdgs)
do
    IUCNCAT=$(awk  -vFPAT='([^,]*)|("[^"]+")' -vOFS=, '/'$MCDG'/{ print $5" AS mg_hierarc, "$22" as IUCN_CAT, "$23" as IUCN_BOUNDS, "$24" as IUCN_criteria" }' ../macrogroups_global.csv| sed -e s/NA/NULL/g)
    FILENAME=$(awk  -vFPAT='([^,]*)|("[^"]+")' -vOFS=, '/'$MCDG'/{ print $5 }' ../macrogroups_global.csv| sed -e s/\ /-/g | tr -d \")
    RASTNAME=${MCDG}.tif
    RASTVAL=$(echo $MCDG | sed -s 's/M//' | sed -s 's/^0*//')
    echo $RASTNAME $FILENAME
    
    if [ -e $RASTNAME ] 
    then
      echo $RASTNAME "esta listo"
    else
      gdal_calc.py -A $WORKDIR/IVC_NS_v7_270m_robin.tif \
        --outfile=$RASTNAME \
        --calc="(A==${RASTVAL})*1" --quiet \
        --format=GTiff \
        --creation-option="COMPRESS=DEFLATE" --NoDataValue=0
        #--type=Byte --creation-option="NBITS=1" \ # not needed?
      echo $RASTNAME "creado"
    fi

    for res in 1 # not doing 3 and 5? 
      do 
        if [ -e $WORKDIR/vector-data-potential-dist/${FILENAME}-${res}km.gpkg ]
        then
          echo $FILENAME "listo"
        else
          gdalwarp -tr ${res}000 ${res}000 -r max -co "COMPRESS=DEFLATE" \
              ${RASTNAME} ${MCDG}-${res}km.tif
          gdal_polygonize.py ${MCDG}-${res}km.tif ${MCDG}-${res}km.gpkg -f "GPKG"
          ogr2ogr ${FILENAME}-${res}km.gpkg  ${MCDG}-${res}km.gpkg \
            -dialect sqlite -sql "SELECT '${MCDG}' AS mg_key, $IUCNCAT, ST_union(geom) AS geom FROM out " \
            -nln "rle_assessment" -t_srs "EPSG:4326" \
          	-mo CREATOR="JR Ferrer-Paris" \
                  -mo CITATION="Ferrer-Paris, J. R., Zager, I., Keith, D. A., Oliveira-Miranda, M., Rodríguez, J. P., Josse, C., González-Gil, M., Miller, R. M., Zambrana-Torrelio, C., & Barrow, E. An ecosystem risk assessment of temperate and tropical forests of the Americas with an outlook on future conservation strategies. Conserv. Lett. 12.. https://doi.org/10.1111/conl.12623"\
          	-mo NOTE="Map shows potential distribution. This is a simplified vector in lower resolution than the original raster file."
          	# -simplify ${res}000\ # this step is redundant
          mv ${FILENAME}-${res}km.gpkg $WORKDIR/vector-data-potential-dist
          
          echo ${FILENAME}-${res}km.gpkg "listo"
        fi
      done
done



