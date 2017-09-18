###############################################################################################
#Aaron Kamoske -- kamoskea@msu.edu
#02/15/2017
###############################################################################################
#THIS R SCRIPT WILL TAKE PREVIOUSLY DOWNLOADED SMAP PM H5 DATA,
#EXTRACT SOIL_MOISTURE, RETRIEVAL_QUAL_FLAG, AND SURFACE_FLAG RASTERS,
#MASK "FILL GAP" VALUES AND MODELED VALUES (BASED OFF OF RETRIEVAL_QUAL_FLAG
#AND SURFACE_FLAG BINARY VALUES), AND WRITE ALL PROCESSED RASTERS AS GEOTIFFS
#THE SMAPr PACKAGE PROCESSES MULTIPLE FILES AS A RASTERBRICK, THUS ALLOWING
#FOR EASY FILE MANIPULATION AND UNSTACKING AT THE END OR PROCESSING TO WRITE AS GEOTIFFs
###############################################################################################
#USEFUL DOCUMENTATION CAN BE FOUND HERE:
#https://github.com/earthlab/smapr
#http://nsidc.org/data/docs/daac/smap/sp_l3_smp/data-fields.html#Soil_Moisture_Retrieval_Data
#http://smap.jpl.nasa.gov/
###############################################################################################

library("smapr")
library("curl")
library("httr")
library("rappdirs")
library("raster")
library("rgdal")
library("rhdf5")
library("utils")
library("zoo")

setwd("Y:/shared_data/SMAP")

#list all downloaded h5 files
smap.files <- list.files("raw_data/reprocessed_data")

#process all the smap files and save them to appropriate directory
for (i in smap.files) {
  #have to force the smap files into the same input style that extract_smap needs as an input due to downloading changes
  
  #extract the file name with no extension and put the result into a data frame
  smap.file.name <- tools::file_path_sans_ext(i)
  smap.df <- as.data.frame(smap.file.name)
  #need to extract the date from the file name for our dataframe
  name <- strsplit(smap.file.name, "_")
  name <- unlist(name)
  date <- name[5]
  date <- paste0(substr(date, 1, 4), "-", substr(date, 5, 6), "-", substr(date, 7, 8))
  #populate the date frame
  smap.df$date <- date
  smap.df$local_dir <- "raw_data/reprocessed_data"
  names(smap.df)[names(smap.df) == "smap.file.name"] <- "name"
 
  #extract soil_moisture layer from hdf5 file and return it as a Raster object
  #NOTE: some files appear to already have "fill gap" values removed and some do not..
  #mask "fill gap" values (-9999) and plot raster
  print("EXTRACTING SOIL_MOISTURE RASTERS...")
  soilMoisture <- extract_smap(smap.df, name = 'Soil_Moisture_Retrieval_Data_PM/soil_moisture_pm')
  print("SOIL_MOISTURE RASTERS EXTRACTED!!!")
  
  print("MASKING FILL GAP VALUES...")
  soilMoisture[soilMoisture == -9999] <- NA
  print("FILL GAP VALUES MASKED!!!")
  
  #extract retrieval_qual_flag layer from hdf5 file and return it as a Raster object
  #mask all retrieval_qual_flag values that are > 0 (0 == pixels that are in "Retrieval Successful" category)
  #for documentation of retrieval_qual_flags error values see
  #http://nsidc.org/data/docs/daac/smap/sp_l3_smp/data-fields.html#retrieve
  print("EXTRACTING RETRIEVAL_QUAL_FLAG RASTERS...")
  qualFlag<- extract_smap(smap.df, name = 'Soil_Moisture_Retrieval_Data_PM/retrieval_qual_flag_pm')
  print("RETRIEVAL_QUAL_FLAG RASTERS EXTRACTED!!!")
  
  print("MASKING RETRIEVAL_QUAL_FLAG VALUES...")
  qualFlag[qualFlag > 0] <- NA
  print("RETRIEVAL_QUAL_FLAG VALUES MASKED!!!")
  
  #extract surface_flag layer from hdf5 file and return it as a Raster object
  #find frequency of surface_flag values to compare to surface_flag codes
  #mask all surface_flag values that are > 0 (pixels that did not fall into a surface_flag category)
  #plot raster
  #for documentation of surface_flag error values see
  #http://nsidc.org/data/docs/daac/smap/sp_l3_smp/data-fields.html#surf
  print("EXTRACTING SURFACE_FLAG RASTERS...")
  surfaceFlag <- extract_smap(smap.df, name = 'Soil_Moisture_Retrieval_Data_PM/surface_flag_pm')
  print("SURFACE_FLAG RASTERS EXTRACTED!!!")
  
  print("MASKING SURFACE_FLAG VALUES...")
  surfaceFlag[surfaceFlag > 0] <- NA
  print("SURFACE_FLAG VALUES MASKED!!!")
  
  #mask the surface_flag raster and the retrieval_qual_flag raster
  #so that only the overlapping pixels are returned
  #mask the soil_moisture raster (that has had fill gap values removed)
  #with the surface_flag and retrieval_qual_flag mask
  print("MASKING SURFACE_FLAG AND RETRIEVAL_QUAL_FLAG VALUES...")
  sfQf <- mask(surfaceFlag, qualFlag)
  print("SURFACE_FLAG AND RETRIEVAL_QUAL_FLAG VALUES MASKED!!!")
  
  print("MASKING SOIL_MOISTURE RASTER...")
  smRaster <- mask(soilMoisture, sfQf)
  print("SOIL_MOISTURE RASTER MASKED!!!")
  
  #create variables for output paths and names
  #write rasters as GeoTiffs
  outPath <- "Y:/shared_data/SMAP/clean_data/reprocessed_data/PM/"
  outName <- paste0(smap.file.name, "_SOIL_MOISTURE_PM")
  writeRaster(smRaster, filename = paste0(outPath, outName), format = "GTiff", overwrite = TRUE)
}


