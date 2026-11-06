-- coments
-- Q1:How many vehicles are in the dataset and what is the distribution by electric vehicle type?
-- Technique: COUNT, GROUP BY, SUM() OVER() para percentual
SELECT electric_vehicle_type as tipo_veiculo,
COUNT(electric_vehicle_type) as total_veiculos,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentual
FROM ev_population_import
GROUP BY electric_vehicle_type ;

--Q2: How has the EV fleet evolved across model years?
-- Technique:(COUNT, GROUP BY, ORDER BY)
--   length distribution: all 4 chars; no leading/trailing spaces
--   min/max: 1997 / 2023; no sentinels in top frequencies
--   sum of groups = 300,142 (matches table total); 0 null/empty groups
SELECT model_year,
COUNT(*) AS vehicles,
electric_vehicle_type
FROM ev_population_import
GROUP BY model_year, electric_vehicle_type
ORDER BY model_year ASC;


--Q3: Which vehicle makes have the most registered vehicles and how are they distributed?
-- Technique: GROUP BY, COUNT(*), window SUM() OVER() for share and cumulative share.
-- Validation: sum of groups = 300,142; make spelling verified (no variants).
SELECT make as manufacturer,
COUNT(make) as vehicles_count ,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as share_pct,
 ROUND(SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC) * 100.0
          / SUM(COUNT(*)) OVER (), 2) AS cumulative_pct
FROM ev_population_import
GROUP BY make
ORDER BY vehicles_count DESC
LIMIT 10;

--Q4:Which cities and counties concentrate the largest EV fleet?
-- Q4 uses separate rankings (GROUP BY city; GROUP BY county) to avoid ambiguity
SELECT city,
COUNT(*) as vehicles_count,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as share_pct,
	ROUND(SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC) * 100.0
/ SUM(COUNT(*)) OVER (), 2) AS cumulative_pct
FROM ev_population_import
GROUP BY city
ORDER BY vehicles_count DESC
LIMIT 10;

SELECT county,
COUNT(*) as vehicles_count,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as share_pct,
	ROUND(SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC) * 100.0
/ SUM(COUNT(*)) OVER (), 2) AS cumulative_pct
FROM ev_population_import
GROUP BY county
ORDER BY vehicles_count DESC
LIMIT 10;

--Q5:Which EV type has the highest average electric range?
--Technique:(AVG + cast + GROUP BY).
--36 nulls in electric_range, all PHEV (~0.012%); excluded by AVG; impact on PHEV mean is negligible given the small count."
--Results - BEV 37,08 > PHEV 32,28
SELECT electric_vehicle_type, COUNT(electric_vehicle_type) AS vehicles_count,
ROUND(AVG(electric_range::numeric), 2) AS average_range
FROM ev_population_import
WHERE electric_range::numeric > 0
GROUP BY electric_vehicle_type
ORDER BY average_range DESC
LIMIT 2;

--Q6: Which makes are above or below the average number of vehicles per make?
-- Technique: CTE (count per make) + scalar subquery (average) + CASE.
-- Note: average includes makes with 1 vehicle (skews threshold low).
-- Ordered by vehicle_count DESC to surface largest makes first.
WITH make_counts AS(
    -- Bloco 1: contagem por fabricante
    SELECT
        make,
        COUNT(*) AS vehicle_count
    FROM ev_population_import
    GROUP BY make
)
SELECT
    make,
    vehicle_count,
    -- Bloco 2: CASE comparando com a média
    CASE
        WHEN vehicle_count > ( SELECT AVG(vehicle_count) FROM make_counts ) THEN 'above average'
        ELSE 'below average'
    END AS classification
FROM make_counts
ORDER BY classification ASC, vehicle_count DESC;

--Q7:Which counties have more registered vehicles than the average per county?
-- Technique: CTE (count per county) + scalar subquery (average) + WHERE filter.
-- Nulls: 15 NULL counties (~0.005%) kept as a NULL group; negligible impact on the mean.
WITH county_counts AS (
    -- Bloco 1: contagem por condado
    SELECT
        county,
        COUNT(*) AS vehicle_count
    FROM ev_population_import
    GROUP BY county
)
SELECT
    county,
    vehicle_count
FROM county_counts
WHERE vehicle_count > ( SELECT AVG(vehicle_count) FROM county_counts)
ORDER BY vehicle_count DESC;

--Q8: What is the median electric range, and how do standard deviation and variance vary by EV type?
-- Data quality issue: 81.49% of BEVs have electric_range = 0 (missing info,
-- not real autonomy); 0% of PHEVs. Zeros excluded to avoid distorting stats.
-- Valid rows: ~44,755 BEV + ~58,266 PHEV = ~103,022.
-- Technique: PERCENTILE_CONT(0.5) WITHIN GROUP (ordered-set aggregate),
-- STDDEV, VARIANCE, GROUP BY.
-- Note: 36 NULLs (all PHEV) also excluded by aggregates.
-- Cross-reference: Q5 mean is understated for BEV by the same zeros.

SELECT electric_vehicle_type,
PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY electric_range::numeric) AS median_range,
ROUND(STDDEV(electric_range::numeric),2) AS standard_deviation,
ROUND(VARIANCE(electric_range::numeric),2) AS variance_range
FROM ev_population_import
WHERE electric_range::numeric > 0
GROUP BY electric_vehicle_type;

--Q9:How do counties rank by fleet size, and what is the practical difference between RANK and DENSE_RANK on ties?
--Technique: CTE for aggregation + window functions RANK, DENSE_RANK, OVER(ORDER BY fleet_size DESC).

WITH county_counts AS (
    SELECT
        county,
        COUNT(*) AS fleet_size
    FROM ev_population_import
	WHERE county IS NOT NULL
    GROUP BY county
)
SELECT
    county,
    fleet_size,
	RANK() OVER (ORDER BY fleet_size DESC) AS rank_global,
	DENSE_RANK() OVER (ORDER BY fleet_size DESC) AS dense_rank_global
FROM county_counts
ORDER BY fleet_size DESC, county ASC;

--Q10: What are the top 3 most popular models for each vehicle make?
--Technique: CTE + ROW_NUMBER() OVER(PARTITION BY make ORDER BY COUNT(*) DESC) + filtro rank <= 3
--ROW_NUMBER guarantees at most 3 rows per make (RANK/DENSE_RANK would exceed on ties).
-- Final ORDER BY make, rn groups blocks; popularity "jumps" between makes = partition reset, not a bug.
WITH popular_models AS (
    SELECT
        make,
		model,
        COUNT(*) AS popularity
    FROM ev_population_import
	GROUP BY make, model
),
positions AS(
	SELECT
		make,
		model,
		popularity,
		ROW_NUMBER() OVER (PARTITION BY make ORDER BY popularity DESC) AS rn
	FROM popular_models
)
SELECT 
	make,
	model,
	popularity
FROM positions
WHERE rn <= 3
ORDER BY popularity DESC, make, rn
LIMIT 3;


