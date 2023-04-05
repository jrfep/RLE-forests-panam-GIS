
require(mapview)
require(sf)

M134 <- read_sf(sprintf("%s/vector-data-potential-dist/M134-3km-union.gpkg",Sys.getenv("TMPDIR")))
mapview(M134)

M563 <- read_sf(sprintf("%s/vector-data-potential-dist/M563-1km-union.gpkg",Sys.getenv("TMPDIR")))


M294 <- read_sf(sprintf("%s/vector-data-potential-dist/M294-1km-union.gpkg",Sys.getenv("TMPDIR")))
mapview(M294) + mapview(M134) + mapview(M563)


