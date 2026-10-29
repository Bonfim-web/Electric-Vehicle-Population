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

Column-level classification (nature, structure, nulls, cardinality);
| Column | Declaration | Semantic | Evidence  | Percentual de nulos | Cardinalidade | Observation |
| --- | --- | --- | --- | --- | --- | --- |
| VIN(1-10) | text |  |  |  |  |  |
| county | text | **qualitativo nominal** | 300142 linhas; 15 nulos (0,005%); 254 distintos; nomes geograficos; cardinalidade media-baixa | 0.005 |  | 15 nulos (0,005%): praticamente completa; tratar com COALESCE(condado,'desconhecido') em agrupamentos; possivel falha na fonte. |
| city | text | **qualitativo nominal (identificador)** | 300142 linhas; 15 nulos (0.005%); 935 distintos; nomes geográficos; cardinalidade média (mais granular que condado); | 0.005 | 934 |  |
| state1 | text | qualitativo nominal | 300142 linhas; 0 nulos (0%); 51 distintos; nomes geográficos; cardinalidade baixa; | 0.000 | 51 | baixa cardinalidade,  verificar se são 51 cidades reais ou se há variações de grafia (ex.: "São Paulo" vs "Sao Paulo") |
| postal code | text | qualitativo  | 300142 linhas; 15 nulos (0,005%); 1198 distintos; código postal; alta cardinalidade em relação às demais colunas geográficas; não é único por linha | 0.005 | 1198 | Verificar nulos; |
| model year | text | quantitativo  | 300142 linhas; 0 nulos (0%); 23 distintos; ano do modelo; valores numéricos ordenáveis; uso em comparação, ordenação e agregação | 0.0000 | 23 |  (0 nulos); 23 distintos indica faixa curta de anos (ex.: 2000–2022); pode ser tratado como categórico ordinal em agrupamentos; verificar se há valores fora de faixa (ex.: 0, 9999, ano futuro) |
| make | text | qualitativo nominal | 300142 linhas; 0 nulos (0%); 51 distintos; fabricante; uso em comparação, ordenação; | 0.000 | 51 | verificar variações de grafia e padronizar se necessário |
| model | text | qualitativo nominal | 300142 linhas; 0 nulos (0%); 205 distintos; (código/nome de modelo); uso em GROUP BY e filtros, não em SUM/AV | 0.000 | 205 | verificar variações de grafia e padronizar se necessário |
| eletric vehicle type  | text | qualitativo nominal | 300142 linhas; 0 nulos (0%); 2 distintos; categoria de tipo de veículo elétrico; uso em GROUP BY e filtros | 0.000 | 2 | apenas 2 categorias (ex.: BEV/PHEV); cardinalidade mínima; |
| clean alternative fuel vehicle eligibility | text | qualitativo | 300142 linhas; 0 nulos (0%); 3 distintos; | 0.000 | 3 | verificar os 3 valores exatos e se há categoria "desconhecido/não elegível” |
| eletric range | text | quantitativo | 300142 linhas; ~36 nulos (0,012%); 117 distintos; autonomia elétrica em milhas; uso em AVG/MIN/MAX e comparações | 0.012 | 117 | Levemente esparsa (0,012%); valor 0 pode indicar ausência de informação (verificar); analisar por tipo de veículo; 117 distintos sugere valores arredondados/agrupados
 |
| legislative district | text | qualitativo | 300142 linhas; ~789 nulos (0,263%); 49 distintos; número do distrito legislativo; uso em GROUP BY e filtros, não em SUM/AVG | 0.263 | 49 | Levemente esparsa (0,263%); apesar de numérico, é código de distrito — não somar nem tirar média; cardinalidade baixa (49 distritos); tratar nulos com COALESCE ou excluir conforme a análise |
| dol vehicle ID | text | identificador único | 300142 linhas; 0 nulos (0%); cardinalidade = 300142 (igual ao número de linhas); identificador do veículo; único por registro | 0.000 | 300142 | Completa (0 nulos); **identificador único** — chave natural/candidata da tabela; não usar em GROUP BY nem em agregações; candidata a PRIMARY KEY ou UNIQUE; ideal para joins e deduplicação |
| vehicle location | text | semiestruturado | 300142 linhas; ~24 nulos (0,008%); 1197 distintos; formato `POINT(x y)` com par de coordenadas embutido; não é escalar, exige parser (ST_X/ST_Y) | 0.008 | 1197 | Levemente esparsa (0,008%); **contém dois quantitativos contínuos (longitude, latitude)** — extrair com `ST_X`/`ST_Y` antes de medir; usar PostGIS para distância/região; não usar AVG direto na coluna |
| eletric utility | text | qualitativo nominal multivalorado | 300142 linhas; ~15 nulos (0,005%); 76 distintos; texto com nome da concessionária + cidade/estado no mesmo campo (ex.: "City of Seattle - WA", "City of Tacoma - (WA)"); formato inconsistente exige parser | 0.005 | 76 | Levemente esparsa (0,005%); **multivalorado** — contém concessionária + cidade + estado; separar com `split_part`/regex antes de agrupar; padronizar grafia (WA vs (WA)) e considerar extrair colunas derivadas; tratar nulos com COALESCE se agrupar |
| 2020geoID | text | qualitativo nominal | 300142 linhas; ~15 nulos (0,005%); 2468 distintos; código do setor censitário (2020); numérico por fora, mas é código geográfico; uso em GROUP BY/joins, não em SUM/AV | 0.005 | 2468 | Levemente esparsa (0,005%); **não somar nem tirar média** — é código, não quantidade; não é único (2468 distintos para 300k linhas ≈ 122 por tract); bom para joins com dados do censo; cuidado com zeros à esquerda se for `text` |

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
