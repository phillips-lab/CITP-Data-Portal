
library(data.table)
library(DBI)
library(jsonlite)
library(openxlsx)
library(PKI)
library(RPostgres)
library(tidyverse)

dir.create("data_tables", recursive=TRUE, showWarnings=FALSE)
dir.create("downloads/by_strain", recursive=TRUE, showWarnings=FALSE)
dir.create("downloads/by_comp", recursive=TRUE, showWarnings=FALSE)
dir.create("downloads/by_dataset", recursive=TRUE, showWarnings=FALSE)

DB_HOST <- Sys.getenv("DB_HOST")
DB_NAME <- "citp-published"
DB_PORT <- 5432
DB_USER <- Sys.getenv("DB_USER")
DB_PWD <- Sys.getenv("DB_PWD")



# reference tables

con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
all.comps <- dbGetQuery(con, "SELECT * FROM all_compounds_table JOIN compound_metadata_table ON all_compounds_table.comp_id=compound_metadata_table.comp_id WHERE active_comp = TRUE")
dbDisconnect(con)

con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
all.pubs <- dbGetQuery(con, "SELECT * FROM manuscript_table")
dbDisconnect(con)



# ================================================================================
# DATASET DOWNLOAD FILES

con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
dset <- dbGetQuery(con, "SELECT dataset_name FROM dataset_table")
dbDisconnect(con)

dsets <- dset$dataset_name

con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
xdset <- dbGetQuery(con, "SELECT * FROM xdatasets")
dbDisconnect(con)

all.dsets <- data.frame()

# qery the data
for(i in 1:length(dsets)) {
  
  xdset.s <- subset(xdset, dataset_name==dsets[i])
  xdset.exp <- paste(unique(xdset.s$experiment_id), collapse = ",")
  
  if(length(unique(xdset.s$experiment_id))>0) {
    
    con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
    dat <- dbGetQuery(con, paste0('SELECT t1.experiment_name AS "Experiment", t1.indiv_death as "Dead", t1.indiv_censor AS "Censor", t1.death_age AS "DeathAge", t2.death_age AS "DeathNoCen", t1.observation_date AS "ObsDate", t1.lost || \' lost, \' || t1.bag || \' bag, \' || t1.extrusion || \' ext.\' as "ObsReason", t1.start_date AS "StartDate", t1.notes as "ObsNote", t1.plate_name AS "Plate", t1.device AS "Scanner", t1.plate_column_upper || \':\' ||t1.plate_row AS "Plate Location", t1.total_worms AS "Total Worms", t1.strain_name AS "Strain", t1.species_name AS "Species", t1.tech_id AS "Tech ID", t1.lab_name AS "Lab", t1.replicate_num AS "Rep", t1.comp_name AS "Compound", t1.concentration AS "Concentration", t1.concentration_units AS "Units", t1.exp_cond_name AS "Condition", t1.death_id, t1.observation_id, t1.plate_id, t1.experiment_id FROM (SELECT death_table.indiv_death, death_table.indiv_censor, observation_table.death_age, observation_table.notes, experiment_table.start_date, observation_table.observation_date, plate_table.plate_name, experiment_table.experiment_name, all_strains_table.strain_name, all_strains_table.species_name, plate_alm_supp_table.device, plate_alm_supp_table.plate_row, UPPER(plate_alm_supp_table.plate_column) AS "plate_column_upper", plate_alm_supp_table.total_worms, tech_table.tech_id, experiment_table.lab_name, experiment_table.experiment_type_name, xreps.replicate_num, xcomps.concentration, xcomps.concentration_units, experimental_conditions_table.exp_cond_name, all_compounds_table.comp_name, death_table.death_id, observation_table.observation_id, plate_table.plate_id, experiment_table.experiment_id, observation_table.lost, observation_table.bag, observation_table.extrusion FROM death_table, observation_table, (plate_table LEFT JOIN plate_alm_supp_table ON ((plate_table.plate_id = plate_alm_supp_table.plate_id))), xstrainthaws, experiment_table, worm_thaws_table, all_strains_table, tech_table, xreps, xcomps, experimental_conditions_table, all_compounds_table WHERE (death_table.observation_id = observation_table.observation_id AND observation_table.plate_id = plate_table.plate_id AND plate_table.xstrain_id = xstrainthaws.xstrain_id AND xstrainthaws.experiment_id = experiment_table.experiment_id AND experiment_table.experiment_id IN (',xdset.exp,') AND xstrainthaws.worm_thaw_id = worm_thaws_table.worm_thaw_id AND worm_thaws_table.strain_id = all_strains_table.strain_id AND plate_table.tech_initial = tech_table.tech_initial AND plate_table.xrep_id = xreps.xrep_id AND plate_table.exclude_from_export = FALSE AND xreps.xcomp_id = xcomps.xcomp_id AND xcomps.exp_cond_id = experimental_conditions_table.exp_cond_id AND xcomps.comp_id = all_compounds_table.comp_id) ORDER BY plate_table.plate_id, observation_table.observation_date) t1 LEFT JOIN (SELECT observation_table.death_age, death_table.indiv_death, death_table.death_id FROM observation_table, death_table WHERE (observation_table.observation_id = death_table.observation_id AND death_table.indiv_death = 1)) t2 ON t1.death_id = t2.death_id ORDER BY t1.experiment_id, t1.plate_id, t1.observation_id, t1.death_id;'))
    dbDisconnect(con)
    
    dat$doi[dat$experiment_id >= 30000000 & dat$experiment_id <= 30002000] <- "10.1038/ncomms14256"
    dat$doi[dat$experiment_id >= 30002020 & dat$experiment_id <= 30003300] <- "10.1111/acel.13488"
    
    write.csv(dat, file=paste0("downloads/by_dataset/citp_dataset_",dsets[i],".csv"), row.names=FALSE)
    
    wb <- createWorkbook()
    addWorksheet(wb=wb, sheetName="dataset")
    writeDataTable(wb=wb, sheet=1, x=dat)
    saveWorkbook(wb, paste0("downloads/by_dataset/citp_dataset_",dsets[i],".xlsx"), overwrite=TRUE)
    
    all.dsets <- rbind(all.dsets, dat)
    
  }
  
}



