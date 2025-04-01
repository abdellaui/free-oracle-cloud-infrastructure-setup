# -*- coding: utf-8 -*-

import os

import dotenv
import pytz

dotenv.load_dotenv()

APP_SERVICE_NAME = "example-service"
TLD_HOSTNAME = os.getenv("TLD_HOSTNAME", "example.com")
USER_NAME = os.getenv("USER_NAME", "ubuntu")
HOME_PATH = os.getenv("HOME_PATH", f"/home/{USER_NAME}")
APP_FULL_PATH = os.getenv("APP_FULL_PATH", os.path.join(HOME_PATH, "app"))
APP_SRC_DIR = os.getenv("APP_SRC_DIR", "src")
APP_SRC_PATH = os.getenv("APP_SRC_PATH", os.path.join(APP_FULL_PATH, APP_SRC_DIR))
APP_TEMPLATES_PATH = os.getenv(
    "APP_TEMPLATES_PATH", os.path.join(APP_SRC_PATH, "templates")
)
TIMEZONE_NAME = os.getenv("APP_CUSTOM_TIMEZONE", "Europe/Istanbul")
TURKEY_TIMEZONE = pytz.timezone(TIMEZONE_NAME)
