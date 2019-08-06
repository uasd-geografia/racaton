#Cargar paquetes
library(raster)
library(rgrass7)
library(rgdal)
library(sf)
library(gdalUtils)

#Mostrar directorio de trabajo
getwd()
#Si hiciera falta fijarlo, setwd('ruta')

#Leer DEM (mejor opción)
#Cargando directamente desde el repo
dem <- raster('fuentes/n18_w071_1arc_v3.tif')

#Desde carpeta "../compartidos/"
# dem <- raster('../compartidos/n18_w071_1arc_v3.tif')

#Exploratorio
dem[]
length(dem[])
dem
max(dem[])
min(dem[])
summary(dem[])
dem[dem[]<=0]

#Delimitar extensión de ambas cuencas
#Desde el repo
cuencas <- st_read('fuentes/edwin/kml_la_vaca_ocoa.gpkg')

#Desde carpeta "../compartidos/"
# cuencas <- st_read('../compartidos/kml_la_vaca_ocoa.gpkg')

#Recortar DEM
# demcuencas <- crop(dem, cuencas) #Comentado, por escasez de recursos, usar paquete gdalUtils

# #Eliminando el DEM de memoria
# rm(dem)

#Recortar DEM con gdalUtils, sin necesidad de importar a R
gdalwarp(
  srcfile = '/home/compartidos/n18_w071_1arc_v3.tif',
  dstfile = '/home/compartidos/n18_w071_1arc_v3_cuencas.tif',
  cutline = '/home/compartidos/kml_la_vaca_ocoa.kml',
  crop_to_cutline = T,
  overwrite = T)
demcuencas <- raster('home/compartidos/n18_w071_1arc_v3_cuencas.tif')
plot(demcuencas)
rm(demcuencas)

#Iniciar sesión de Grass desde R con rgrass7
