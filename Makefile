.PHONY: up ingest dbt test down
up:
	docker compose up --build
ingest:
	docker compose run --rm pipeline sh -c 'psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -f /app/db/init/00_schemas.sql -f /app/db/init/01_terminology.sql && fhir-omop ingest /app/data/fhir'
dbt:
	docker compose run --rm pipeline sh -c 'psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -f /app/db/init/00_schemas.sql -f /app/db/init/01_terminology.sql && cd /app/dbt && dbt run --profiles-dir . && dbt test --profiles-dir .'
test:
	python -m pytest
down:
	docker compose down

