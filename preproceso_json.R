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
  nombre <- str_split(archivo, "\\.")[[1]][1] %>% paste0(".rds")
  write_rds(dat, paste0("./datos_salida/", nombre))
})

archivos_rds <- list.files(path = "./datos_salida/", full.names = TRUE) %>% 
  keep( ~ str_detect(.x, "rds")) 
#archivos_rds_2 <- archivos_rds %>% keep(~str_detect(.x, "NACIM99|NACIM[0-1]"))
#archivos_rds_3 <- archivos_rds %>% keep(function(x){!(x %in% archivos_rds_2)})

# json schema - usar el último año
dat <- read_rds(archivos_rds_2[18])
nom_variables <- names(dat)
fields <- as_bq_fields(dat)
toJSON(bigrquery:::as_json(fields), pretty = TRUE, auto_unbox = TRUE)


# crear datos json y corregir tipos
archivos_rds %>% walk(function(archivo){
  tbl <- read_rds(archivo)
  num <- str_extract(archivo, "[0-9].")
  # corregir errores
  if("LOCAL_RESI" %in% names(tbl)){
    tbl <- tbl %>% rename(LOC_RESID = LOCAL_RESI)
  }
  if("MES_NAC" %in% names(tbl)){
    tbl <- tbl %>% rename(MES_NACIM = MES_NAC)
  }
  # usar relleno como archivos más recientes
  tbl <- tbl %>% 
    mutate(ENT_REGIS = str_pad(ENT_REGIS, 2, pad = "0"),
           MUN_REGIS = str_pad(MUN_REGIS, 3, pad = "0"),
           ENT_RESID = str_pad(ENT_RESID, 2, pad = "0"),
           MUN_RESID = str_pad(MUN_RESID, 3, pad = "0"),
           ENT_OCURR = str_pad(ENT_OCURR, 2, pad = "0"),
           MUN_OCURR = str_pad(MUN_OCURR, 3, pad = "0")) %>% 
    mutate_at(vars(one_of("LOC_RESID", "LOC_REGIS", "LOC_OCURR")), str_pad, 4, pad = "0") %>%  
    mutate_at(vars(one_of("DIS_RE_OAX")), as.character)
  # arreglar años
  tbl <- tbl %>% 
    mutate(ANO_NAC = ifelse(ANO_NAC < 100, ANO_NAC + 1900, ANO_NAC),
           ANO_REG = ifelse(ANO_REG < 100, ANO_REG + 1900, ANO_REG))
  tbl %>% stream_out(
    con = file(glue("./json_data/nacimientos_{num}.json")), 
    null = c("list"),
    na = c("null")) 
})

# correr script para subir los archivos