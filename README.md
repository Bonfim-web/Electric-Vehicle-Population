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

Column-level classification (nature, structure, nulls, cardinality);
## Data Catalog

Column-level classification for `ev_population_import` (300,142 rows, 16 columns).
Classification follows four axes: **nature** (qualitative / quantitative /
identifier), **structure** (structured / semi-structured), **origin**
(primary / secondary / tertiary), and **sparsity** (null ratio).

| Column | Declaration | Semantic | Evidence | % Nulls | Cardinality | Observation |
|---|---|---|---|---|---|---|
| VIN (1-10) | text | Identifier (vehicle prefix) | 300,142 rows; 0 nulls (0%); 300,142 distinct; first 10 chars of the VIN; 1:1 with rows | 0.000 | 300,142 | Complete; unique per row like `dol_vehicle_id`; use for joins/dedup; not for aggregation |
| county | text | Qualitative nominal | 300,142 rows; 15 nulls (0.005%); 254 distinct; geographic names; medium-low cardinality | 0.005 | 254 | Nearly complete; treat nulls with `COALESCE(county, 'unknown')` in groupings; possible source gap |
| city | text | Qualitative nominal | 300,142 rows; 15 nulls (0.005%); 935 distinct; geographic names; medium cardinality (more granular than county) | 0.005 | 935 | Nearly complete; more granular than `county`; check spelling variants before grouping |
| state1 | text | Qualitative nominal | 300,142 rows; 0 nulls (0%); 51 distinct; state abbreviations; low cardinality | 0.000 | 51 | Complete; low cardinality; verify whether all 51 are valid state codes or include variants |
| postal_code | text | Identifier (geographic code) | 300,142 rows; 15 nulls (0.005%); 1,198 distinct; postal codes; high cardinality vs. other geo columns; not unique per row | 0.005 | 1,198 | Not a unique identifier (~250 rows per code); treat nulls if grouping; keep as text to preserve leading zeros |
| model_year | text | Quantitative discrete (ordinal) | 300,142 rows; 0 nulls (0%); 23 distinct; model year; orderable numeric values | 0.000 | 23 | Complete; 23 distinct suggests a short range (e.g., 2000–2022); check for sentinels (0, 9999, future years); can be treated as ordinal categorical |
| make | text | Qualitative nominal | 300,142 rows; 0 nulls (0%); 51 distinct; manufacturer name | 0.000 | 51 | Complete; normalize spelling/case (`UPPER(TRIM(make))`) before grouping |
| model | text | Qualitative nominal | 300,142 rows; 0 nulls (0%); 205 distinct; model name/code; alphanumeric | 0.000 | 205 | Complete; normalize spelling/case before grouping; alphanumeric values confirm non-quantitative nature |
| electric_vehicle_type | text | Qualitative nominal (binary) | 300,142 rows; 0 nulls (0%); 2 distinct; EV type category | 0.000 | 2 | Complete; only 2 categories (e.g., BEV/PHEV); minimal cardinality; not worth a standalone index |
| cafv_eligibility | text | Qualitative nominal | 300,142 rows; 0 nulls (0%); 3 distinct; clean alternative fuel vehicle eligibility | 0.000 | 3 | Complete; 3 categories; verify exact values and whether an "unknown/not eligible" category exists |
| electric_range | text | Quantitative continuous | 300,142 rows; ~36 nulls (0.012%); 117 distinct; electric range in miles | 0.012 | 117 | Slightly sparse (0.012%); value 0 may mean missing data (verify); 117 distinct suggests rounded/binned values; analyze by EV type |
| legislative_district | text | Identifier (district code) | 300,142 rows; ~789 nulls (0.263%); 49 distinct; legislative district number; code, not a quantity | 0.263 | 49 | Slightly sparse (0.263%); do not sum or average — it is a code; handle nulls with `COALESCE` or exclude per analysis |
| dol_vehicle_id | text | Unique identifier (key) | 300,142 rows; 0 nulls (0%); 300,142 distinct (= row count); vehicle identifier; 1:1 with rows | 0.000 | 300,142 | Complete; unique identifier — candidate PRIMARY KEY/UNIQUE; not for GROUP BY or aggregation; ideal for joins and dedup |
| vehicle_location | text (POINT) | Semi-structured (spatial) | 300,142 rows; ~24 nulls (0.008%); 1,197 distinct; `POINT(x y)` with embedded coordinate pair; not scalar; requires parser (`ST_X`/`ST_Y`) | 0.008 | 1,197 | Slightly sparse (0.008%); contains two continuous quantitative values (longitude, latitude); extract before measuring; use PostGIS for distance/region; avoid AVG on the column |
| electric_utility | text | Qualitative nominal (multivalued) | 300,142 rows; ~15 nulls (0.005%); 76 distinct; utility name + city/state in one field (e.g., "City of Seattle - WA", "City of Tacoma - (WA)"); inconsistent format | 0.005 | 76 | Slightly sparse (0.005%); multivalued — contains utility + city + state; parse with `split_part`/regex before grouping; normalize formatting (WA vs (WA)); consider derived columns |
| 2020geoID | text | Identifier (geographic code) | 300,142 rows; ~15 nulls (0.005%); 2,468 distinct; 2020 census tract ID; numeric-looking code, not a quantity | 0.005 | 2,468 | Slightly sparse (0.005%); do not sum or average — it is a code; not unique (~122 rows per tract); good for joins with census data; keep as text to preserve leading zeros |

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
