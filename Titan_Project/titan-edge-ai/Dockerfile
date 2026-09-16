FROM python:3.11-slim
WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir numpy scikit-learn joblib

# Copy model files and application
COPY model_weights.json .
COPY scaler_params.json .
COPY fraud_model.pkl .
COPY index.html .
COPY serve.py .

EXPOSE 8001

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8001/index.html')"

CMD ["python", "serve.py"]
