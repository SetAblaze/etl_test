@echo off
    docker compose up -d postgres
    docker compose run --rm airflow-init
    docker compose up -d airflow-webserver airflow-scheduler
    echo Open http://localhost:8080  (admin/admin)
    pause
