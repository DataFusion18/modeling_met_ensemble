##' Download and convert single grid point NLDAS to CF single grid point from hydro1.sci.gsfc.nasa.gov using OPENDAP interface
##' @name download.NLDAS
##' @title download.NLDAS
##' @export
##' @param outfolder
##' @param start_date
##' @param end_date
##' @param site_id
##' @param lat
##' @param lon
##'
##' @author Christy Rollinson (with help from Ankur Desai)

download.NLDAS <- function(outfolder, start_date, end_date, site_id, lat.in, lon.in, overwrite=FALSE, verbose=FALSE, ...){  
  # require(PEcAn.utils)
  require(RCurl)
  require(lubridate)
  require(ncdf4)
  require(stringr)
  # require(abind)

  # Date stuff
  start_date <- as.POSIXlt(start_date, tz = "GMT")
  end_date <- as.POSIXlt(end_date, tz = "GMT")
  start_year <- year(start_date)
  end_year   <- year(end_date)
  outfolder = paste0(outfolder,"/", site_id)
  
  lat.in = as.numeric(lat.in)
  lon.in = as.numeric(lon.in)
  dap_base="http://hydro1.sci.gsfc.nasa.gov/thredds/dodsC/NLDAS_FORA0125_H.002"
  dir.create(outfolder, showWarnings=FALSE, recursive=TRUE)
  
  ylist <- seq(start_year,end_year,by=1)
  rows = length(ylist)
  results <- data.frame(file=character(rows), host=character(rows),
                        mimetype=character(rows), formatname=character(rows),
                        startdate=character(rows), enddate=character(rows),
                        dbfile.name = "NLDAS",
                        stringsAsFactors = FALSE
                        )
  
  var = data.frame(DAP.name = c("N2-m_above_ground_Temperature","LW_radiation_flux_downwards_surface","Pressure","SW_radiation_flux_downwards_surface","N10-m_above_ground_Zonal_wind_speed","N10-m_above_ground_Meridional_wind_speed","N2-m_above_ground_Specific_humidity","Precipitation_hourly_total"),
                   DAP.dim = c(2,1,1,1,2,2,2,1),
                   CF.name = c("air_temperature","surface_downwelling_longwave_flux_in_air","air_pressure","surface_downwelling_shortwave_flux_in_air","eastward_wind","northward_wind","specific_humidity","precipitation_flux"),
                   units = c('Kelvin',"W/m2","Pascal","W/m2","m/s","m/s","g/g","kg/m2/s") 
                   )
  time.stamps = seq(0000, 2300, by=100)
  for (i in 1:rows){
    year = ylist[i]    
    
    # figure out how many days we're working with
    if(rows>1 & !i==1 & !i==rows){ # If we have multiple years and we're not in the first or last year, we're taking a whole year
      nday  = ifelse(lubridate:: leap_year(year), 366, 365) # leap year or not; days per year
      days.use = 1:nday
    } else if(rows==1){
      # if we're working with only 1 year, lets only pull what we need to
      nday  = ifelse(lubridate:: leap_year(year), 366, 365) # leap year or not; days per year
      day1 <- yday(start_date)
      # Now we need to check whether we're ending on the right day
      day2 <- yday(end_date)
      days.use = day1:day2
      nday=length(days.use) # Update nday
    } else if(i==1) {
      # If this is the first of many years, we only need to worry about the start date
      nday  = ifelse(lubridate:: leap_year(year), 366, 365) # leap year or not; days per year
      day1 <- yday(start_date)
      days.use = day1:nday
      nday=length(days.use) # Update nday
    } else if(i==rows) {
      # If this is the last of many years, we only need to worry about the start date
      nday  = ifelse(lubridate:: leap_year(year), 366, 365) # leap year or not; days per year
      day2 <- yday(end_date)
      days.use = 1:day2
      nday=length(days.use) # Update nday
    }
    ntime = nday*24 # leap year or not;time slice (hourly)

    loc.file = file.path(outfolder,paste("NLDAS",year,"nc",sep="."))
    
    ## Create dimensions
    lat <- ncdim_def(name='latitude', units='degree_north', vals=lat.in, create_dimvar=TRUE)
    lon <- ncdim_def(name='longitude', units='degree_east', vals=lon.in, create_dimvar=TRUE)
    time <- ncdim_def(name='time', units="sec", vals=seq((min(days.use)+1-1/24)*24*360, (max(days.use)+1-1/24)*24*360, length.out=ntime), create_dimvar=TRUE, unlim=TRUE)
    dim=list(lat,lon,time)
    
    var.list = list()
    dat.list = list()

    # Defining our dimensions up front
    for(j in 1:nrow(var)){
      var.list[[j]] = ncvar_def(name=as.character(var$CF.name[j]), units=as.character(var$units[j]), dim=dim, missval=-999, verbose=verbose)
      dat.list[[j]] <- array(NA, dim=c(length(lat.in), length(lon.in), ntime)) # Go ahead and make the arrays
    }
    names(var.list) <- names(dat.list) <- var$CF.name

    ## get data off OpenDAP
    for(j in 1:length(days.use)){
      date.now <- as.Date(days.use[j], origin=as.Date(paste0(year-1,"-12-31")))
      mo.now <- str_pad(month(date.now), 2, pad="0")
      day.mo <- str_pad(day(date.now), 2, pad="0")
      doy <- str_pad(days.use[j], 3, pad="0")
      for(h in 1:length(time.stamps)){
        hr <- str_pad(time.stamps[h],4,pad="0")
        dap_file = paste0(dap_base, "/",year, "/", doy, "/","NLDAS_FORA0125_H.A",year,mo.now,day.mo, ".",hr, ".002.grb.ascii?")
        
        # Query lat/lon
        latlon <- getURL(paste0(dap_file,"lat[0:1:223],lon[0:1:463]"))
        lat.ind <- gregexpr("lat", latlon)
        lon.ind <- gregexpr("lon", latlon)
        lats <- as.vector(read.table(con <- textConnection(substr(latlon, lat.ind[[1]][3], lon.ind[[1]][3]-1)), sep=",", fileEncoding="\n", skip=1))
        lons <- as.vector(read.table(con <- textConnection(substr(latlon, lon.ind[[1]][3], nchar(latlon))), sep=",", fileEncoding="\n", skip=1))
        
        lat.use <- which(lats-0.125/2<=lat.in & lats+0.125/2>=lat.in)
        lon.use <- which(lons-0.125/2<=lon.in & lons+0.125/2>=lon.in)
        
        # Set up the query for all of the met variables
        dap_query=""
        for(v in 1:nrow(var)){
          time.string <- ""
          for(i in 1:var$DAP.dim[v]){
            time.string <- paste0(time.string,"[0:1:0]")
          }
          dap_query <- paste(dap_query, paste0(var$DAP.name[v], time.string, "[",lat.use,"][",lon.use,"]"), sep=",")  
        }
        dap_query=substr(dap_query,2,nchar(dap_query))
        
        start.time <- Sys.time()
        dap.out <- getURL(paste0(dap_file,dap_query))
        for (v in 1:nrow(var)) {
          var.now <- var$DAP.name[v]
          ind.1 <- gregexpr(paste(var.now,var.now, sep="."), dap.out)
          end.1 <- gregexpr(paste(var.now,"time", sep="."), dap.out)
          dat.list[[v]][,,j*24-24+h] <- read.delim(con <- textConnection(substr(dap.out, ind.1[[1]][1], end.1[[1]][2])), sep=",", fileEncoding="\n" )[1,1]
        } # end variable loop
      } # end hour
    } # end day
    ## change units of precip from kg/m2/hr to kg/m2/s 
    dat.list[["precipitation_flux"]] = dat.list[["precipitation_flux"]]/(60*60)
    
    ## put data in new file
    loc <- nc_create(filename=loc.file, vars=var.list, verbose=verbose)
    for(j in 1:nrow(var)){
      ncvar_put(nc=loc, varid=as.character(var$CF.name[j]), vals=dat.list[[j]])
    }
    nc_close(loc)
    
    results$file[i] <- loc.file
#     results$host[i] <- fqdn()
    results$startdate[i] <- paste0(year,"-01-01 00:00:00")
    results$enddate[i] <- paste0(year,"-12-31 23:59:59")
    results$mimetype[i] <- 'application/x-netcdf'
    results$formatname[i] <- 'CF Meteorology'
    
  }
  
  invisible(results)
}


