#Cargar paquetes
library(raster)
library(rgrass7)
library(rgdal)
library(sf)

#Fijar directorio de trabajo
getwd()

#Leer DEM
dem <- raster('../compartidos/n18_w071_1arc_v3.tif')

#Exploratorio
dem[]
length(dem[])
dem
max(dem[])
min(dem[])
summary(dem[])
dem[dem[]<=0]

#Delimitar extensión de ambas cuencas
cuencas <- st_read('../compartidos/kml_la_vaca_ocoa.gpkg')

#Recortar DEM
demcuencas <- crop(dem, cuencas)

#Eliminando el DEM de memoria
rm(dem)
