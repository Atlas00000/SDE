# INF-2-002: Reproducible ORBVWAP AI replay environment (no apt-get — faster on Windows Docker)
FROM python:3.11-slim-bookworm

WORKDIR /orbvwap

COPY requirements-lock.txt pyproject.toml ./
COPY Diagnostics ./Diagnostics
COPY models ./models
COPY Include ./Include
COPY tests ./tests

RUN pip install --no-cache-dir --default-timeout=300 --retries=5 \
    -r requirements-lock.txt

ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/orbvwap/Diagnostics/ai

CMD ["python", "Diagnostics/ai/replay_all.py"]
