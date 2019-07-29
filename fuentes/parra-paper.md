---
output: 
  pdf_document:
    # citation_package: natbib
    keep_tex: true
    fig_caption: true
    latex_engine: pdflatex
    template: svm-latex-ms.tex
    number_sections: true
    # template: arxiv.tex
title: | 
        | Reproducible script for the manuscript entitled
        | "Drainage rearrangement as a driver of geomorphological 
        | evolution during the Upper Pleistocene in a small tropical basin"
author:
- name: José Ramón Martínez Batlle
  affiliation: Universidad Autónoma de Santo Domingo
abstract: "The development of river networks in contexts where intense tectonic activity converges with great lithological variability, such as the Ocoa River Basin in the south of the Dominican Republic, usually hosts excellent examples of drainage rearrangement. This mechanism is defined as a transfer of part or all of a river's flow to another river. According to the process involved, drainage rearrangement may be classified in one of four categories: stream capture, river diversion, beheading and, more recently, karst piracy. The Parra River Basin (29.5 square kilometers), part of the Ocoa River Basin, features excellent examples of drainage rearrangement. The aim of this research was to detect and characterize drainage rearrangement evidence in three sub-basins of the Parra River Basin. Several geomorphological features, including striking differences in lithological types of alluvial deposits between terraces and stream beds, a sinkhole in a tributary stream, as well as high variability in basin morphometry computed using GIS techniques, suggest the development of karst piracy during the Upper Pleistocene in the Parra drainage network, along with other minor rearrangement forms. Karst piracy is an understudied model of drainage rearrangement worldwide, and so it is in the Dominican Republic. Hence, this paper contributes to a better understanding of the interaction between rivers and karst systems, at the same time providing new evidence for this little-known phenomenon."
keywords: "karst piracy, basin morphometry, GRASS GIS, Dominican Republic, Ocoa River Basin, Parra River Basin"
date: "`r format(Sys.time(), '%B %d, %Y')`"
geometry: margin=1in
fontfamily: mathpazo
fontsize: 11pt
# spacing: double
bibliography: bibliography.bib
csl: plos-one.csl
header-includes:
  \usepackage{pdflscape}
  \newcommand{\blandscape}{\begin{landscape}}
  \newcommand{\elandscape}{\end{landscape}}
# biblio-style: apsr
---

# Introduction

\ldots

# Materials and methods

\ldots

# Results

\ldots

# Discussion

# Supporting information

* Reproducible script of published paper:
http://www.ccsenet.org/journal/index.php/jgg/article/view/0/39703

### Set the working directory
-   Note: It is strongly recommended to reproduce the script in a clean R session

```{r wd}
wd <- tempdir()
setwd(wd)
getwd()
```

```{r setup, echo=FALSE}
knitr::opts_knit$set(root.dir = wd)
```


### Load packages

```{r loadpackages, results='hide', tidy=FALSE, warning=FALSE, message=FALSE}
library(raster)
library(rgdal)
library(gdalUtils)
library(sp) #Raster package should load this one, just to be sure
library(rgrass7)
library(ggplot2)
library(rasterVis)
library(grid)
library(scales)
library(viridis)
library(ggthemes)
library(ggsn)
library(colorspace)
library(tidyverse)
library(devtools) #For R packages, R scripts
library(sf)
library(mapview)
library(rgeos)
library(hydroTSM)
library(leaflet)
library(parallel)
library(tmap)
```

### Load personal scripts

```{r mononscripts, message=FALSE, warning=FALSE, tidy=FALSE}
scripts <- c(
  'plotgrass.R',
  'integerextent.R',
  'xyvector.R',
  'comparerasters.R',
  'lfp_network.R',
  'lfp_network_merge.R',
  'lfp_profiles_concavity.R',
  'lfp_profiles_concavity_for_any_network.R',
  'integral_hypsometric_curve.R',
  'pT.R',
  'tts_polar_plot.R',
  'transverse_topographic_symmetry.R',
  'sources_for_transverse_topographic_symmetry.R'
  )
ghsource <- paste('https://raw.githubusercontent.com/geofis/rgrass/master/')
invisible(map(
    paste0(ghsource, scripts),
    source_url)
)
```

### Create a cluster for parallel computing

```{r parallel, results='hide', warning=FALSE, message=FALSE, tidy=FALSE}
no_cores <- detectCores() - 1
paral <- TRUE #Runs only parallel computing code chunks, when available
```

### Set the GRASS GIS Environment and download the DEM

