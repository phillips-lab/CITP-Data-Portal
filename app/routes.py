
from app import app
from flask import render_template, redirect, request, url_for
import pandas as pd
import sqlalchemy as db
import urllib.parse

# Configuration for serving static files
app.static_url_path = '/static'

# Index
@app.route("/")
@app.route("/index")

def home():
    title = ""
    return render_template("index.html", title=title)

# FAQ
@app.route("/")
@app.route("/faq")
def faq():
    title = ""
    return render_template("faq.html", title=title)

# Volcano plot
@app.route("/volcano_plot/<strain>/<age>/<comp_abbrev>")
def volcano_plot(strain, age, comp_abbrev):
    title = "Volcano Plot - DE Genes"
    strain = strain
    age = age
    comp_abbrev = comp_abbrev
    return render_template("volcano_plot.html", title=title, strain=strain, age=age, comp_abbrev=comp_abbrev)

# Sample Summary
@app.route("/")
@app.route("/sample/summary")
def sample():
    title = ""
    return render_template("sample_summary.html", title=title)

@app.route("/sample/summary/data")
def sample_data():
    sql = "SELECT * FROM all_compounds_table WHERE comp_abbrev IN ('SULF', 'TRET') ORDER BY comp_name" 
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# Education Resources
@app.route("/")
@app.route("/education")
def education():
    title = ""
    return render_template("education.html", title=title)

# Healthspan
@app.route("/")
@app.route("/healthspan")
def healthspan():
    title = ""
    return render_template("healthspan.html", title=title)

# Dataframes
@app.route("/")
@app.route("/dataframes.html")
def dataframes():
    title = ""
    return render_template("dataframes.html", title=title)

# Publications
@app.route("/lifespan/pub")
def pub():
    title = "Published Datasets"
    return render_template("pub.html", title=title)


@app.route("/lifespan/pub/data")
def pub_data():
    sql = "SELECT * FROM pub_table ORDER BY year, author, dataset_name"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# Strains
@app.route("/lifespan/strain")
def strain():
    title = "Strains"
    return render_template("strain.html", title=title)

@app.route("/lifespan/strain/data")
def strain_data():
    sql = "SELECT * FROM all_strains_table ORDER BY strain_name"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# Strain Summary
@app.route("/lifespan/summary/strain/<strain>")
def summary_strain(strain):
    title = "Strain Summary: " + strain
    strain = strain
    return render_template("summary_strain.html", title=title, strain=strain)

@app.route("/lifespan/summary/strain/data/<strain>")
def strain_comp_data(strain):
    sql = "SELECT DISTINCT comp_name, 'Lucanic (2007)' AS publication FROM all_plates WHERE comp_name NOT IN ('CTRL_H2O', 'CTRL_DMSO') AND strain_name = '" + strain + "'"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# Compounds
@app.route("/lifespan/compound")
def compound():
    title = "Compounds"
    return render_template("compound.html", title=title)

@app.route("/lifespan/comp/data")
def comp_data():
    sql = "SELECT * FROM all_compounds_table ORDER BY comp_name"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# Compound Summary
@app.route("/lifespan/summary/comp/<comp>")
def summary_comp(comp):
    title = "Compound Summary: " + comp
    comp = comp
    return render_template("summary_comp.html", title=title, comp=comp)

@app.route("/lifespan/summary/comp/data/<comp>")
def summary_comp_data(comp):
    sql = "SELECT DISTINCT strain_name, species_name, 'Lucanic (2007)' AS publication FROM all_plates WHERE comp_name = '" + comp + "'"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# RNA-seq Samples
# Column names: Sample Name, Strain, Adult Age, Treatment, Replicate Number, Lab Name
@app.route("/lifespan/rnaseq/sample")
def rnaseq_sample():
    title = "RNA-seq Samples"
    return render_template("rnaseq_sample.html", title=title)

@app.route("/lifespan/rnaseq/sample/data")
def rnaseq_sample_data():
    sql = "SELECT sample_name, strain_name, adult_age, treatment, replicate_num, lab_name FROM rna_seq_sample_table"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# Experiments
@app.route("/lifespan/experiment")
def experiment():
    title = "Experiments"
    return render_template("experiment.html", title=title)

@app.route("/lifespan/exp/data")
def exp_data():
    sql = "SELECT * FROM all_experiments ORDER BY experiment_name"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# Plates
@app.route("/lifespan/plate")
def plate():
    title = "Plates"
    return render_template("plate.html", title=title)

@app.route("/lifespan/plate/data")
def plate_data():
    sql = "SELECT * FROM all_plates ORDER BY plate_name"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# Observations
@app.route("/lifespan/observation")
def observation():
    title = "Observations"
    return render_template("observation.html", title=title)

@app.route("/lifespan/observation/data")
def observation_data():
    sql = "SELECT * FROM all_observations ORDER BY observation_date"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# Deaths
@app.route("/lifespan/deaths")
def deaths():
    title = "Deaths"
    return render_template("deaths.html", title=title)

@app.route("/lifespan/deaths/data")
def deaths_data():
    sql = "SELECT * FROM all_worm_deaths ORDER BY death_id"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# RNA-seq Data
# Column names: WormBase ID, Gene Name, logFC, logCPM, P-Value, FDR
@app.route("/lifespan/rnaseq/de")
def rnaseq_de():
    title = "RNA-seq Differential Expression Results"
    return render_template("rnaseq_de.html", title=title)

@app.route("/lifespan/rnaseq/de/data")
def rnaseq_de_data():
    sql = "SELECT gene_wbid, gene_name, log_fc, log_cpm, p_value, fdr FROM rna_seq_de_table"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")

# RNA-seq Comparisons
# Column names: Strain, Adult Age, Treatment, Control, Data, Plot
@app.route("/lifespan/rnaseq/comparison")
def rnaseq_comparison():
    title = "RNA-seq Comparisons"
    return render_template("rnaseq_comparison.html", title=title)

@app.route("/lifespan/rnaseq/comparison/data")
def rnaseq_comparison_data():
    sql = "SELECT DISTINCT strain_name, adult_age, treatment, 'DMSO' AS control, 'Data' AS data_id, 'Plot' AS plot_id FROM rna_seq_sample_table WHERE treatment='SULF'"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")