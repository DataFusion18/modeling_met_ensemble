# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: Compress new hourly ensemble members to get pushed to Cyverse
# Creator: Christy Rollinson
# Contact: crollinson@mortonarb.org
# -----------------------------------
# Description
# Compress hourly ensemble members for each site so they can get pushed to Cyverse
# -----------------------------------
# 
# -----------------------------------
# General Workflow Components
# -----------------------------------
# 0. Set up file structure, load packages, etc
# 1. 
# -----------------------------------
# rm(list=ls())
wd.base <- "/home/crollinson/met_ensemble"

site.name = "GLSP"
vers=".v1"
site.lat  = 45.54127
site.lon  = -95.5313

in.base = file.path(wd.base, "data/met_ensembles", paste0(site.name, vers), "1hr/ensembles/")
out.base =  file.path(wd.base, "data/met_ensembles", paste0(site.name, vers), "1hr/ensembles_compressed/") 

dir.create(out.base, recursive = T, showWarnings = F)

GCM.list <- dir(in.base)
for(GCM in GCM.list){
  dir.create(file.path(out.base, GCM), recursive = T, showWarnings = F)
  
  setwd(file.path(in.base, GCM))
  
  gcm.ens <- dir()
  pb <- txtProgressBar(min=0, max=length(gcm.ens), style=3)
  pb.ind=1
  for(ens in gcm.ens){
    system(paste0("tar -jcvf ", file.path(out.base, GCM, paste0(ens, ".tar.bz2 ")), ens), show.output.on.console = F)
  }
} 
