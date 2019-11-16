library(tidyverse)
library(foreign)
library(bigrquery)
library(jsonlite)
library(glue)
# aquí deben estar lor archivos descargados de INEGI
archivos <- list.files(path = "./datos_zip/", full.names = TRUE)

# descomprimir
walk(archivos, function(archivo){
  unzip(archivo, exdir = "./datos_unzip/", overwrite = TRUE)
})

# obtener nombres archivos con datos
archivos_dbf <- list.files(path = "./datos_unzip/", full.names = FALSE) %>% 
  keep( ~ str_detect(.x, "NACIM"))

# convertir a rds
archivos_dbf %>% walk(function(archivo){
  print(archivo)
  dat <- read.dbf(paste0("./datos_salida/", archivo))
  nombre <- str_split(archivo, "\\.")[[1]][1] %>% paste0(".csv")
  write_rds(dat, paste0("./datos_salida/", nombre))
})

archivos_rds <- list.files(path = "../natalidad/datos/", full.names = TRUE) %>% 
  keep( ~ str_detect(.x, "rds")) 
archivos_rds_2 <- archivos_rds %>% keep(~str_detect(.x, "NACIM99|NACIM[0-1]"))

# json schema
dat <- read_rds(archivos_rds_2[1])
nom_variables <- names(dat)
fields <- as_bq_fields(dat)
toJSON(bigrquery:::as_json(fields), pretty = TRUE, auto_unbox = TRUE)


# crear datos json 
archivos_rds_2[-1] %>% walk(function(archivo){
  tbl <- read_rds(archivo)
  num <- str_extract(archivo, "[0-9].")
  tbl %>% stream_out(
    con = file(glue("./json_data/nacimientos_{num}.json")), 
    null = c("list"),
    na = c("null")) 
})

# correr script para subir los archivos