```{r wd.grassenv, results='hide', tidy=FALSE}
#GRASS GIS Environment
gisdbase <- 'GRASS'
loc <- initGRASS(gisBase = "/usr/lib/grass70/", #Locate your lib/grass instalation
                 home = wd, 
                 gisDbase = paste(wd, gisdbase, sep = '/'),
                 location = 'data',
                 mapset = "PERMANENT",
                 override = TRUE)

#Input DEM, clipped from SRTM source with the following commented lines
inputdem0 <- paste(wd, 'parradem0.tif', sep = '/')
# sourcedem <- '/home/jr/Documentos/grass/naranjal/n18_w071_1arc_v3.tif'
# gdal_translate(
#   src_dataset = sourcedem,
#   dst_dataset = paste0(wd, '/', inputdem0),
#   #Clips exactly Parra-Hondo-El Naranjal basins
#   projwin = c(-70.50, 18.582, -70.44, 18.495),
#   of = 'GTiff'
# )
download.file(
  url = 'https://geografiafisica.org/r/parrapaper/parradem.tif',
  destfile = inputdem0
)
```

### Browse the downloaded DEM info

```{r gdalinfo, warning=FALSE, tidy=FALSE}
GDALinfo(inputdem0)
```

### Resample the downloaded DEM

```{r gdalwarp, results='hide', tidy=FALSE}
inputdem1 <- paste(wd, 'parradem1.tif', sep = '/')
gdalwarp(
  srcfile = inputdem0,
  dstfile = inputdem1,
  r = "bilinear",
  t_srs = CRS("+init=epsg:32619"),
  overwrite = T
)
```

- Bilinear interpolation reduces strip-like artifacts from the source DEM.
- Likewise, gridded artifacts in QGIS are avoided if proper EPSG for the project is selected, normally the same one in which the data was provided. In order to avoid gridded artifact while displaying the UTM layer, set the project CRS to EPSG:4326, or choose bilinear zoom strategy in the Style tab of the layer properties.


### Test the resampled DEM

- This step is intended for calculating RMSE and testing differences in n random samples of z value between original and resampled DEM

```{r rmseandttest, tidy=FALSE}
inputdem0r <- raster(inputdem0)
inputdem1r <- raster(inputdem1)
#Parallel computing
system.time({
  cl <- makeCluster(no_cores)
  clusterExport(cl, c("inputdem0r", "inputdem1r", "comparerasters"))
  clusterEvalQ(cl, {
    library(raster)
  })
  compsr.pl <- parSapply(
    cl,
    sample(1:1000, 20),
    function(x) {
      comparerasters(
        r1 = inputdem0r,
        r2 = inputdem1r,
        n = 100,
        nsig = 0.05,
        seed = x
      )
    }
  )
  stopCluster(cl)}
)
compsr.pl
```


### Denoise the source DEM (SRTM 30 M void filled) [@nasa2014srtm1sdem, @sun2007fast]

