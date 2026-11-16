-- Banca MIS: Snowflake queries for the daily upload.
-- One query per sheet. The names after AS must stay exactly as they are: the dashboard reads columns by name.
-- Change everything in <angle brackets> to your own tables, columns and filters.
-- Daily window: 1st of the month to yesterday. On the 1st it sends the whole of last month,
-- so late corrections come through. Re-sent rows that have not changed are skipped on load.
-- First load: replace the date filter with  >= '2025-04-01'  and send as .csv if it passes a million rows.


-- =====================================================================
-- 1. Business: one row per policy, the issuance transaction only
--    (extra premium, refunds and cancellations go to Servicing)
-- =====================================================================
SELECT
    TO_CHAR(p.<issue_date>, 'YYYY-MM-DD')              AS issue_date,
    p.<policy_number>                                   AS policy_no,
    p.<previous_policy_number>                          AS previous_policy_no,
    TO_CHAR(p.<risk_start_date>, 'YYYY-MM-DD')          AS policy_start_date,
    TO_CHAR(p.<risk_end_date>, 'YYYY-MM-DD')            AS policy_end_date,
    p.<imd_code>                                        AS imd_code,
    p.<sub_imd_code>                                    AS sub_imd_code,
    p.<channel>                                         AS channel,
    p.<sub_channel>                                     AS sub_channel,
    p.<bank_name>                                       AS bank,
    p.<state>                                           AS state,
    p.<city>                                            AS city,
    p.<branch_sol_id>                                   AS branch_code,
    p.<branch_name>                                     AS branch_name,
    p.<lob>                                             AS lob,
    p.<product_name>                                    AS product,
    p.<business_type>                                   AS business_type,   -- New / Renewal / Rollover / Portability
    p.<premium_excl_gst>                                AS premium,         -- same basis as the AOP targets
    p.<sum_insured>                                     AS sum_assured
FROM <policy_transaction_table> p
WHERE p.<transaction_type> = '<issuance / base>'
  AND p.<channel_group> = '<bancassurance filter>'
  AND p.<issue_date> >= DATE_TRUNC('month', DATEADD(day, -1, CURRENT_DATE()))
  AND p.<issue_date> <  CURRENT_DATE()
QUALIFY ROW_NUMBER() OVER (PARTITION BY p.<policy_number> ORDER BY p.<transaction_timestamp>) = 1;


-- =====================================================================
-- 2. Renewals Due: one row per policy expiring
--    Window: expired up to 90 days ago (win-back) to 60 days ahead
-- =====================================================================
SELECT
    e.<policy_number>                                   AS expiring_policy_no,
    TO_CHAR(e.<risk_end_date>, 'YYYY-MM-DD')            AS expiry_date,
    e.<imd_code>                                        AS imd_code,
    e.<sub_imd_code>                                    AS sub_imd_code,
    e.<channel>                                         AS channel,
    e.<bank_name>                                       AS bank,
    e.<state>                                           AS state,
    e.<city>                                            AS city,
    e.<branch_sol_id>                                   AS branch_code,
    e.<lob>                                             AS lob,
    e.<product_name>                                    AS product,
    e.<premium_excl_gst>                                AS premium,
    e.<sum_insured>                                     AS sum_assured,
    CASE WHEN r.<policy_number> IS NOT NULL THEN 'Renewed' END       AS renewal_status,
    TO_CHAR(r.<issue_date>, 'YYYY-MM-DD')               AS renewed_on,
    r.<policy_number>                                   AS renewed_policy_no,
    r.<premium_excl_gst>                                AS renewed_premium
FROM <policy_table> e
LEFT JOIN <policy_table> r
       ON r.<previous_policy_number> = e.<policy_number>
WHERE e.<channel_group> = '<bancassurance filter>'
  AND e.<risk_end_date> >= DATEADD(day, -90, CURRENT_DATE())
  AND e.<risk_end_date> <= DATEADD(day,  60, CURRENT_DATE());


