FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir torch numpy pandas flask requests

COPY fl_server.py .

EXPOSE 8098

CMD ["python", "fl_server.py"]
