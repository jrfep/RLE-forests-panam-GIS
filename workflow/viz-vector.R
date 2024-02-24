
require(mapview)
require(sf)

source(sprintf("%s/proyectos/IUCN-RLE/RLE-forests-panam-GIS/env/project-env.R",Sys.getenv("HOME")))
vct.dir <- "vector-data-potential-dist"
target <- "1.B.2.Na.151---Northern-Great-Plains-Woodland-1km.gpkg"

macrogroup_vector <- read_sf(
    sprintf(
        "%s/%s/%s",
        work.dir,
        vct.dir,
        target
        )
    )
mapview(macrogroup_vector)

M563 <- read_sf(sprintf("%s/vector-data-potential-dist/M563-1km-union.gpkg",Sys.getenv("TMPDIR")))

1.B.2.Na.151---Northern-Great-Plains-Woodland-1km.gpkg
M294 <- read_sf(sprintf("%s/vector-data-potential-dist/M294-1km-union.gpkg",Sys.getenv("TMPDIR")))
mapview(M294) + mapview(M134) + mapview(M563)


