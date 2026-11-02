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


def configure_invitation_log_redaction():
    logger = logging.getLogger('uvicorn.access')
    if not any(isinstance(item, InvitationAccessLogFilter) for item in logger.filters):
        logger.addFilter(InvitationAccessLogFilter())
