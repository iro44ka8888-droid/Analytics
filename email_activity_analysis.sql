-- ============================================
-- Email Activity & Account Creation Analysis
-- Goal: Analyze email engagement metrics
-- (sent, opened, clicked) and account creation
-- dynamics by date, country, send interval,
-- verification and subscription status.
-- Tool: BigQuery
-- Author: Iryna Savelieva
-- ============================================

-- Step 1: Aggregate email activity and account creation
-- by date, country, send interval, verification and subscription status
WITH aggregated AS (
    SELECT
        date,
        country,
        send_interval,
        is_verified,
        is_unsubscribed,
        SUM(account_cnt) AS account_cnt,
        SUM(sent_msg)    AS sent_msg,
        SUM(open_msg)    AS open_msg,
        SUM(visit_msg)   AS visit_msg
    FROM (
        -- Part 1: Email activity metrics (sent, opened, clicked)
        -- Joined with account and session data to get country and user attributes
        SELECT
            DATE_ADD(s.date, INTERVAL ems.sent_date DAY) AS date,
            sp.country,
            a.send_interval,
            a.is_verified,
            a.is_unsubscribed,
            0                                AS account_cnt,
            COUNT(DISTINCT ems.id_message)   AS sent_msg,
            COUNT(DISTINCT eo.id_message)    AS open_msg,
            COUNT(DISTINCT ev.id_message)    AS visit_msg
        FROM `data-analytics-mate.DA.email_sent` ems
        JOIN `data-analytics-mate.DA.account`         a   ON a.id = ems.id_account
        JOIN `data-analytics-mate.DA.account_session` acs ON ems.id_account = acs.account_id
        JOIN `data-analytics-mate.DA.session`         s   ON acs.ga_session_id = s.ga_session_id
        LEFT JOIN `data-analytics-mate.DA.email_open`  eo ON ems.id_message = eo.id_message
        LEFT JOIN `data-analytics-mate.DA.email_visit` ev ON ems.id_message = ev.id_message
        JOIN `data-analytics-mate.DA.session_params`  sp  ON s.ga_session_id = sp.ga_session_id
        GROUP BY date, sp.country, a.send_interval, a.is_verified, a.is_unsubscribed

        UNION ALL

        -- Part 2: Account creation metrics
        -- Counts distinct accounts created per date, country and user segments
        SELECT
            s.date,
            sp.country,
            a.send_interval,
            a.is_verified,
            a.is_unsubscribed,
            COUNT(DISTINCT a.id) AS account_cnt,
            0                    AS sent_msg,
            0                    AS open_msg,
            0                    AS visit_msg
        FROM `data-analytics-mate.DA.account`         a
        JOIN `data-analytics-mate.DA.account_session` ac ON a.id = ac.account_id
        JOIN `data-analytics-mate.DA.session`         s  ON ac.ga_session_id = s.ga_session_id
        JOIN `data-analytics-mate.DA.session_params`  sp ON s.ga_session_id = sp.ga_session_id
        GROUP BY s.date, sp.country, a.send_interval, a.is_verified, a.is_unsubscribed
    ) final
    GROUP BY date, country, send_interval, is_verified, is_unsubscribed
),

-- Step 2: Calculate total account count and sent messages per country
-- Used as a base for ranking
country_summary AS (
    SELECT
        country,
        SUM(account_cnt) AS total_country_account_cnt,
        SUM(sent_msg)    AS total_country_sent_cnt
    FROM aggregated
    GROUP BY country
),

-- Step 3: Rank countries by total account count and total sent messages
-- Using DENSE_RANK to handle ties correctly
ranked_countries AS (
    SELECT *,
        DENSE_RANK() OVER (ORDER BY total_country_account_cnt DESC) AS rank_total_country_account_cnt,
        DENSE_RANK() OVER (ORDER BY total_country_sent_cnt DESC)    AS rank_total_country_sent_cnt
    FROM country_summary
)

-- Step 4: Final output — join aggregated data with Top-10 countries
-- A country is included if it ranks in Top-10 by either metric
SELECT
    a.*,
    rc.total_country_account_cnt,
    rc.total_country_sent_cnt,
    rc.rank_total_country_account_cnt,
    rc.rank_total_country_sent_cnt
FROM aggregated a
JOIN ranked_countries rc ON a.country = rc.country
WHERE rc.rank_total_country_account_cnt <= 10
   OR rc.rank_total_country_sent_cnt    <= 10
ORDER BY a.date, a.country, a.send_interval;