- This step requires mdenoise. For more information:
    - [Mdenoise Page](https://personalpages.manchester.ac.uk/staff/neil.mitchell/mdenoise/)
    - [Github repo](https://github.com/exuberant/mdenoise/blob/master/README.md)


```{r transdenoisetrans, results='hide', tidy=FALSE}
rawsrcasc <- paste(wd, 'rawdem.asc', sep = '/')
denasc <- paste(wd,'denoiseddem.asc', sep = '/')
dentif <- paste(wd,'demdenoised.tif', sep = '/')
gdal_translate(
  src_dataset = inputdem1,
  dst_dataset = rawsrcasc,
  a_nodata = 0,
  of = 'AAIGrid'
)

system(
  paste(
    'mdenoise',
    '-i', rawsrcasc,
    '-n 5 -t 0.99',
    '-o', denasc
  )
)
gdal_translate(
  src_dataset = denasc,
  dst_dataset = dentif,
  a_nodata = -32767,#Prevent further issues with r.* addons
  of = 'GTiff'
)
rawextent <- extent(raster(dentif))
newextent <- intext(e = rawextent, r = 30, type = 'inner')
newextent
```

- NOTE. Since \texttt{r.basin} may throw an error \texttt{ERROR: Region resolution and raster map resolution differs}, it is recommended to set  integer numbers for both bbox and resolution before importing the DEM into GRASS GIS, which is accomplished in the next chunk.


```{r gdalwarptonewextent, results='hide', tidy=FALSE}
demtif <- paste(wd,'dem.tif', sep = '/')
gdalwarp(
  srcfile = dentif,
  dstfile = demtif,
  te = xyvector(newextent),
  tr = c(30,30),
  r = 'bilinear',
  overwrite = T
)
```


### Test the denoised DEM

- This step is intended for calculating RMSE and testing differences in n random samples of z value between the rawdem and the denoised DEM

```{r rmseandttest2, tidy=FALSE}
demtifr <- raster(demtif)
#Parallel computing
system.time({
  cl <- makeCluster(no_cores)
  clusterExport(cl, c("inputdem1r", "demtifr", "comparerasters"))
  clusterEvalQ(cl, {
    library(raster)
  })
  comprd.pl <- parSapply(
    cl,
    sample(1:1000, 20),
    function(x) {
      comparerasters(
        r1 = inputdem1r,
        r2 = demtifr,
        n = 100,
        nsig = 0.05,
        seed = x
      )
    }
  )
  stopCluster(cl)}
)
comprd.pl
```


### Importing DEM into GRASS and updating the GRASS region

```{r demintograss, results='hide', tidy=FALSE}
execGRASS(
  "g.proj",
  flags = c('t','c'),
  georef=demtif)
```
```{r demintograss2}
gmeta()
```
```{r demintograss3, results='hide', tidy=FALSE}
execGRASS(
  "r.in.gdal",
  flags='overwrite',
  parameters=list(
    input=demtif,
    output="dem"
  )
)
#A "just in case" region update
execGRASS(
  "g.region",
  parameters=list(
    raster = "dem",
    align = "dem"
  )
)
```
```{r demintograss4}
gmeta()
```

```{r, results='show', tidy=FALSE}
execGRASS(
  'g.list',
  flags = 't',
  parameters = list(
    type = c('raster', 'vector')
  )
)
```


### Shaded relief, for visualization purposes only

```{r shadedrelief, results='hide', tidy=FALSE, fig.height=6}
execGRASS(
  "r.relief",
  flags='overwrite',
  parameters = list(
    input = "dem",
    output = "hillshade",
    altitude = 45,
    azimuth = 315)
)
execGRASS(
  "r.shade",
  flags='overwrite',
  parameters = list(
    shade = "hillshade",
    color = 'dem',
    output = "elevation_hillshade")
)
#Plot Grass layers with ggplot custom function plotgrass
plotgrass(
  gl = 'dem',
  scaledist = 2
)#default: cols = scale_fill_viridis()
plotgrass(
  gl = 'hillshade',
  cols = scale_fill_gradientn(colours = grey.colors(255)),
  scaledist = 2
)#default: scaledist = 4
plotgrass(
  gl = 'elevation_hillshade',
  cols = scale_fill_gradientn(colours = terrain_hcl(3)),
  scaledist = 2
)#default: scaledist = 4
```


### Sink removal

From GRASS GIS 7 Manual Page:
  
- \textbf{DESCRIPTION}
    - "\texttt{r.hydrodem} applies hydrological conditioning (sink removal) to a required input elevation map. If the conditioned elevation map is going to be used as input elevation for r.watershed, only small sinks should be removed and the amount of modifications restricted with the mod option. For other modules such as r.terraflow or third-party software, full sink removal is recommended."

    - Since the area of interest has few depressions, this addon was executed with default parameters, so minor corrections were performed. The accumulation raster, as well as the streams extracted, were inspected visually, but no hydrological issues were found.

```{r sinkremoval, results='hide', tidy=FALSE, fig.height=6}
execGRASS(
  "r.hydrodem",
  flags = c('overwrite'),
  parameters = list(
    input = 'dem',
    output = 'hydrodem'
  )
)
```

```{r, results='show', tidy=FALSE}
execGRASS(
  'g.list',
  flags = 't',
  parameters = list(
    type = c('raster', 'vector')
  )
)
```


### Flow accumulation, flow direction and stream extraction using \texttt{r.watershed}

- As stated by the GRASS GIS manual [webpage](https://grass.osgeo.org/documentation/manuals/), [\texttt{r.watershed}](https://grass.osgeo.org/grass76/manuals/r.watershed.html) calculates hydrological parameters.

```{r rwshed, results='hide', tidy=FALSE, fig.height=6}
#Using r.watershed
execGRASS(
  "r.watershed",
  flags = 'overwrite',
  parameters = list(
    elevation = "hydrodem",
    accumulation = "tmp-w-accum",
    drainage = "tmp-w-drainage-direction",
    stream = "tmp-w-stream",
    threshold = 11
    #Setting minimum arbitrary threshold
    #Several threshold will be assessed futherly
  )
)
```

```{r, results='show', tidy=FALSE}
execGRASS(
  'g.list',
  flags = 't',
  parameters = list(
    type = c('raster', 'vector')
  )
)
```


### The Parra River basin delineation.

- This step prevents the emergence of negative values in the accumulation map.
- Note: preliminary coordinates of the Parra River basin outlet were captured using QGIS

```{r parrabasindelineation, results='hide', tidy=FALSE}
execGRASS(
  "r.water.outlet",
  flags='overwrite',
  parameters = list(
    input = "tmp-w-drainage-direction",
    coordinates = c(341836,2051146),#Obtained using QGIS
    output = "parra-basin"
  )
)
sapply(
  c('normal','smoothed'),
  function(x){
    execGRASS(
      "r.to.vect",
      flags = if(x=='normal') 'overwrite' else c('overwrite','s'),
      parameters = list(
        input = "parra-basin",
        output = paste0("parra_basin_",x),
        type = 'area'
      )
    )
  }
)
```

```{r, results='show', tidy=FALSE}
execGRASS(
  'g.list',
  flags = 't',
  parameters = list(
    type = c('raster', 'vector')
  )
)
```


### Set up the mask and delete previous files

```{r parraregionremove, results='hide', tidy=FALSE}
execGRASS(
  "g.region",
  parameters=list(
    raster = "parra-basin",
    align = "parra-basin"
  )
)
execGRASS(
  "g.remove",
  flags = 'f',
  parameters = list(
    type = c('raster','vector'),
    pattern = 'tmp*'
  )
)
execGRASS(
  "r.mask",
  flags = c('verbose','overwrite'),
  parameters = list(
    raster = 'parra-basin'
  )
)
```

```{r, results='show', tidy=FALSE}
execGRASS(
  'g.list',
  flags = 't',
  parameters = list(
    type = c('raster', 'vector')
  )
)
```


### Recalculate w-accum, now with the mask

```{r recalculatewaccum, results='hide', tidy=FALSE}
execGRASS(
  "r.watershed",
  flags = 'overwrite',
  parameters = list(
    elevation = "hydrodem",
    accumulation = "w-accum"
  )
)
```

```{r, results='show', tidy=FALSE}
execGRASS(
  'g.list',
  flags = 't',
  parameters = list(
    type = c('raster', 'vector')
  )
)
```


### Stream extraction and stream order using \texttt{r.stream}.

- The stream extraction was generated using parallel computing for several accumulation thresholds, which is defined as "number of cells" (each cell is sized 30x30 sq m). The different networks generated were visually evaluated in QGIS using a topographic map, a high resolution orthophoto (2 sq. m cell size) and the source SRTM DEM itself as backgrounds. Since the purpose of this research is to assess the drainage rearrengement of a small basin area, the threshold used to compute the network must be choosen carefully. In addition, the network generated must keep resemblance with the actual stream network while avoiding the generation of artifacts, specially those produced at the stream heads.

- Using 11 cells as the accumulation threshold (ca. 1 Ha) the module generated a densely but faulty network, which included artifacts at the stream heads. Furthermore, the network generated using accumulation tresholds of 33 cells and greater, showed scarce or absent stream artifacts, but the network looked too generalised for the purpose of this research. Finally, the network generated using 22 cells as a threshold (ca. 2 Ha), fitted well in the river valleys depicted in the orthophoto as well as in the topographic map.

```{r streamextract, results='hide', tidy=FALSE}
#Paralell computing r.stream.extract, MFD, several accumulation threshold values
system.time({
  cl <- makeCluster(no_cores)
  clusterEvalQ(cl, library(rgrass7))
  parSapply(
    cl,
    as.integer(seq(11,100, by=11)),
    #YES! as.integer, not a trivial step, because if those numbers are
    #treated as double, the GRASS GIS addon "r.stream.order" will fail
    #when calculating the Strahler order; subsequently this addon will
    #also fail when it calculates the Horton order, and so on.
    function(x){
      execGRASS(
        "r.stream.extract",
        flags = c('overwrite'),
        parameters = list(
          elevation = 'hydrodem',
          threshold = x,
          stream_raster = paste0('r-extract-stream-mfd-threshold-', x),
          stream_vector = paste0('r_extract_stream_mfd_threshold_', x),
          direction = paste0('r-extract-direction-mfd-threshold-', x)
        )
      )
    }
  )
  stopCluster(cl)}
)

threshold <- 22L
#Rename selected stream raster and vector maps
execGRASS(
  "g.rename",
  flags = 'overwrite',
  parameters = list(
    raster = paste0(
      "r-extract-stream-mfd-threshold-",
      threshold,
      ",r-extract-stream-final"
    ),
    vector = paste0(
      "r_extract_stream_mfd_threshold_",
      threshold,
      ",r_extract_stream_final"
    )
  )
)
execGRASS(
  "g.rename",
  parameters = list(
    raster = "r-extract-direction-mfd-threshold-22,r-extract-direction-final"
  )
)
#Remove unwanted maps
execGRASS(
  "g.remove",
  flags = c('f'),
  parameters = list(
    type = c('raster','vector'),
    pattern = '*extract*',
    exclude = '*final'
  )
)
```

```{r, results='show', tidy=FALSE}
execGRASS(
  'g.list',
  flags = 't',
  parameters = list(
    type = 'raster'
  )
)#"*-final" raster maps should appear in the list
```

```{r streamextract2, results='hide', tidy=FALSE}
execGRASS(
  "r.stream.order",
  flags = c('overwrite', 'verbose'),
  parameters = list(
    stream_rast = 'r-extract-stream-final',
    direction = 'r-extract-direction-final',
    elevation = 'hydrodem',
    accumulation = 'w-accum',
    stream_vect = 'order_all',
    strahler = 'order-strahler',
    horton = 'order-horton',
    shreve = 'order-shreve',
    hack = 'order-hack-gravelius',
    topo = 'order-topology'
  )
)
```

```{r, results='show', tidy=FALSE}
execGRASS(
  'g.list',
  flags = 't',
  parameters = list(
    type = c('raster', 'vector')
  )
)
```


### Subbasins delineation based on stream order

```{r subbasinsstreamorder, results='hide', tidy=FALSE, fig.height=11}
#Importing hydrodem into R, so zonal stats can be applied
#in order to find the outlets of the basins
hydrodem <- raster(readRAST('hydrodem'))
#Querying and generating an R object with the Strahler order (min and max)
rinfo.ordstra <- execGRASS(
  'r.info',
  flags = 'r',
  parameters = list(
    map = 'order-strahler'
  )
)
minmaxord <- as.numeric(
  stringr::str_extract_all(
    attributes(rinfo.ordstra)$resOut,
    "[0-9]+"
  )
)
minmaxord
###Delineate basins based on stream order (parallel)
system.time({
  sapply(
    min(minmaxord):max(minmaxord),
    function(x){
      execGRASS(
        "r.stream.basins",
        flags = c('overwrite', 'c'),
        parameters = list(
          direction = 'r-extract-direction-final',
          stream_rast = 'order-strahler',
          cats = as.character(x),
          basins = paste0('r-stream-basins-',x)
        )
      )
    }
  )
  coordoutletsord <- sapply(
    min(minmaxord):max(minmaxord),
    function(x){
      basinsr <- raster(readRAST(paste0('r-stream-basins-',x)))
      basinscat <- unique(na.omit(basinsr[]))
      names(basinscat) <- paste0(
        'Strahler order ',
        x,
        ', basin # ',
        as.character(basinscat)
      )
      cl <- makeCluster(no_cores)
      clusterExport(cl, c("hydrodem"))
      clusterEvalQ(cl, {
        library(rgrass7)
        library(raster)
      })
      parSapply(
        cl,
        basinscat,
        function(y){
          mk <- basinsr
          mk[!mk==y] <- NA
          xyFromCell(
            hydrodem,
            which.min(
              mask(hydrodem, mk)
            )
          )
        },
        USE.NAMES = T,
        simplify = F
      )
    }
  )
  stopCluster(cl)}
)
#  user  system elapsed 
# 0.496   0.796  24.459
##Saving results
coordoutletsord <- lapply(
  coordoutletsord,
  plyr::ldply,
  data.frame,
  .id = 'cat')
coordoutletsord.sf <- do.call('rbind', coordoutletsord) %>% 
  mutate(index = gsub(' |#|,|strahler', '', tolower(cat))) %>% 
  st_as_sf(coords=c('x','y'), crs = 32619)
st_write(
  coordoutletsord.sf,
  dsn = paste0(wd, '/coordoutletsdord.gpkg'),
  layer = 'coordoutletsdord',
  driver = 'GPKG',
  delete_layer = TRUE
)
```


\pretolerance=10000

```{r subbasinsstreamorder2, results='hide', tidy=FALSE, fig.height=8}
#Plot subbasins
i <- NULL
for(i in min(minmaxord):max(minmaxord)){
    p <- plotgrass(
      paste0('r-stream-basins-',i), legpos = 'none', qual = T,
      scaledist = 2, cols = scale_discrete_manual(brewer.pal(8, "Pastel2")
      )
    )
    print(p)
}
```

\pretolerance=100


```{r subbasinsstreamorder3, echo = TRUE, results='show', tidy=FALSE, fig.height=8}
#Mapping all the outlets together
tmap_options(max.categories = 184)
tm_shape(coordoutletsord.sf) +
  tm_dots(col = 'index', size = 0.3, legend.show = F) +
  tm_text('index', size = 0.6, auto.placement = T) +
  tm_grid(n.x = 5, n.y = 10) +
  tm_scale_bar(position = c('right', 'TOP'), width = 0.3, size = 1) +
  tm_layout(inner.margins=c(0.1, 0.1, 0.1, 0.1))
```


### Morphometric characterization of subbasins by stream order using \texttt{r.basin}


```{r morphometryrbasinsorderoutputdir, eval=TRUE, results='hide', tidy=FALSE}
outputdir <- paste0(wd, '/outputs/subbasinsorder')
prefix <- 'rbasin_'
```

The code chunks from this point on may take a while to run, but should run faster in a dedicated machine with a high-performance processor and enough available RAM memory.


```{r morphometryrbasinsorder, eval=FALSE, results='hide', tidy=FALSE}
# WARNING:
# Before running this code chunk, keep in mind that it may take minutes,
# even hours, depending on the performance of the machine and the number of
# basins to be processed.
# The 184 basins of this example were processed in 78 minutes, on a machine
# with the following memory and processor type:
# Output from in bash:
# memory         8GiB Memoria de sistema
# processor      Intel(R) Core(TM) i7-3610QM CPU @ 2.30GHz

# Unfortunately, parallel processing was not an option, because r.basin
# updates the GRASS region at the beginning of each basin calculation
system.time(
  sapply(
    coordoutletsord.sf$index,
    function(x){
      execGRASS(
        "r.basin",
        flags = c('overwrite','c'),
        parameters = list(
          map = 'hydrodem',
          prefix = paste0(prefix, x),
          coordinates = as.integer(unlist(
            st_coordinates(coordoutletsord.sf[coordoutletsord.sf$index==x,])
            )
          )-1,
          #Two notes:
          #1) The value "-1" at the end of previous line prevent r.basin
          #from stopping. I know that this is related to
          #r.stream.snap or g.region.
          #More research must be done on the code
          #for finding a solution to the following error:
          #"An ERROR occurred running r.basin
          #Please check for error messages above
          #or try with another pairs of outlet coordinates"
          
          #2) There is an open issue (24/OCT/2018) related to r.width.funct
          #http://osgeo-org.1560.x6.nabble.com/r-basin-error-td5382675.html
          #To successfully run the r.basin script, the r.width.funct was
          #excluded from the script by commenting appropriate lines:
          #I commented the lines that calls r.width.funct
          #in the r.basin script, so lines 344-347 look like this. 
          #        grass.message( "------------------------------" ) 
          
          #        grass.run_command('r.width.funct', map = r_distance, 
          #                                  image = os.path.join(directory,prefix)) 
          threshold = threshold,
          dir = paste0(outputdir, '/', x)
        )
      )
      execGRASS(
        "g.remove",
        flags = 'f',
        parameters = list(
          type = c('raster','vector'),
          pattern = 'rbasin_*'
        )
      )
    }
  )
)
#     user   system  elapsed 
# 3823.448  968.764 4703.137 
```

Retrieving the morphometric parameters from the CSV files

```{r, results='show', tidy=FALSE}
#Identify and isolate subbasins for which r.basin did not generated a CSV file
params.filelist <- list.files(
  outputdir,
  recursive = T,
  full.names = T,
  pattern = 'rbasin.*parametersT'
)
totalbasins <- dir(outputdir, full.names = F)
params.filelist.names <- paste0(
  'order',
  gsub('^/.*/order|/rbasin.*$', '', params.filelist)
)
setdiff(totalbasins, params.filelist.names)
#Six subbasins, which are actually artifacts, were not adequately processed

#Generate a single table containing all the information from the CSVs
csvtables <- lapply(
  params.filelist,
  function(x){read.csv(x)}
)
names(csvtables) <- params.filelist.names
params <- plyr::ldply(csvtables, data.frame, .id = 'subbasin ID')
str(params)
saveRDS(params, paste0(wd, '/params.RDS'))
write.csv(params, paste0(wd, '/params.csv'), row.names = F)
```

Joining basins by order with morphometric parameters

```{r joiningbasinsparams, echo = TRUE, results='hide', tidy=FALSE, fig.height=7}
basoutparams <- coordoutletsord.sf %>%
  inner_join(params, by = c('index' = 'subbasin ID'))
basoutparams %>% st_write(
  dsn = paste0(wd, '/basoutparams.gpkg'),
  layer = 'basoutparams',
  driver = 'GPKG',
  delete_layer = TRUE
)

#Vectorize basins and export to GPKG
sapply(
  min(minmaxord):max(minmaxord),
  function(x){
    execGRASS(
      "r.to.vect",
      flags='overwrite',
      parameters = list(
        input = paste0('r-stream-basins-',x),
        output = paste0('r_stream_basins_',x),
        type = 'area'
      )
    )
  }
)

rstrbasinsl <- sapply(
  as.character(min(minmaxord):max(minmaxord)),
  function(x){
    readVECT(paste0('r_stream_basins_',x)) %>% st_as_sf() %>% 
      group_by(value) %>% summarise() %>% st_cast()
    #sp object converted to sf and grouped further since either way
    #a single basin is splitted in multiple polygons
  },
  simplify = F
)
rstrbasins <- sf::st_as_sf(plyr::ldply(rstrbasinsl, .id = 'order')) %>% 
  mutate(index = paste0('order', order, 'basin', value))
# rstrbasins <- sf::st_as_sf(data.table::rbindlist(rstrbasinsl, idcol = 'order'))
rstrbasins %>% 
  st_write(
    dsn = paste0(wd, '/rstrbasins.gpkg'),
    layer = 'rstrbasins',
    driver = 'GPKG',
    delete_layer = TRUE
  )
basinsparams <- rstrbasins %>%
  inner_join(basoutparams %>% st_set_geometry(NULL), by = 'index')
basinsparams %>% st_write(
    dsn = paste0(wd, '/basinsparams.gpkg'),
    layer = 'basinsparams',
    driver = 'GPKG',
    delete_layer = TRUE
  )
#Mapping all the basins with outlets together
tmap_options(max.categories = 184)
tm_shape(basinsparams) +
  # tm_dots(col = 'index', size = 0.3, legend.show = F) +
  tm_text('index', size = 0.4, auto.placement = T) +
  tm_borders() +
  tm_grid(n.x = 5, n.y = 10) +
  tm_scale_bar(position = c('right', 'TOP'), width = 0.3, size = 1) +
  tm_layout(inner.margins=c(0.1, 0.1, 0.1, 0.1))
```

\newpage
\newgeometry{margin=0.1in, top=0.1in, headheight=0.0in, footskip=0.2in, includehead, includefoot}
\blandscape

```{r basinsparamsbystrahler, echo = TRUE, results='asis', warning=FALSE, tidy=TRUE, out.width='0.95\\paperheight', fig.width=11, fig.height=7, fig.align='center'}
minlengthforplots <- 15
#Parameters of order 1 subbasins
plot(
  basinsparams %>%
    filter(Max_order_Strahler==1) %>%
    rename_all(funs(gsub('_{1,}','\\.',.))) %>%
    rename_all(abbreviate, minlength=minlengthforplots),
  max.plot=38)
cat('\\pagebreak')
#Parameters of order 2 subbasins
plot(
  basinsparams %>%
    filter(Max_order_Strahler==2) %>% 
    rename_all(funs(gsub('_{1,}','\\.',.))) %>%
    rename_all(abbreviate, minlength=minlengthforplots),
  max.plot=38)
cat('\\pagebreak')
#Parameters of order 3 subbasins
plot(
  basinsparams %>%
    filter(Max_order_Strahler==3) %>% 
    rename_all(funs(gsub('_{1,}','\\.',.))) %>%
    rename_all(abbreviate, minlength=minlengthforplots),
  max.plot=38)
cat('\\pagebreak')
#Parameters of order 4 subbasins
plot(
  basinsparams %>%
    filter(Max_order_Strahler==4) %>% 
    rename_all(funs(gsub('_{1,}','\\.',.))) %>%
    rename_all(abbreviate, minlength=minlengthforplots),
  max.plot=38)
```
\elandscape
\restoregeometry

Smooth basin boundaries

```{r smooth, results='hide', warning=FALSE, tidy=FALSE}
sapply(
  min(minmaxord):max(minmaxord),
  function(x){
    execGRASS(
      "v.clean",
      flags = 'overwrite',
      parameters = list(
        tool='rmarea',
        threshold=10000,
        input=paste0('r_stream_basins_', x),
        output=paste0('tmp_r_stream_basins_clean',x),
        type='area'
      )
    )
    execGRASS(
      "v.type",
      flags = 'overwrite',
      parameters = list(
        input = paste0('tmp_r_stream_basins_clean',x),
        output = paste0('tmp_r_stream_basins_clean_lines',x),
        from_type='boundary',
        to_type='line'
      )
    )
    execGRASS(
      "v.generalize", 
      flags = 'overwrite',
      parameters = list(
        input=paste0('tmp_r_stream_basins_clean_lines',x),
        type="line",
        output=paste0("tmp_r_stream_basins_clean_lines_gen",x),
        threshold=1000,
        iterations=3,
        method="chaiken"
      )
    )
    execGRASS(
      "v.type", 
      flags = 'overwrite',
      parameters = list(
        input=paste0("tmp_r_stream_basins_clean_lines_gen",x),
        output=paste0("r_stream_basins_smoothed_",x),
        from_type='line',
        to_type='boundary'
      )
    )
    execGRASS(
      "g.remove",
      flags = 'f',
      parameters = list(
        type = 'vector',
        pattern = 'tmp_*'
      )
    )
  }
)
```

Joining the smoothed basins with the morphometric parameters table. Although there is a topology issue across basins from different stream orders, displaying basins of each max Strahler stream order may be visually better than their unsmoothed versions.

```{r joinsmoothedwithparameters, results='hide', warning=FALSE, tidy=FALSE}
rstrbasinsmthl <- sapply(
  as.character(min(minmaxord):max(minmaxord)),
  function(x){
    readVECT(paste0('r_stream_basins_smoothed_',x)) %>% st_as_sf() %>%
      group_by(value) %>% summarise() %>% st_cast()
    #sp object converted to sf and grouped further since either way
    #a single basin is splitted in multiple polygons
  },
  simplify = F
)
rstrbasinsmth <- sf::st_as_sf(plyr::ldply(rstrbasinsmthl, .id = 'order')) %>%
  mutate(index = paste0('order', order, 'basin', value))
rstrbasinsmth %>%
  st_write(
    dsn = paste0(wd, '/rstrbasinsmth.gpkg'),
    layer = 'rstrbasinsmth',
    driver = 'GPKG',
    delete_layer = TRUE
  )
basinsparamsmth <- rstrbasinsmth %>%
  inner_join(basoutparams %>% st_set_geometry(NULL), by = 'index')
basinsparamsmth %>% st_write(
    dsn = paste0(wd, '/basinsparamsmth.gpkg'),
    layer = 'basinsparamsmth',
    driver = 'GPKG',
    delete_layer = TRUE
  )
```

\newpage
\newgeometry{margin=0.1in, top=0.1in, headheight=0.0in, footskip=0.2in, includehead, includefoot}
\blandscape

```{r basinsparamsbystrahlersmooth, echo = TRUE, results='asis', warning=FALSE, tidy=TRUE, out.width='0.95\\paperheight', fig.width=11, fig.height=7, fig.align='center'}
#Parameters of order 1 subbasins
plot(
  basinsparamsmth %>%
    filter(Max_order_Strahler==1) %>% 
    rename_all(funs(gsub('_{1,}','\\.',.))) %>%
    rename_all(abbreviate, minlength=minlengthforplots),
    max.plot=38)
cat('\\pagebreak')
#Parameters of order 2 subbasins
plot(
  basinsparamsmth %>%
    filter(Max_order_Strahler==2) %>% 
    rename_all(funs(gsub('_{1,}','\\.',.))) %>%
    rename_all(abbreviate, minlength=minlengthforplots),
  max.plot=38)
cat('\\pagebreak')
#Parameters of order 3 subbasins
plot(
  basinsparamsmth %>%
    filter(Max_order_Strahler==3) %>% 
    rename_all(funs(gsub('_{1,}','\\.',.))) %>%
    rename_all(abbreviate, minlength=minlengthforplots),
  max.plot=38)
cat('\\pagebreak')
#Parameters of order 4 subbasins
plot(
  basinsparamsmth %>%
    filter(Max_order_Strahler==4) %>%
    rename_all(funs(gsub('_{1,}','\\.',.))) %>%
    rename_all(abbreviate, minlength=minlengthforplots),
  max.plot=38)
```

\elandscape
\restoregeometry


```{r, results='hide', warning=FALSE, message=FALSE}
file.remove(
  c(
    list.files(path = wd, pattern = '*.err$', full.names = T),
    list.files(path = wd, pattern = '*.out$', full.names = T),
    list.files(path = wd, pattern = '^files*', full.names = T)
  )
)
```


```{r, eval=FALSE, tidy=FALSE}
rmarkdown::render(
  paste0(
    '~/Documentos/proyecto_FONDOCyT/varios/pasar_a_drive/R_ensayos_historicos',
    '/subcuenca-el-naranjal/preproducibility/parra-paper.Rmd'
  )
)
```



# References
