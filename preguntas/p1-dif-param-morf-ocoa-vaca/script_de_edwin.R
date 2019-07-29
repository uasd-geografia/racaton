library(raster)
library(rgrass7)
library(rgdal)
library(sf)
getwd()     
raster("../compartidos/n18_w071_1arc_v3.tif")  
mde <- raster("../compartidos/n18_w071_1arc_v3.tif")  
mde
mde[]
length(mde)
length(mde)
min(mde[])
cuencas <- st_read("../compartidos/kml_la_vaca_ocoa.gpkg")
corte_cuenca <- crop(mde, cuencas)
?crop
plot(corte_cuenca)
rm(mde) 
