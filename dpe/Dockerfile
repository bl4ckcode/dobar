FROM python:3.11-slim

WORKDIR /app

COPY pyproject.toml ./
COPY dobar_payment ./dobar_payment

EXPOSE 8080

CMD ["uvicorn", "dobar_payment.api.app:create_app", "--factory", "--host", "0.0.0.0", "--port", "8080"]
