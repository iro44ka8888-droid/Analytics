-- ============================================
-- Revenue and User Metrics by Continent
-- Goal: Analyze revenue (total, mobile, desktop),
--       account counts and session volume
--       broken down by continent
-- Tool: BigQuery
-- Author: Iryna Savelieva
-- ============================================

-- Step 1: Calculate revenue by continent
-- Split by device type using CASE WHEN
WITH revenue_usd AS (
    SELECT
        sp.continent,
        SUM(p.price) AS revenue,
        -- Revenue from mobile devices only
        SUM(CASE WHEN device = 'mobile' THEN price END) AS revenue_from_mobile,
        -- Revenue from desktop devices only
        SUM(CASE WHEN device = 'desktop' THEN price END) AS revenue_desktop
    FROM `data-analytics-mate.DA.order` o
    JOIN `data-analytics-mate.DA.product` p
        ON o.item_id = p.item_id
    JOIN `data-analytics-mate.DA.session_params` sp
        ON o.ga_session_id = sp.ga_session_id
    GROUP BY continent
),

-- Step 2: Count total and verified accounts by continent
account_cnt AS (
    SELECT
        sp.continent,
        COUNT(DISTINCT id) AS account_count,
        -- Count only verified accounts (is_verified = 1)
        COUNT(DISTINCT CASE WHEN is_verified = 1 THEN id END) AS verified_account
    FROM `data-analytics-mate.DA.account` a
    JOIN `data-analytics-mate.DA.account_session` acs
        ON a.id = acs.account_id
    JOIN `data-analytics-mate.DA.session_params` sp
        ON acs.ga_session_id = sp.ga_session_id
    GROUP BY sp.continent
),

-- Step 3: Count unique sessions by continent
sess_cnt AS (
    SELECT
        sp.continent,
        COUNT(DISTINCT s.ga_session_id) AS session_cnt
    FROM `data-analytics-mate.DA.session` s
    JOIN `data-analytics-mate.DA.session_params` sp
        ON s.ga_session_id = sp.ga_session_id
    GROUP BY sp.continent
)

-- Step 4: Combine all CTEs into a final summary table
-- Using LEFT JOIN to keep all continents even without revenue data
SELECT
    sess_cnt.continent,
    revenue_usd.revenue,
    revenue_usd.revenue_from_mobile,
    revenue_usd.revenue_desktop,
    -- Each continent's share of total revenue (%)
    revenue_usd.revenue / SUM(revenue_usd.revenue) OVER () * 100 AS perc_revenue_from_total,
    account_cnt.account_count,
    account_cnt.verified_account,
    sess_cnt.session_cnt
FROM sess_cnt
LEFT JOIN revenue_usd
    ON sess_cnt.continent = revenue_usd.continent
LEFT JOIN account_cnt
    ON sess_cnt.continent = account_cnt.continent
