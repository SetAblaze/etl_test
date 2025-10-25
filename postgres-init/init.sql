CREATE DATABASE airflow;
CREATE DATABASE warehouse;

\connect warehouse
CREATE SCHEMA IF NOT EXISTS raw_data;
CREATE SCHEMA IF NOT EXISTS dbt_transformed;
