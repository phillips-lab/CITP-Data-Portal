
from pathlib import Path
import os
import pandas as pd
import psycopg2
import sqlite3

DB_NAME = "citp-published"
DB_PORT = 5432
DB_FILE_PATH = "citp-data-portal.db"


conn = psycopg2.connect(
    dbname=DB_NAME, user=os.environ["DB_USER"], password=os.environ["DB_PWD"], host=os.environ["DB_HOST"], port=DB_PORT
)

c = conn.cursor()


# PUB DATASET
query = (
    "SELECT manuscript_table.manuscript_id, doi, author, journal, dataset_name, year FROM manuscript_table JOIN dataset_table ON manuscript_table.manuscript_id = dataset_table.manuscript_id"
)

c.execute(query)
res = c.fetchall()

pub_dataset_table = pd.DataFrame.from_records(
    res,
    columns=["manuscript_id", "doi", "author", "journal", "dataset_name", "year"],
)


# COMPOUND
query = (
    "SELECT all_compounds_table.comp_id, comp_name, comp_abbr, control_name, comp_display_name, pubchem_id FROM all_compounds_table JOIN compound_metadata_table ON all_compounds_table.comp_id = compound_metadata_table.comp_id WHERE active_comp = TRUE"
)

c.execute(query)
res = c.fetchall()

all_compounds_table = pd.DataFrame.from_records(
    res,
    columns=["comp_id", "comp_name", "comp_abbr", "control_name", "comp_display_name", "pubchem_id"],
)


# STRAIN
query = (
    "SELECT strain_id, strain_name, species_name FROM all_strains_table where active_strain = TRUE"
)
c.execute(query)
res = c.fetchall()
all_strains_table = pd.DataFrame.from_records(
    res,
    columns=["strain_id", "strain_name", "species_name"],
)


c.close()
conn.close()


# Create the SQLite database.

Path(DB_FILE_PATH).touch()

conn = sqlite3.connect(DB_FILE_PATH)
c = conn.cursor()

all_compounds_table.to_sql(
    "all_compounds_table", conn, if_exists="replace", index=False
)

all_strains_table.to_sql(
    "all_strains_table", conn, if_exists="replace", index=False
)

pub_dataset_table.to_sql(
    "pub_dataset_table", conn, if_exists="replace", index=False
)

c.close()
conn.close()
