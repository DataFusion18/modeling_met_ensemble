##' Download and conver to CF CRUNCEP single grid point from MSTIMIP server using OPENDAP interface
##' @name download.CRUNCEP
##' @title download.CRUNCEP
##' @export
##' @param outfolder
##' @param start_date
##' @param end_date
##' @param lat
##' @param lon
##'
##' @author James Simkins, Mike Dietze
download.CRUNCEP <- function(outfolder, start_date, end_date, site_id, lat.in, lon.in, overwrite=FALSE, verbose=FALSE, ...){  
  # require(PEcAn.utils)
  require(lubridate)
  require(ncdf4)
  start_date <- as.POSIXlt(start_date, tz = "GMT")
  end_date <- as.POSIXlt(end_date, tz = "GMT")
  start_year <- year(start_date)
  end_year   <- year(end_date)
  # site_id = as.numeric(site_id)
  outfolder = paste0(outfolder,"/", site_id)

  lat.in = as.numeric(lat.in)
  lon.in = as.numeric(lon.in)
  lat_trunc = floor(2*(90-as.numeric(lat.in)))+1
  lon_trunc = floor(2*(as.numeric(lon.in)+180))+1
  dap_base ='http://thredds.daac.ornl.gov/thredds/dodsC/ornldaac/1220/mstmip_driver_global_hd_climate_'
    
  dir.create(outfolder, showWarnings=FALSE, recursive=TRUE)
  
  ylist <- seq(start_year,end_year,by=1)
  rows = length(ylist)
  results <- data.frame(file=character(rows), host=character(rows),
                        mimetype=character(rows), formatname=character(rows),
                        startdate=character(rows), enddate=character(rows),
                        dbfile.name = "CRUNCEP",
                        stringsAsFactors = FALSE)
  
  var = data.frame(DAP.name = c("tair","lwdown","press","swdown","uwind","vwind","qair","rain"),
                   CF.name = c("air_temperature","surface_downwelling_longwave_flux_in_air","air_pressure","surface_downwelling_shortwave_flux_in_air","eastward_wind","northward_wind","specific_humidity","precipitation_flux"),
                   units = c('Kelvin',"W/m2","Pascal","W/m2","m/s","m/s","g/g","kg/m2/s")
  )
  
  for (i in 1:rows){
    year = ylist[i]    
    # ntime = ifelse(year%%4 == 0,1463,1459)
    ntime = ifelse(lubridate:: leap_year(year), 366*4, 365*4) # leap year or not; days per year
    
    loc.file = file.path(outfolder,paste("CRUNCEP",year,"nc",sep="."))
    
    ## Create dimensions
    lat <- ncdim_def(name='latitude', units='degree_north', vals=lat.in, create_dimvar=TRUE)
    lon <- ncdim_def(name='longitude', units='degree_east', vals=lon.in, create_dimvar=TRUE)
    time <- ncdim_def(name='time', units="sec", vals=(1:ntime)*21600, create_dimvar=TRUE, unlim=TRUE)
    dim=list(lat,lon,time)
    
    var.list = list()
    dat.list = list()
    
    ## get data off OpenDAP
    for(j in 1:nrow(var)){
      
      dap_file = paste0(dap_base,var$DAP.name[j],"_",year,"_v1.nc4")
      dap = nc_open(dap_file)
      dat.list[[j]] = ncvar_get(dap,as.character(var$DAP.name[j]),c(lon_trunc,lat_trunc,1),c(1,1,ntime))
      var.list[[j]] = ncvar_def(name=as.character(var$CF.name[j]), units=as.character(var$units[j]), dim=dim, missval=-999, verbose=verbose)
      nc_close(dap)
      
    }
    ## change units of precip to kg/m2/s instead of 6 hour accumulated precip
    ## 1 g H2O = 1 g/cm3 
    ## 1 cm3 = 100^3 cm3/m3
    ## 1 kg H2O = 10^3 g/kg = 10^3 (g/kg) * 100^-3 (m3/cm3) = 0.01 m3/m2 = 0.001 m = 1 mm
    dat.list[[8]] = dat.list[[8]]/(60*60*6)
    
    
    ## put data in new file
    loc <- nc_create(filename=loc.file, vars=var.list, verbose=verbose)
    for(j in 1:nrow(var)){
      ncvar_put(nc=loc, varid=as.character(var$CF.name[j]), vals=dat.list[[j]])
    }
    nc_close(loc)
     
    results$file[i] <- loc.file
    # results$host[i] <- fqdn()
    results$startdate[i] <- paste0(year,"-01-01 00:00:00")
    results$enddate[i] <- paste0(year,"-12-31 23:59:59")
    results$mimetype[i] <- 'application/x-netcdf'
    results$formatname[i] <- 'CF Meteorology'
    
  }
  
  invisible(results)
}


