FROM python:3.12.8-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*
COPY pyproject.toml README.md ./
COPY src ./src
RUN pip install --no-cache-dir '.[dev]'
COPY dbt ./dbt
COPY db ./db
COPY scripts ./scripts
CMD ["python", "-m", "fhir_omop.cli", "--help"]

