from decouple import config

from .base import *

DEBUG = False
ALLOWED_HOSTS = config("ALLOWED_HOSTS", default="").split(",")

CORS_ALLOWED_ORIGINS = config("CORS_ORIGINS", default="").split(",")
