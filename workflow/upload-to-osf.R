env.script <- sprintf(
    "%s/proyectos/IUCN-RLE/RLE-forests-panam-GIS/env/project-env.R",
    Sys.getenv("HOME")
    )

source(env.script)

library(dplyr)
library(osfr)
osfcode <- Sys.getenv("OSF_PROJECT")
osf_project <- osf_retrieve_node(sprintf("https://osf.io/%s", osfcode))
osf_folders <- osf_ls_files(osf_project, 
    path="vector-data-potential-dist")


source.file <- sprintf(
    "%s/vector-data-potential-dist/M134-3km-union.gpkg",
    Sys.getenv("TMPDIR")
    )

gbm_data_file  <- 
    osf_upload(
        osf_folders, 
        path = source.file, 
        conflicts="skip")