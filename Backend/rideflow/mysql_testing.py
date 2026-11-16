"""Isolated MySQL tests. Never point this configuration at a production database."""
import os
from .testing import *
DATABASES = {'default': {
    'ENGINE': 'django.db.backends.mysql',
    'NAME': os.environ.get('MYSQL_TEST_DATABASE', 'trivia_test_base'),
    'USER': os.environ.get('MYSQL_TEST_USER', 'root'),
    'PASSWORD': os.environ.get('MYSQL_TEST_PASSWORD', ''),
    'HOST': os.environ.get('MYSQL_TEST_HOST', '/tmp/trivia-mysql.sock'),
    'OPTIONS': {'charset': 'utf8mb4', 'isolation_level': 'read committed',
                'init_command': "SET sql_mode='STRICT_TRANS_TABLES', default_storage_engine=INNODB"},
    'TEST': {'NAME': os.environ.get('MYSQL_TEST_NAME', 'test_trivia_isolated')},
}}
