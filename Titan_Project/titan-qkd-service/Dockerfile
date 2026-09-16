FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir flask cryptography

COPY qkd_engine.py .
COPY qkd_service.py .

EXPOSE 8100

CMD ["python", "qkd_service.py"]
