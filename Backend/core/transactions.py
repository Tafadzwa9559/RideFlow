"""Official MongoDB transactions, bounded retries and write-conflict guards.

Nested official atomic blocks have no savepoints. Retry only the outer command;
never retry an ambiguous commit by re-executing its body.
"""
import functools
import random
import time
from contextlib import ContextDecorator
from django.db import connections, DEFAULT_DB_ALIAS
from django_mongodb_backend import transaction as mongo_transaction
from pymongo.errors import PyMongoError, DuplicateKeyError
from rest_framework.exceptions import APIException


class TransactionConflict(APIException):
    status_code = 409
    default_code = 'transaction_conflict'
    default_detail = 'A concurrent update conflicted. Retry the same idempotent request.'


def has_label(exc, label):
    seen = set()
    while exc is not None and id(exc) not in seen:
        seen.add(id(exc))
        if getattr(exc, 'has_error_label', lambda value: False)(label):
            return True
        exc = exc.__cause__ or exc.__context__
    return False


def retryable(exc):
    if has_label(exc, 'TransientTransactionError'):
        return True
    while exc is not None:
        if isinstance(exc, DuplicateKeyError):
            return True
        exc = exc.__cause__
    return False


def retry(function):
    @functools.wraps(function)
    def command(*args, **kwargs):
        connection = connections[DEFAULT_DB_ALIAS]
        if connection.in_atomic_block_mongo:
            return function(*args, **kwargs)
        for attempt in range(8):
            try:
                return function(*args, **kwargs)
            except Exception as exc:
                if not retryable(exc):
                    raise
                if attempt == 7:
                    raise TransactionConflict() from exc
                time.sleep(min(.01 * 2**attempt, .2) + random.uniform(0, .01))
    return command


class Atomic(ContextDecorator):
    def __init__(self, using=None):
        self.using = using or DEFAULT_DB_ALIAS

    def __enter__(self):
        self.context = mongo_transaction.atomic(using=self.using)
        return self.context.__enter__()

    def __exit__(self, kind, value, traceback):
        for attempt in range(5):
            try:
                return self.context.__exit__(kind, value, traceback)
            except Exception as exc:
                if kind is not None or not has_label(exc, 'UnknownTransactionCommitResult'):
                    raise
                if attempt == 4:
                    # Do not rerun the body: the server may already have committed it.
                    connection = connections[self.using]
                    if connection.session:
                        connection.session.end_session()
                        connection.session = None
                    connection.run_on_commit = []
                    error = TransactionConflict('Commit acknowledgement is uncertain. Retrieve state before retrying.')
                    error.detail.code = 'commit_outcome_unknown'
                    raise error from exc
                time.sleep(.02 * (attempt + 1))

    def __call__(self, function):
        @functools.wraps(function)
        def inside(*args, **kwargs):
            with Atomic(self.using):
                return function(*args, **kwargs)
        return retry(inside)


def atomic(using=None):
    return Atomic()(using) if callable(using) else Atomic(using)


on_commit = mongo_transaction.on_commit


def guard(model, pk):
    """Write a shared document before reading state; conflicts abort stale snapshots."""
    connection = connections[DEFAULT_DB_ALIAS]
    if not connection.in_atomic_block_mongo:
        raise RuntimeError('A write guard requires an official MongoDB transaction.')
    label = model._meta.label_lower if hasattr(model, '_meta') else str(model)
    connection.get_collection('trivia_operation_fences').update_one(
        {'_id': f'{label}:{pk}'}, {'$inc': {'revision': 1}}, upsert=True, session=connection.session)
