-- ============================================
-- Email Monthly Activity Stats per Account
-- Goal: Calculate each account's share of emails
--       sent within a given month, along with
--       first and last send dates
-- Tool: BigQuery
-- Author: Iryna Savelieva
-- ============================================

-- Step 1: Calculate actual send dates by joining
-- email_sent with account_session and session tables
WITH new_date1 AS (
    SELECT
        es.sent_date,
        s.date,
        -- Calculate the actual send date by adding sent_date interval to session date
        DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS new_date,
        -- Truncate to month level to group by calendar month
        DATE_TRUNC(DATE_ADD(s.date, INTERVAL es.sent_date DAY), MONTH) AS sent_month,
        es.id_account,
        es.id_message
    FROM `data-analytics-mate.DA.email_sent` es
    JOIN `data-analytics-mate.DA.account_session` acs
        ON es.id_account = acs.account_id
    JOIN `data-analytics-mate.DA.session` s
        ON acs.ga_session_id = s.ga_session_id
)

-- Step 2: Calculate per-account monthly metrics using window functions
SELECT DISTINCT
    sent_month,
    id_account,
    -- Share of messages sent by this account relative to all messages sent that month (%)
    COUNT(DISTINCT id_message) OVER (PARTITION BY id_account, sent_month)
    / COUNT(DISTINCT id_message) OVER (PARTITION BY sent_month) * 100
        AS sent_msg_percent_from_this_month,
    -- First email send date for this account in the given month
    MIN(new_date) OVER (PARTITION BY id_account, sent_month) AS first_sent_date,
    -- Last email send date for this account in the given month
    MAX(new_date) OVER (PARTITION BY id_account, sent_month) AS last_sent_date
FROM new_date1
ORDER BY 1 DESC, 2
