from decouple import config

from .base import *

DEBUG = False
ALLOWED_HOSTS = config("ALLOWED_HOSTS", default="").split(",")

CORS_ALLOWED_ORIGINS = config("CORS_ORIGINS", default="").split(",")

SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
