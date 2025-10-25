# Support Analytics — Airflow + dbt (Docker)

> Минимальный ELT-конвейер для аналитики службы поддержки: загрузка заявок, трансформации в dbt и оркестрация в Airflow. Результат — витрины для KPI, распределения по категориям и рейтинга специалистов.

---

## Содержание

- [Цель](#цель)
- [Вариант выполнения](#вариант-выполнения)
- [Архитектура решения](#архитектура-решения)
- [Данные](#данные)
- [Модели / витрины](#модели--витрины)
- [Структура репозитория](#структура-репозитория)
- [Быстрый запуск](#быстрый-запуск)
- [Проверка результата](#проверка-результата)
- [Скриншоты](#скриншоты)
- [Траблшутинг](#траблшутинг)
- [Выводы](#выводы)

---

## Цель

Построить минимальный ELT-конвейер для анализа обращений в поддержку на имитационном датасете: автоматически загрузить данные, преобразовать их в витрины и подтвердить качество тестами dbt.

---

## Вариант выполнения

**Вариант:** Docker.

**Почему так:**
- локальная среда без облачного аккаунта;
- быстрый старт через `docker compose`;
- удобно дебажить Airflow и dbt в одних контейнерах.

---

## Архитектура решения

```mermaid
flowchart LR
    A[CSV seed<br/>support_tickets.csv] -->|dbt seed| B[(Postgres<br/>schema: dbt_transformed_raw_data)]
    B -->|dbt run (views)| C[stg_support_tickets]
    C --> D[kpi_daily]
    C --> E[category_daily]
    C --> F[agent_ranking]

    subgraph Airflow DAG
    S[dbt_seed] --> R[dbt_run] --> T[dbt_test]
    end
```

- **Хранилище:** PostgreSQL (БД `warehouse`)
- **Схемы:**
  - `dbt_transformed_raw_data` — сырые таблицы/сиды
  - `dbt_transformed_dbt_transformed` — представления (витрины)

---

## Данные

Использован датасет **Bitext Sample Customer Service** (части training/validation/testing CSV).  
В работе задействованы тексты/интенты и, главным образом, колонка **`category`** — по ней строятся агрегаты.

---

## Модели / витрины

- `stg_support_tickets` — стейджинг: чистка/приведение типов
- `kpi_daily(date, tickets, avg_resolution_hours, avg_first_response_hours, avg_satisfaction, repeat_rate)`
- `category_daily(date, category, tickets)`
- `agent_ranking(agent_id, tickets, avg_resolution_hours, avg_satisfaction, repeat_rate, score)` — интегральная оценка по агентам  
  *(формула агрегации смотрите в `models/marts/agent_ranking.sql` проекта dbt)*

---

## Структура репозитория

```
.
├── docker-compose.yml
├── dags/
│   └── support_analytics_dag.py        # Airflow: dbt_seed → dbt_run → dbt_test
├── dbt/
│   └── support_analytics/
│       ├── dbt_project.yml
│       ├── models/
│       │   ├── staging/stg_support_tickets.sql
│       │   └── marts/
│       │       ├── kpi_daily.sql
│       │       ├── category_daily.sql
│       │       └── agent_ranking.sql
│       ├── seeds/support_tickets.csv   # объединённый seed
│       └── .dbt/profiles.yml           # профиль подключения к Postgres
├── postgres-init/                      # (если есть) инициализация БД
├── scripts/
│   ├── start.bat                       # опционально: запуск для Windows
│   └── stop.bat
└── screenshots/
    ├── airflow_dag_success.png         # граф DAG
    └── dbeaver_kpi_daily.png           # витрина в DBeaver/pgAdmin
```

> **Примечание:** каталоги `dbt/**/target`, `dbt/**/logs`, `dbt/**/dbt_packages` держите в `.gitignore`.

---

## Быстрый запуск

### Предварительно
1. Установите **Docker Desktop** (WSL2 включён).
2. Свободен порт **5432** (в compose проброшен `5432:5432` для `postgres`).

### Поднять инфраструктуру
```bash
docker compose down -v
docker compose up -d
```

### (Опционально) Проверка/установка `git` внутри Airflow

Если `dbt debug` ругается на отсутствие `git` (нужно для некоторых пакетов dbt):

```bash
docker compose exec --user root airflow-webserver  bash -lc "apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*"
docker compose exec --user root airflow-scheduler bash -lc "apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*"
```

### Прогнать dbt руками (быстрый sanity-check)
```bash
docker compose exec airflow-webserver bash -lc "cd /opt/airflow/dbt/support_analytics && dbt debug && dbt seed && dbt run && dbt test"
```

### Запустить DAG в Airflow
1. Откройте **http://localhost:8080** (логин/пароль: `admin/admin`).
2. Найдите `support_analytics_dbt`, включите и нажмите **Trigger DAG**.
3. Дождитесь зелёной цепочки **dbt_seed → dbt_run → dbt_test**.

---

## Проверка результата

### DBeaver / pgAdmin (Postgres)

Параметры подключения:
- **Host:** `localhost`
- **Port:** `5432`
- **Database:** `warehouse`
- **User:** `postgres`
- **Password:** `postgres`

Ищите витрины в схеме **`dbt_transformed_dbt_transformed`**.

### Пример запроса

```sql
-- работать в целевой схеме
SET search_path TO dbt_transformed_dbt_transformed;

-- последние 20 дней KPI
SELECT * FROM kpi_daily
ORDER BY date DESC
LIMIT 20;

-- распределение по категориям за апрель 2024
SELECT category, SUM(tickets) AS tickets_apr_2024
FROM category_daily
WHERE date >= DATE '2024-04-01' AND date < DATE '2024-05-01'
GROUP BY category
ORDER BY tickets_apr_2024 DESC;

-- топ-10 агентов по интегральному скору
SELECT * FROM agent_ranking
ORDER BY score DESC NULLS LAST
LIMIT 10;
```

## Выводы

Связка **Airflow + dbt** даёт чёткое разделение ролей:
- **Airflow** — оркестрация, расписания, зависимости, ретраи и мониторинг.
- **dbt** — декларативные SQL-модели, документация, тесты качества (например, `not_null`, `unique`) и аккуратная работа со схемами.

В проекте получены:
- ежедневные KPI (`kpi_daily`);
- распределение обращений по категориям (`category_daily`);
- рейтинг специалистов (`agent_ranking`).

**Плюсы Docker-варианта:** быстрый локальный старт, независимость от облака, простота отладки.  
**Минусы:** нет управляемых сервисов и автоскейлинга; доступность/бэкапы нужно проектировать самостоятельно.