# ================================================================================
# INTERVENTION TABLE

interv <- unique(all.dsets[c("Strain","Species","Compound","doi")])
interv <- subset(interv, !(Compound %in% c("CTRL_H2O","CTRL_DMSO")))
interv <- merge(interv, all.comps, by.x="Compound", by.y="comp_name")
interv$control_name[interv$control_name=="CTRL_H2O"] <- "H2O"
interv$control_name[interv$control_name=="CTRL_DMSO"] <- "DMSO"
interv <- merge(interv, all.pubs, by="doi")
interv$pub <- paste0(interv$author," (",interv$year,")")
interv <- interv[order(interv$year, interv$Compound, interv$Strain),]
interv <- interv[c("comp_display_name","comp_abbr","control_name","Strain","pub","doi","pubchem_id")]
colnames(interv)[4] <- "strain_name"

sink("data_tables/tmp.json")
cat(toJSON(interv, na="null"))
sink()
system(paste0("python3 -m json.tool data_tables/tmp.json > data_tables/intervention.json"))
unlink("data_tables/tmp.json")



# ================================================================================
# COMPOUND DOWNLOAD FILES

con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
comp <- dbGetQuery(con, "SELECT comp_id, comp_abbr FROM all_compounds_table WHERE active_comp = TRUE")
dbDisconnect(con)

