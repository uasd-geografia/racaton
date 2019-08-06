#paquetes 
library(raster)
library(rgrass7)
library(rgdal)
library(sf)
#fijar el directorio de trabajo
getwd()
#importar y asignar ratser
raster("../compartidos/n18_w071_1arc_v3.tif")  
mde <- raster("../compartidos/n18_w071_1arc_v3.tif")  
mde
mde[]
#caracteristicas del raster
length(mde)
length(mde)
min(mde[])
max(mde[])
#importar y asignar capa vectorial 
cuencas <- st_read("../compartidos/kml_la_vaca_ocoa.gpkg")
#cortar area del raster con la capa vectorial
corte_cuenca <- crop(mde, cuencas)
?crop #ayuda
#plotear el raster
plot(corte_cuenca)
rm(mde) #eliminar el raster original de la data de trabajo
