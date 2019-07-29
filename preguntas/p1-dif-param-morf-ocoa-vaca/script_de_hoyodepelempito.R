library(raster)
library(rgrass7)
library(rgdal)
library(sf)

getwd()
dem <- raster('../compartidos/n18_w071_1arc_v3.tif')

#Exploratorio
dem[]
length(dem[])
dem
max(dem[])
min(dem[])
summary(dem[])
dem[dem[]<=0]

#Cuencas
cuencas <- st_read('../compartidos/kml_la_vaca_ocoa.gpkg')

#crop
demcuencas <- crop(dem, cuencas)

#Removing dem
rm(dem)
