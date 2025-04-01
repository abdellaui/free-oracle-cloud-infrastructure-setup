#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import flask
import waitress

from web.Parameters import (
    APP_ASSETS_PATH,
    APP_SERVICE_NAME,
    APP_TEMPLATES_PATH,
    TLD_HOSTNAME,
)

app = flask.Flask(
    __name__, static_folder=APP_ASSETS_PATH, template_folder=APP_TEMPLATES_PATH
)


@app.route("/landing/robots.txt", defaults={"prefix": ""})
@app.route("/status/robots.txt", defaults={"prefix": "status."})
async def robots(prefix):
    return flask.render_template(
        "robots.txt.template",
        host_url=f"https://{prefix}{TLD_HOSTNAME}/",
    )


@app.route("/landing/sitemap.xml", defaults={"prefix": ""})
@app.route("/status/sitemap.xml", defaults={"prefix": "status."})
async def sitemap(prefix):
    return flask.render_template(
        "sitemap.xml.template",
        app_service_name=APP_SERVICE_NAME,
        app_service_title=f"{APP_SERVICE_NAME} by {TLD_HOSTNAME}",
        host_url=f"https://{prefix}{TLD_HOSTNAME}/",
    )


@app.route("/status", defaults={"path": ""}, strict_slashes=False)
@app.route("/status/<path:path>")
async def status(path):
    force_cache = True

    return flask.render_template(
        "status.html.template",
        app_service_name=APP_SERVICE_NAME,
        app_service_title=f"STATUS of {APP_SERVICE_NAME} by {TLD_HOSTNAME}",
        tld_host=TLD_HOSTNAME,
        host_url=f"https://status.{TLD_HOSTNAME}/",
    )


@app.route("/landing", defaults={"path": ""}, strict_slashes=False)
@app.route("/landing/<path:path>")
async def landing(path):
    return flask.render_template(
        "landing.html.template",
        app_service_name=APP_SERVICE_NAME,
        app_service_title=f"{APP_SERVICE_NAME} by {TLD_HOSTNAME}",
        tld_host=TLD_HOSTNAME,
        host_url=f"https://{TLD_HOSTNAME}/",
    )


@app.route("/")
async def default_redirect():
    return flask.redirect("/status/")


if __name__ == "__main__":
    waitress.serve(app=app, host="127.0.0.1", port=9093)
