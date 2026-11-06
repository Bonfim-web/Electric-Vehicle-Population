# Electric Vehicle Population — SQL Analysis

## About

This project explores the Electric Vehicle Population dataset to understand
how EV adoption is distributed across vehicle makes, electric vehicle types,
model years, and geography (city/county) in Washington State. The goal is to practice end-to-end analytical SQL — from data profiling to window
functions and descriptive statistics.

The analysis answers ten business questions organized by increasing
analytical complexity, and documents every decision (data quality issues,
null handling, distribution shape) alongside the SQL.

## Objective

- Data profiling and semantic classification of columns
- Aggregations, conditional logic, subqueries and CTEs
- Window functions (ranking, top-N per group, share of total)
- Descriptive statistics (median, standard deviation, variance)

  ## Project Stage

  This is an **exploratory data analysis (EDA)** project — descriptive and
  diagnostic. It answers "what" and "how groups differ", not "what will happen".
  Predictive modeling, formal statistical inference, and dashboards are out of scope.

## About the Data

- **Source:** Data.gov — Electric Vehicle Population (Washington State DOL)
- **Rows:** 300,142
- **Columns:** 16
- **Original format:** CSV, imported as text to preserve leading zeros
  (e.g., postal codes and census tracts)
- **Data origin:** secondary (public dataset)
- **Grain:** one row per registered electric vehicle
- **Key:**  `dol_vehicle_id` (unique per row)

## Data Catalog

All 16 columns were profiled and classified across four axes: **nature**
(qualitative / quantitative / identifier), **structure** (structured /
semi-structured), **origin** (primary / secondary / tertiary), and
**sparsity** (null ratio).

Key observations:
- `dol_vehicle_id` and `VIN (1-10)` are unique identifiers (1:1 with rows).
- `vehicle_location` is a semi-structured POINT column (spatial).
- `electric_utility` is multivalued (utility + city + state in one field).
- `electric_range` uses 0 as a missing-value code for BEVs (see Q8).

Full classification: [`docs/data_catalog.md`](docs/data_catalog.md).

## Scope
**In scope:** descriptive analysis of fleet composition, geography,
range, and eligibility; rankings and comparisons across groups.

## Business Questions

The questions are organized in order of increasing complexity.

### 
- Q1. How many vehicles are in the dataset, and what is the distribution
  by electric vehicle type? *(COUNT, GROUP BY, SUM() OVER())*
  
- Q2. How has the EV fleet evolved across model years?
  *(COUNT, GROUP BY, ORDER BY)*
  
- Q3. Which vehicle makes have the most registered vehicles?
  *(GROUP BY, COUNT(*), window SUM() OVER(), ORDER BY DESC, ROUND, LIMIT)*
  
- Q4. Which cities and counties concentrate the largest EV fleet?
  *(GROUP BY, COUNT, SUM() OVER(), ORDER BY, LIMIT)*
  
- Q5. Which electric vehicle type has the highest average electric range?
  *(AVG, type casting, GROUP BY)*
  
- Q6. Which makes are above or below the average number of vehicles per
  make? *(CTE + CASE WHEN + scalar subquery)*
  
- Q7. Which counties have more registered vehicles than the average per
  county? *(subquery / CTE + WHERE)*
  
- Q8. What is the median electric range, and how do standard deviation and
  variance vary by electric vehicle type?
  *(PERCENTILE_CONT, STDDEV, VARIANCE, WHERE, GROUP BY)*
  
- Q9. How do counties rank by fleet size, and what is the practical
  difference between RANK() and DENSE_RANK() on ties?
  *(CTE, RANK, DENSE_RANK, OVER(ORDER BY)*
  
- Q10. What are the top 3 most popular models for each vehicle make?
  *(CTE, ROW_NUMBER() OVER(PARTITION BY make) + rank filter)*

Each question is documented with its SQL in
[sql/03_analises.sql](sql/03_analises.sql).


## Approach Used

### SQL techniques
- Aggregation: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `GROUP BY`
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
- **Geographic concentration:** the top 10 counties hold ~90.55% of the fleet —
  EV adoption is highly concentrated, not spread evenly.
- **Range by type (zeros excluded):** BEVs average 200.37 miles vs 32.28 for
  PHEVs. For BEVs, the median (215) is higher than the mean (200.37),
  indicating a left-skewed distribution; for PHEVs, median (32) and mean
  (32.28) are nearly equal, indicating a symmetric distribution.
- **Data quality (Q8):** 81.49% of BEVs (197,085 of 241,840) report
  `electric_range = 0`, which represents missing information rather than real
 autonomy; no PHEV has zero. These zeros were excluded from the range
 statistics (`WHERE electric_range > 0`). With zeros excluded, the BEV median
 rises from 0 to ~215 miles, and the standard deviation drops from 83 to ~71.90.
 PHEV statistics are unchanged (median 32, stddev 13), since PHEVs have no
 zeros. The 36 nulls (all PHEV) were also excluded by the aggregates.

## Limitations

- 15 nulls in `county` and `postal_code` (~0.005%) — negligible but noted.
- Single secondary source (Data.gov); no external validation.
- `vehicle_location` is a semi-structured POINT column and was not
  extracted for formal spatial analysis.
- Statistics are descriptive only (no hypothesis testing or inference).
- Vehicle registration data may lag behind actual sales/adoption.
