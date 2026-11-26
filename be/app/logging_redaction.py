import logging


class InvitationAccessLogFilter(logging.Filter):
    def filter(self, record):
        if isinstance(record.args, tuple) and len(record.args) >= 3:
            args = list(record.args)
            target = str(args[2])
            path, separator, _ = target.partition("?")
            if "/invitations/" in path or "/accept-invitation" in path:
                args[2] = path + ("?[REDACTED]" if separator else "")
                record.args = tuple(args)
        return True


# Format used by every ``databases`` backend for its DEBUG query log.
_DATABASES_QUERY_LOG_FORMAT = "Query: %s Args: %s"


class DatabaseQueryArgsRedactionFilter(logging.Filter):
    """Redact bound values from the ``databases`` library's DEBUG query log.

    With DEBUG logging enabled, ``databases`` logs every statement together
    with its bound values (invitation codes, emails, phone numbers, ...).
    The SQL text (placeholders only) is kept; the values are replaced.
    """

    def filter(self, record):
        if record.msg == _DATABASES_QUERY_LOG_FORMAT and isinstance(record.args, tuple) \
                and len(record.args) == 2:
            record.args = (record.args[0], "[REDACTED]")
        return True


# aiosqlite (SQLite driver) DEBUG logs: the repr of each call embeds the SQL
# and its bound values, e.g. "executing functools.partial(..., 'SELECT ...', ['code'])".
_AIOSQLITE_STATEMENT_LOG_FORMATS = frozenset({
    "executing %s",
    "operation %s completed",
    "returning exception %s",
})


class AiosqliteStatementRedactionFilter(logging.Filter):
    """Redact statement/argument reprs from aiosqlite's DEBUG logs."""

    def filter(self, record):
        if record.msg in _AIOSQLITE_STATEMENT_LOG_FORMATS:
            record.args = ("[REDACTED]",)
        return True


def _install(logger_name, filter_cls):
    logger = logging.getLogger(logger_name)
    if not any(isinstance(item, filter_cls) for item in logger.filters):
        logger.addFilter(filter_cls())


def configure_invitation_log_redaction():
    """Keep invitation codes and contact details out of logs.

    * uvicorn access log: query strings of invitation endpoints.
    * ``databases`` / ``aiosqlite`` DEBUG query logs: bound values.
    """
    _install('uvicorn.access', InvitationAccessLogFilter)
    _install('databases', DatabaseQueryArgsRedactionFilter)
    _install('aiosqlite', AiosqliteStatementRedactionFilter)