for (i in 1:nrow(comp)) {
  
  # query the data
  con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
  dat <- dbGetQuery(con, paste0('SELECT t1.experiment_name AS "Experiment", t1.indiv_death as "Dead", t1.indiv_censor AS "Censor", t1.death_age AS "DeathAge", t2.death_age AS "DeathNoCen", t1.observation_date AS "ObsDate", t1.lost || \' lost, \' || t1.bag || \' bag, \' || t1.extrusion || \' ext.\' as "ObsReason", t1.start_date AS "StartDate", t1.notes as "ObsNote", t1.plate_name AS "Plate", t1.device AS "Scanner", t1.plate_column_upper || \':\' ||t1.plate_row AS "Plate Location", t1.total_worms AS "Total Worms", t1.strain_name AS "Strain", t1.species_name AS "Species", t1.tech_id AS "Tech ID", t1.lab_name AS "Lab", t1.replicate_num AS "Rep", t1.comp_name AS "Compound", t1.concentration AS "Concentration", t1.concentration_units AS "Units", t1.exp_cond_name AS "Condition", t1.death_id, t1.observation_id, t1.plate_id, t1.experiment_id FROM (SELECT death_table.indiv_death, death_table.indiv_censor, observation_table.death_age, observation_table.notes, experiment_table.start_date, observation_table.observation_date, plate_table.plate_name, experiment_table.experiment_name, all_strains_table.strain_name, all_strains_table.species_name, plate_alm_supp_table.device, plate_alm_supp_table.plate_row, UPPER(plate_alm_supp_table.plate_column) AS "plate_column_upper", plate_alm_supp_table.total_worms, tech_table.tech_id, experiment_table.lab_name, experiment_table.experiment_type_name, xreps.replicate_num, xcomps.concentration, xcomps.concentration_units, experimental_conditions_table.exp_cond_name, all_compounds_table.comp_name, death_table.death_id, observation_table.observation_id, plate_table.plate_id, experiment_table.experiment_id, observation_table.lost, observation_table.bag, observation_table.extrusion FROM death_table, observation_table, (plate_table LEFT JOIN plate_alm_supp_table ON ((plate_table.plate_id = plate_alm_supp_table.plate_id))), xstrainthaws, experiment_table, worm_thaws_table, all_strains_table, tech_table, xreps, xcomps, experimental_conditions_table, all_compounds_table WHERE (death_table.observation_id = observation_table.observation_id AND observation_table.plate_id = plate_table.plate_id AND plate_table.xstrain_id = xstrainthaws.xstrain_id AND xstrainthaws.experiment_id = experiment_table.experiment_id AND xcomps.comp_id = ',comp$comp_id[i],' AND xstrainthaws.worm_thaw_id = worm_thaws_table.worm_thaw_id AND worm_thaws_table.strain_id = all_strains_table.strain_id AND plate_table.tech_initial = tech_table.tech_initial AND plate_table.xrep_id = xreps.xrep_id AND plate_table.exclude_from_export = FALSE AND xreps.xcomp_id = xcomps.xcomp_id AND xcomps.exp_cond_id = experimental_conditions_table.exp_cond_id AND xcomps.comp_id = all_compounds_table.comp_id) ORDER BY plate_table.plate_id, observation_table.observation_date) t1 LEFT JOIN (SELECT observation_table.death_age, death_table.indiv_death, death_table.death_id FROM observation_table, death_table WHERE (observation_table.observation_id = death_table.observation_id AND death_table.indiv_death = 1)) t2 ON t1.death_id = t2.death_id ORDER BY t1.experiment_id, t1.plate_id, t1.observation_id, t1.death_id;'))
  dbDisconnect(con)
  
  # query the controls
  if(nrow(dat)>0) {
    
    con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
    dat.ctrl <- dbGetQuery(con, paste0('SELECT t1.experiment_name AS "Experiment", t1.indiv_death as "Dead", t1.indiv_censor AS "Censor", t1.death_age AS "DeathAge", t2.death_age AS "DeathNoCen", t1.observation_date AS "ObsDate", t1.lost || \' lost, \' || t1.bag || \' bag, \' || t1.extrusion || \' ext.\' as "ObsReason", t1.start_date AS "StartDate", t1.notes as "ObsNote", t1.plate_name AS "Plate", t1.device AS "Scanner", t1.plate_column_upper || \':\' ||t1.plate_row AS "Plate Location", t1.total_worms AS "Total Worms", t1.strain_name AS "Strain", t1.species_name AS "Species", t1.tech_id AS "Tech ID", t1.lab_name AS "Lab", t1.replicate_num AS "Rep", t1.comp_name AS "Compound", t1.concentration AS "Concentration", t1.concentration_units AS "Units", t1.exp_cond_name AS "Condition", t1.death_id, t1.observation_id, t1.plate_id, t1.experiment_id FROM (SELECT death_table.indiv_death, death_table.indiv_censor, observation_table.death_age, observation_table.notes, experiment_table.start_date, observation_table.observation_date, plate_table.plate_name, experiment_table.experiment_name, all_strains_table.strain_name, all_strains_table.species_name, plate_alm_supp_table.device, plate_alm_supp_table.plate_row, UPPER(plate_alm_supp_table.plate_column) AS "plate_column_upper", plate_alm_supp_table.total_worms, tech_table.tech_id, experiment_table.lab_name, experiment_table.experiment_type_name, xreps.replicate_num, xcomps.concentration, xcomps.concentration_units, experimental_conditions_table.exp_cond_name, all_compounds_table.comp_name, death_table.death_id, observation_table.observation_id, plate_table.plate_id, experiment_table.experiment_id, observation_table.lost, observation_table.bag, observation_table.extrusion FROM death_table, observation_table, (plate_table LEFT JOIN plate_alm_supp_table ON ((plate_table.plate_id = plate_alm_supp_table.plate_id))), xstrainthaws, experiment_table, worm_thaws_table, all_strains_table, tech_table, xreps, xcomps, experimental_conditions_table, all_compounds_table WHERE (death_table.observation_id = observation_table.observation_id AND observation_table.plate_id = plate_table.plate_id AND plate_table.xstrain_id = xstrainthaws.xstrain_id AND xstrainthaws.experiment_id = experiment_table.experiment_id AND xcomps.comp_id IN (1000, 1010) AND experiment_table.experiment_id IN (',paste(unique(dat$experiment_id), collapse = ","),') AND xstrainthaws.worm_thaw_id = worm_thaws_table.worm_thaw_id AND worm_thaws_table.strain_id = all_strains_table.strain_id AND plate_table.tech_initial = tech_table.tech_initial AND plate_table.xrep_id = xreps.xrep_id AND plate_table.exclude_from_export = FALSE AND xreps.xcomp_id = xcomps.xcomp_id AND xcomps.exp_cond_id = experimental_conditions_table.exp_cond_id AND xcomps.comp_id = all_compounds_table.comp_id) ORDER BY plate_table.plate_id, observation_table.observation_date) t1 LEFT JOIN (SELECT observation_table.death_age, death_table.indiv_death, death_table.death_id FROM observation_table, death_table WHERE (observation_table.observation_id = death_table.observation_id AND death_table.indiv_death = 1)) t2 ON t1.death_id = t2.death_id ORDER BY t1.experiment_id, t1.plate_id, t1.observation_id, t1.death_id;'))
    dbDisconnect(con)
    
    dat <- rbind(dat, dat.ctrl)
    
  }
  
  dat$doi[dat$experiment_id >= 30000000 & dat$experiment_id <= 30002000] <- "10.1038/ncomms14256"
  dat$doi[dat$experiment_id >= 30002020 & dat$experiment_id <= 30003300] <- "10.1111/acel.13488"
  
  write.csv(dat, file=paste0("downloads/by_comp/citp_compound_",comp$comp_abbr[i],".csv"), row.names=FALSE)
  
  wb <- createWorkbook()
  addWorksheet(wb=wb, sheetName="comp")
  writeDataTable(wb=wb, sheet=1, x=dat)
  saveWorkbook(wb, paste0("downloads/by_comp/citp_compound_",comp$comp_abbr[i],".xlsx"), overwrite=TRUE)
  
}



