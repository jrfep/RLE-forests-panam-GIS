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
    pattern="vector-data-potential-dist")


source.dir <- "vector-data-potential-dist"
setwd(work.dir)

upl_data_file  <- 
  osf_upload(
    osf_project, 
    path = source.dir,
    conflict = "skip")


