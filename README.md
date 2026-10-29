# Electric-Vehicle-Population
# Electric Vehicle Population — SQL Analysis

## About

This project explores the Electric Vehicle Population dataset to understand
how EV adoption is distributed across vehicle makes, electric vehicle types,
model years, and geography (city/county) in Washington State. The goal is to
map customer preference and regional concentration of electric vehicles, and
to practice end-to-end analytical SQL — from data profiling to window
functions and descriptive statistics.

The dataset is published by Data.gov (USA) and contains Battery Electric
Vehicles (BEVs) and Plug-in Hybrid Electric Vehicles (PHEVs) currently
registered through the Washington State Department of Licensing (DOL).

## Objective

This is a study project built to practice:
- Data profiling and semantic classification of columns
- Aggregations, conditional logic, subqueries and CTEs
- Window functions (ranking, top-N per group, share of total)
- Descriptive statistics (median, standard deviation, variance)

The analysis answers ten business questions organized by increasing
analytical complexity.

## About the Data

- **Source:** Data.gov — Electric Vehicle Population (Washington State DOL)
- **Rows:** 300,142
- **Columns:** 16
- **Original format:** CSV, imported as text to preserve leading zeros
  (e.g., postal codes and census tracts)
- **Data origin:** secondary (public dataset)
- **Grain:** one row per registered electric vehicle
- **Key:** `dol_vehicle_id` (unique per row)

Column-level classification (nature, structure, nulls, cardinality) is
documented in [`docs/catalogo_dados.md`](docs/catalogo_dados.md).

## Scope

**In scope:** descriptive analysis of fleet composition, geography,
range, and eligibility; rankings and comparisons across groups.

**Out of scope:** predictive modeling, statistical inference, and formal
spatial analysis (the `vehicle_location` POINT column was not extracted
for geo computations).

## Business Questions

The questions are organized in four levels of increasing complexity.

### Level 1 — Basic exploration
- Q1. How many vehicles are in the dataset, and what is the distribution
  by electric vehicle type? *(COUNT, GROUP BY, SUM() OVER())*
- Q2. How has the EV fleet evolved across model years?
  *(GROUP BY, ORDER BY)*
- Q3. Which vehicle makes have the most registered vehicles?
  *(GROUP BY, ORDER BY DESC, LIMIT)*

### Level 2 — Aggregations and comparisons
- Q4. Which cities and counties concentrate the largest EV fleet?
  *(GROUP BY, COUNT, ORDER BY)*
- Q5. Which electric vehicle type has the highest average electric range?
  *(AVG, type casting, GROUP BY)*
- Q6. Which makes are above or below the average number of vehicles per
  make? *(CTE + CASE WHEN + scalar subquery)*

### Level 3 — Analytical queries
- Q7. Which counties have more registered vehicles than the average per
  county? *(subquery / CTE)*

### Level 4 — Statistics and window functions
- Q8. What is the median electric range, and how do standard deviation and
  variance vary by electric vehicle type?
  *(PERCENTILE_CONT, STDDEV, VARIANCE)*
- Q9. How do counties rank by fleet size, and what is the practical
  difference between RANK() and DENSE_RANK() on ties?
  *(RANK, DENSE_RANK, ROW_NUMBER)*
- Q10. What are the top 3 most popular models for each vehicle make?
  *(ROW_NUMBER() OVER(PARTITION BY make) + rank filter)*

Each question is documented with its SQL in
[`sql/03_analises.sql`](sql/03_analises.sql) and its result in
[`resultados/`](resultados/).

## Approach Used

### Data preparation
- Imported the CSV as `text` to preserve leading zeros in codes
  (postal_code, census_tract).
- Profiled every column: row count, nulls, % nulls, cardinality, sample.
- Classified columns semantically (qualitative nominal, quantitative
  discrete/continuous, identifier, semi-structured).
- Converted only columns used in analysis (`electric_range::numeric`,
  `model_year::int`).

### SQL techniques
- Aggregation: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `GROUP BY`, `HAVING`
- Filtering and ordering: `WHERE`, `ORDER BY`, `LIMIT`
- Conditional logic: `CASE WHEN`
- Subqueries and CTEs: scalar subquery for averages, `WITH` for reusable steps
- Window functions:
  - `SUM() OVER()` for percentage of total
  - `ROW_NUMBER`, `RANK`, `DENSE_RANK` for rankings and tie handling
  - `PARTITION BY` for top-N per group and share within county
- Descriptive statistics: `PERCENTILE_CONT(0.5)` (median), `STDDEV`, `VARIANCE`
- String handling: `UPPER`, `TRIM` (make normalization)
- Type casting: `::numeric`, `::int` for safe aggregation

### Tooling
- PostgreSQL (local instance)
- Git for versioning queries and documentation

## Key Findings

> To be filled as the queries are completed. One bullet per answered
> question, with the query reference and a one-line interpretation.

## Limitations

- 15 nulls in `county` and `postal_code` (~0.005%) — negligible but noted.
- Single secondary source (Data.gov); no external validation.
- `vehicle_location` is a semi-structured POINT column and was not
  extracted for formal spatial analysis.
- Statistics are descriptive only (no hypothesis testing or inference).
- Vehicle registration data may lag behind actual sales/adoption.