# ================================================================================
# STRAIN DOWNLOAD FILES

con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
strain <- dbGetQuery(con, "SELECT strain_id, strain_name FROM all_strains_table WHERE active_strain = TRUE")
dbDisconnect(con)

for (i in 1:nrow(strain)) {
  
  # query the data
  con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
  dat <- dbGetQuery(con, paste0('SELECT t1.experiment_name AS "Experiment", t1.indiv_death as "Dead", t1.indiv_censor AS "Censor", t1.death_age AS "DeathAge", t2.death_age AS "DeathNoCen", t1.observation_date AS "ObsDate", t1.lost || \' lost, \' || t1.bag || \' bag, \' || t1.extrusion || \' ext.\' as "ObsReason", t1.start_date AS "StartDate", t1.notes as "ObsNote", t1.plate_name AS "Plate", t1.device AS "Scanner", t1.plate_column_upper || \':\' ||t1.plate_row AS "Plate Location", t1.total_worms AS "Total Worms", t1.strain_name AS "Strain", t1.species_name AS "Species", t1.tech_id AS "Tech ID", t1.lab_name AS "Lab", t1.replicate_num AS "Rep", t1.comp_name AS "Compound", t1.concentration AS "Concentration", t1.concentration_units AS "Units", t1.exp_cond_name AS "Condition", t1.death_id, t1.observation_id, t1.plate_id, t1.experiment_id FROM (SELECT death_table.indiv_death, death_table.indiv_censor, observation_table.death_age, observation_table.notes, experiment_table.start_date, observation_table.observation_date, plate_table.plate_name, experiment_table.experiment_name, all_strains_table.strain_name, all_strains_table.species_name, plate_alm_supp_table.device, plate_alm_supp_table.plate_row, UPPER(plate_alm_supp_table.plate_column) AS "plate_column_upper", plate_alm_supp_table.total_worms, tech_table.tech_id, experiment_table.lab_name, experiment_table.experiment_type_name, xreps.replicate_num, xcomps.concentration, xcomps.concentration_units, experimental_conditions_table.exp_cond_name, all_compounds_table.comp_name, death_table.death_id, observation_table.observation_id, plate_table.plate_id, experiment_table.experiment_id, observation_table.lost, observation_table.bag, observation_table.extrusion FROM death_table, observation_table, (plate_table LEFT JOIN plate_alm_supp_table ON ((plate_table.plate_id = plate_alm_supp_table.plate_id))), xstrainthaws, experiment_table, worm_thaws_table, all_strains_table, tech_table, xreps, xcomps, experimental_conditions_table, all_compounds_table WHERE (death_table.observation_id = observation_table.observation_id AND observation_table.plate_id = plate_table.plate_id AND plate_table.xstrain_id = xstrainthaws.xstrain_id AND xstrainthaws.experiment_id = experiment_table.experiment_id AND worm_thaws_table.strain_id = ',strain$strain_id[i],' AND xstrainthaws.worm_thaw_id = worm_thaws_table.worm_thaw_id AND worm_thaws_table.strain_id = all_strains_table.strain_id AND plate_table.tech_initial = tech_table.tech_initial AND plate_table.xrep_id = xreps.xrep_id AND plate_table.exclude_from_export = FALSE AND xreps.xcomp_id = xcomps.xcomp_id AND xcomps.exp_cond_id = experimental_conditions_table.exp_cond_id AND xcomps.comp_id = all_compounds_table.comp_id) ORDER BY plate_table.plate_id, observation_table.observation_date) t1 LEFT JOIN (SELECT observation_table.death_age, death_table.indiv_death, death_table.death_id FROM observation_table, death_table WHERE (observation_table.observation_id = death_table.observation_id AND death_table.indiv_death = 1)) t2 ON t1.death_id = t2.death_id ORDER BY t1.experiment_id, t1.plate_id, t1.observation_id, t1.death_id;'))
  dbDisconnect(con)
  
  # query the controls
  if(nrow(dat)>0) {
    
    con <- dbConnect(Postgres(), host=DB_HOST, dbname=DB_NAME, port=DB_PORT, user=DB_USER, password=DB_PWD)
    dat.ctrl <- dbGetQuery(con, paste0('SELECT t1.experiment_name AS "Experiment", t1.indiv_death as "Dead", t1.indiv_censor AS "Censor", t1.death_age AS "DeathAge", t2.death_age AS "DeathNoCen", t1.observation_date AS "ObsDate", t1.lost || \' lost, \' || t1.bag || \' bag, \' || t1.extrusion || \' ext.\' as "ObsReason", t1.start_date AS "StartDate", t1.notes as "ObsNote", t1.plate_name AS "Plate", t1.device AS "Scanner", t1.plate_column_upper || \':\' ||t1.plate_row AS "Plate Location", t1.total_worms AS "Total Worms", t1.strain_name AS "Strain", t1.species_name AS "Species", t1.tech_id AS "Tech ID", t1.lab_name AS "Lab", t1.replicate_num AS "Rep", t1.comp_name AS "Compound", t1.concentration AS "Concentration", t1.concentration_units AS "Units", t1.exp_cond_name AS "Condition", t1.death_id, t1.observation_id, t1.plate_id, t1.experiment_id FROM (SELECT death_table.indiv_death, death_table.indiv_censor, observation_table.death_age, observation_table.notes, experiment_table.start_date, observation_table.observation_date, plate_table.plate_name, experiment_table.experiment_name, all_strains_table.strain_name, all_strains_table.species_name, plate_alm_supp_table.device, plate_alm_supp_table.plate_row, UPPER(plate_alm_supp_table.plate_column) AS "plate_column_upper", plate_alm_supp_table.total_worms, tech_table.tech_id, experiment_table.lab_name, experiment_table.experiment_type_name, xreps.replicate_num, xcomps.concentration, xcomps.concentration_units, experimental_conditions_table.exp_cond_name, all_compounds_table.comp_name, death_table.death_id, observation_table.observation_id, plate_table.plate_id, experiment_table.experiment_id, observation_table.lost, observation_table.bag, observation_table.extrusion FROM death_table, observation_table, (plate_table LEFT JOIN plate_alm_supp_table ON ((plate_table.plate_id = plate_alm_supp_table.plate_id))), xstrainthaws, experiment_table, worm_thaws_table, all_strains_table, tech_table, xreps, xcomps, experimental_conditions_table, all_compounds_table WHERE (death_table.observation_id = observation_table.observation_id AND observation_table.plate_id = plate_table.plate_id AND plate_table.xstrain_id = xstrainthaws.xstrain_id AND xstrainthaws.experiment_id = experiment_table.experiment_id AND xcomps.comp_id IN (1000, 1010) AND experiment_table.experiment_id IN (',paste(unique(dat$experiment_id), collapse = ","),') AND xstrainthaws.worm_thaw_id = worm_thaws_table.worm_thaw_id AND worm_thaws_table.strain_id = all_strains_table.strain_id AND plate_table.tech_initial = tech_table.tech_initial AND plate_table.xrep_id = xreps.xrep_id AND plate_table.exclude_from_export = FALSE AND xreps.xcomp_id = xcomps.xcomp_id AND xcomps.exp_cond_id = experimental_conditions_table.exp_cond_id AND xcomps.comp_id = all_compounds_table.comp_id) ORDER BY plate_table.plate_id, observation_table.observation_date) t1 LEFT JOIN (SELECT observation_table.death_age, death_table.indiv_death, death_table.death_id FROM observation_table, death_table WHERE (observation_table.observation_id = death_table.observation_id AND death_table.indiv_death = 1)) t2 ON t1.death_id = t2.death_id ORDER BY t1.experiment_id, t1.plate_id, t1.observation_id, t1.death_id;'))
    dbDisconnect(con)
    
    dat <- rbind(dat, dat.ctrl)
    
  }
  
  dat$doi[dat$experiment_id >= 30000000 & dat$experiment_id <= 30002000] <- "10.1038/ncomms14256"
  dat$doi[dat$experiment_id >= 30002020 & dat$experiment_id <= 30003300] <- "10.1111/acel.13488"
  
  write.csv(dat, file=paste0("downloads/by_strain/citp_strain_",strain$strain_name[i],".csv"), row.names=FALSE)
  
  wb <- createWorkbook()
  addWorksheet(wb=wb, sheetName="strain")
  writeDataTable(wb=wb, sheet=1, x=dat)
  saveWorkbook(wb, paste0("downloads/by_strain/citp_strain_",strain$strain_name[i],".xlsx"), overwrite=TRUE)
  
}
