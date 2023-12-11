
from app import app
from flask import render_template, redirect, request, url_for
import pandas as pd
import sqlalchemy as db
import urllib.parse

# Configuration for serving static files
app.static_url_path = '/static'


# Home Page
@app.route("/")
@app.route("/index")
def home():
    title = "CITP Data Portal"
    icon_size = 70
    return render_template("index.html", title=title, icon_size=icon_size)


# Published Datasets
@app.route("/lifespan/pub", defaults={"pub_id": ""})
@app.route("/lifespan/pub/<pub_id>")
def pub(pub_id):
    title = "Published Datasets"
    return render_template("pub.html", title=title, pub_id=pub_id)

@app.route("/lifespan/pub/data")
def pub_data():
    sql = "SELECT * FROM pub_dataset_table ORDER BY year, author, dataset_name"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")


# Intervention
@app.route("/lifespan/intervention", defaults={"comp": "", "strain": ""})
@app.route("/lifespan/intervention/comp/<comp>", defaults={"strain": ""})
@app.route("/lifespan/intervention/strain/<strain>", defaults={"comp": ""})
def intervention(comp, strain):
    title = "Interventions"
    return render_template("intervention.html", title=title, comp=comp, strain=strain)


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


# Strains
@app.route("/lifespan/strain")
def strain():
    title = "Worm Strains"
    return render_template("strain.html", title=title)

@app.route("/lifespan/strain/data")
def strain_data():
    sql = "SELECT * FROM all_strains_table ORDER BY strain_name"
    engine = db.create_engine("sqlite:///citp-data-portal.db")
    table = pd.read_sql(sql, engine)
    return table.reset_index().to_json(orient="records")
