#! R --vanilla
projectname <- "RLE-forests-panam-GIS/"
projectfolder <- "proyectos/IUCN"

if (Sys.getenv("GISDATA") != "") {
   gis.data <- Sys.getenv("GISDATA")
   work.dir <- Sys.getenv("WORKDIR")
   script.dir <- Sys.getenv("SCRIPTDIR")
   src.dir <- Sys.getenv("SRCDIR")
} else {
   out <- Sys.info()
   username <- out[["user"]]
   hostname <- out[["nodename"]]
   script.dir <- sprintf("%s/%s/%s",
      Sys.getenv("HOME"),
      projectfolder,
      projectname)

   switch(hostname,
      terra={
         gis.data <- sprintf("/opt/gisdata/")
         work.dir <- sprintf("%s/tmp/%s",Sys.getenv("HOME"),projectname)
      },
      roraima.local={
         gis.data <- sprintf("%s/gisdata/",Sys.getenv("HOME"))
         work.dir <- sprintf("%s/tmp/%s",Sys.getenv("HOME"),projectname)
        },
      {
         if (file.exists("/srv/scratch/cesdata")) {
            gis.data <- sprintf("/srv/scratch/cesdata/gisdata/")
            work.dir <- sprintf("/srv/scratch/cesdata/output/%s/",projectname)
         } else {
            stop("Can't figure out where I am, please customize `project-env.R` script\n")
         }
      })
}
if (!file.exists(work.dir)) {
  system(sprintf("mkdir -p %s",work.dir))
}
setwd(work.dir)

if (file.exists("~/.database.ini")) {
   tmp <-     system("grep -A4 psqlaws $HOME/.database.ini", intern = TRUE)[-1]
   get.dbinfo <- gsub("[a-z]+=", "", tmp)
   names(get.dbinfo) <- gsub("([a-z]+)=.*", "\\1",tmp)
   tmp <-     system("grep -A4 IUCNdb $HOME/.database.ini", intern = TRUE)[-1]
   rle.dbinfo <- gsub("[a-z]+=", "", tmp)
   names(rle.dbinfo) <- gsub("([a-z]+)=.*", "\\1", tmp)
   rm(tmp)
}

## OSF personal access token
# we can put this in .Renviron
# Or we can ...
#if (file.exists("~/.secrets/osf")) {
#  osf.token <- readLines("~/.secrets/osf")
#}
## OSF project code
Sys.setenv("OSF_PROJECT" = "wme3b")