-- =====================================================================
-- 3. Servicing: one row per endorsement, refund or cancellation
-- =====================================================================
SELECT
    t.<endorsement_number>                              AS transaction_no,
    t.<policy_number>                                   AS policy_no,
    TO_CHAR(t.<transaction_date>, 'YYYY-MM-DD')         AS transaction_date,
    CASE WHEN t.<is_cancellation> THEN 'Cancellation'
         WHEN t.<premium_change> > 0 THEN 'Extra premium'
         WHEN t.<premium_change> < 0 THEN 'Refund'
         ELSE 'Nil endorsement' END                     AS transaction_type,
    t.<endorsement_or_cancellation_reason>              AS reason,
    t.<premium_change>                                  AS premium_change,  -- refunds and cancellations negative
    t.<sum_insured_change>                              AS sum_assured_change,
    TO_CHAR(p.<issue_date>, 'YYYY-MM-DD')               AS policy_issue_date,
    p.<imd_code>                                        AS imd_code,
    p.<sub_imd_code>                                    AS sub_imd_code,
    p.<bank_name>                                       AS bank,
    p.<lob>                                             AS lob,
    p.<product_name>                                    AS product,
    p.<business_type>                                   AS business_type
FROM <policy_transaction_table> t
JOIN <policy_table> p ON p.<policy_number> = t.<policy_number>
WHERE t.<transaction_type> <> '<issuance / base>'
  AND p.<channel_group> = '<bancassurance filter>'
  AND t.<transaction_date> >= DATE_TRUNC('month', DATEADD(day, -1, CURRENT_DATE()))
  AND t.<transaction_date> <  CURRENT_DATE();


-- =====================================================================
-- 4. Claims: one row per claim, latest status and amounts
--    Daily: claims reported or changed in the last 45 days
-- =====================================================================
SELECT
    c.<claim_number>                                    AS claim_no,
    c.<policy_number>                                   AS policy_no,
    TO_CHAR(c.<intimation_date>, 'YYYY-MM-DD')          AS intimation_date,
    TO_CHAR(c.<loss_date>, 'YYYY-MM-DD')                AS loss_date,
    c.<claim_status>                                    AS claim_status,     -- Open / Paid / Partly paid / Rejected / Closed without payment / Reopened
    c.<paid_to_date>                                    AS paid_amount,
    c.<outstanding_reserve>                             AS outstanding_amount,
    TO_CHAR(c.<settlement_date>, 'YYYY-MM-DD')          AS settlement_date,
    c.<claim_type>                                      AS claim_type,
    p.<imd_code>                                        AS imd_code,
    p.<sub_imd_code>                                    AS sub_imd_code,
    p.<bank_name>                                       AS bank,
    p.<lob>                                             AS lob,
    p.<product_name>                                    AS product,
    p.<state>                                           AS state,
    p.<business_type>                                   AS business_type,
    TO_CHAR(p.<issue_date>, 'YYYY-MM-DD')               AS policy_issue_date
FROM <claims_table> c
JOIN <policy_table> p ON p.<policy_number> = c.<policy_number>
WHERE p.<channel_group> = '<bancassurance filter>'
  AND (c.<intimation_date> >= DATEADD(day, -45, CURRENT_DATE())
       OR c.<last_updated_date> >= DATEADD(day, -45, CURRENT_DATE()));


-- =====================================================================
-- 5. Earned Premium: monthly, after month close
-- =====================================================================
SELECT
    TO_CHAR(ep.<earning_month>, 'YYYY-MM')              AS month,
    ep.<imd_code>                                       AS imd_code,
    ep.<sub_imd_code>                                   AS sub_imd_code,
    ep.<lob>                                            AS lob,
    ep.<product_name>                                   AS product,
    ep.<business_type>                                  AS business_type,
    SUM(ep.<earned_premium>)                            AS earned_premium,
    SUM(ep.<earned_exposure_years>)                     AS earned_policies
FROM <earned_premium_table> ep
WHERE ep.<channel_group> = '<bancassurance filter>'
  AND ep.<earning_month> = DATE_TRUNC('month', DATEADD(month, -1, CURRENT_DATE()))
GROUP BY 1, 2, 3, 4, 5, 6;


-- Checks worth running before loading:
--   Business:  SELECT policy_no, COUNT(*) FROM (<query 1>) GROUP BY 1 HAVING COUNT(*) > 1;      -- must return nothing
--   Claims:    SELECT claim_no,  COUNT(*) FROM (<query 4>) GROUP BY 1 HAVING COUNT(*) > 1;      -- must return nothing
--   All:       imd_code / sub_imd_code spelled the same way as in the Sales Hierarchy.
-- Targets, Sales Hierarchy, Admins, People, Branch Master and Commission & Expense usually come from
-- planning, HR and finance files: paste them into their sheets in the template.
