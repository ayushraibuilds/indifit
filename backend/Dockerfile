FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Audit §4.3: Single-worker enforcement guarantees shared memory for TTLCache and IP_REQUEST_LOGS
ENV WEB_CONCURRENCY=1
ENV PYTHONUNBUFFERED=1

# Expose port (Render/Fly.io default override via $PORT)
EXPOSE 8000

# Start command pinned to 1 worker
CMD uvicorn main:app --workers 1 --host 0.0.0.0 --port ${PORT:-8000}
