"""Read-only source/rollback configuration. Existing SQL migration files are retained.

Run only the legacy application revision for a live SQL rollback; current models
use ObjectIds. This alias is intended for controlled raw read-only export.
"""
import os


def source_database():
    return {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': os.environ.get('MYSQL_DATABASE', os.environ.get('DB_NAME', 'trivia')),
        'USER': os.environ.get('MYSQL_USER', os.environ.get('DB_USER', 'trivia')),
        'PASSWORD': os.environ.get('MYSQL_PASSWORD', os.environ.get('DB_PASSWORD', '')),
        'HOST': os.environ.get('MYSQL_HOST', os.environ.get('DB_HOST', '127.0.0.1')),
        'PORT': os.environ.get('MYSQL_PORT', os.environ.get('DB_PORT', '3306')),
        'OPTIONS': {'charset': 'utf8mb4', 'init_command': "SET SESSION TRANSACTION READ ONLY"},
    }
