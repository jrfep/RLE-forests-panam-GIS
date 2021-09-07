#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
# test if there is at least one argument: if not, return an error
if (length(args)==0) {
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
}
require(readr)
require(dplyr)
require(sf)
require(raster)
require(RPostgreSQL)

source(sprintf("%s/proyectos/IUCN/RLE-forests-panam-GIS/env/project-env.R",Sys.getenv("HOME")))

drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = rle.dbinfo[['database']],
                 host = rle.dbinfo[['host']], port = rle.dbinfo[['port']],
                 user = rle.dbinfo[['user']])

slc <- "294"
slc <- args[1]

gis.dir <- "/opt/gisdb/extra-gisdata/sensores/Landsat"
version <- "GFC-2019-v1.7"

tDir <- tempdir() # works on all platforms with a platform-dependent result
setwd(tDir)

# avoid duplicates
qry <- sprintf("SELECT aoo_cat FROM ivc_rle.aoo_ivc WHERE ivc_value='%s' AND aoo_cat NOT IN (SELECT aoo_cat FROM ivc_rle.aoo_gfc)",slc)
grds <- dbGetQuery(con,qry)$aoo_cat


for (g in sample(grds)) {
   system("rm -f tmp_*.tif")
   # check again to avoid duplicates in parallel run
   check <- dbGetQuery(con,sprintf("select count(*) from ivc_rle.aoo_gfc where aoo_cat ='%s'",g))

   if (check$count==0) {
      qry <- sprintf("select ogc_fid,wkb_geometry FROM ivc_rle.aoo_grid where ogc_fid = '%s'",g)
      tst <- st_read(con,  query = qry,quiet=T)
      bb <- st_bbox(tst)

      prj4 <- "+proj=robin +lon_0=-80 +x_0=0 +y_0=0 +no_defs +a=6378137 +rf=298.257223563 +towgs84=0.000,0.000,0.000 +to_meter=1"
         for (variable in c("treecover2000","lossyear","gain")) {
         system(sprintf("gdalwarp -t_srs '%1$s' -te %2$s %3$s %4$s %5$s %6$s/index_%7$s_%8$s.vrt  tmp_%8$s.tif", prj4,bb$xmin,bb$ymin,bb$xmax,bb$ymax,gis.dir,version,variable))
      }

      r0 <- raster("tmp_treecover2000.tif")
      r1 <- raster("tmp_lossyear.tif")
      r2 <- raster("tmp_gain.tif")

      tree <- values(r0)* prod(res(r0))
      gain <- values(r2)*prod(res(r0))
      loss <- values(r1)

      tree.ts <- sum(tree)
      for (k in 1:19)
       tree.ts <- c(tree.ts,sum(tree * (1-(loss %in% 1:k))) + sum(gain)/19)

       dbSendQuery(con,sprintf("INSERT INTO ivc_rle.aoo_gfc values(%s,%s) ON CONFLICT DO NOTHING",g,paste(tree.ts/1e6,collapse=",")))
       rm(tree.ts)
         system("rm -f tmp_*.tif")
   }
}

dbDisconnect(con)
