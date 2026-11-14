# Loading the daily data

Everything happens in the browser when you click **Load data → Check and load**. Nothing changes until you press **Add to dashboard** in the pop-up.

## The file

Use `templates/Banca-MIS-Data-Template.xlsx`. One row per policy. Sheets left with only the header row are skipped. CSV files with the same headers also work.

### Business – every day, one row per policy issued

| Column | Required | What to put |
|---|---|---|
| issue_date | Yes | Date the policy was issued |
| policy_no | Yes | Policy number. Used to catch repeats and updates |
| previous_policy_no | Optional | For a renewal, the policy it renews. Marks that policy as renewed in the due list |
| channel, vertical_head, bank, nc, zh, tl, rm | Yes | The sales hierarchy, same spelling every day |
| state | Yes | State of the branch (codes like KA work) |
| lob, product | Yes | Line of business and product |
| business_type | Yes | Fresh or Renewal |
| premium | Yes | Premium in rupees |
| sum_assured | Yes | Sum assured, sum insured or IDV in rupees |
| location, branch, imd_code, sub_imd_code | Optional | Turn on those filters |

### Renewals Due – every day, one row per expiring policy

| Column | Required | What to put |
|---|---|---|
| policy_no | Yes | The expiring policy number |
| expiry_date | Yes | The renewal due date |
| channel … rm, lob, product | Yes | As in Business, for the RM who owns the renewal |
| premium | Yes | Expiring premium |
| state, sum_assured | Optional | Turn on state, zone and SA band cuts for renewals |
| renewal_status, renewed_on, renewed_premium | Optional | Fill these if your system has them. Otherwise the dashboard works out renewals from previous_policy_no in Business |

### Targets – monthly

`month, channel, vertical_head, bank, nc, zh, tl, rm, lob, product, aop, adj_aop`. A month in this sheet replaces that month's targets.

### Users – when people change

`email, name, role`. Role is Channel Head, MIS Admin, Vertical Head, NC, ZH, TL or RM. Put **Inactive** to remove someone. Only the people listed change; everyone else stays. The name must match the Business sheet at that person's level.

## What the load does, step by step

1. **Reading your file**: opens the .xlsx (or .csv) in the browser.
2. **Finding the sheets**: works out from the header row which sheet is which, and skips the Read me sheet.
3. **Checking columns**: stops, changing nothing, if a must-have column is missing. Lists any other missing columns.
4. **Cleaning and checking every row**:
   - Issue date missing, not a date, or in the future: the row is not loaded.
   - Premium missing or not a number: the row is not loaded. Negative, zero or above ₹1 crore: loaded and flagged.
   - Names with extra spaces or different capital letters are changed to one spelling (the one already in the data, or the most common one in the file).
   - State codes (KA, MH …) become full names. Zone is filled in from the state.
   - Business type words like New, RN and Rollover become Fresh or Renewal.
   - Blank names load as "Unassigned" and are counted as missing.
5. **Checking for repeats in the file**: the same row twice keeps one. The same policy number with different details keeps the last row and flags it.
6. **Checking issue dates**: lists the dates in the file, flags rows dated before the latest date already loaded (past numbers change), and sets the date the dashboard runs to (the latest issue date).
7. **Checking names and hierarchy**: flags an RM under two TLs in the same file, people who moved compared with earlier data, new names (to catch spelling slips), products under a different LOB, and users whose name has no business at their level.
8. **Comparing with the data already loaded**:
   - A policy number seen before with nothing changed is skipped. With something changed, it is updated (moved to the right month if its issue date changed).
   - A row with no policy number is skipped only if an identical row is already loaded.
   - A file with no policy_no column replaces whatever was loaded for the dates in it.
   - Renewals are matched: a Business row whose previous_policy_no is in the due list marks that policy as renewed on its issue date.
9. **Your review**: a summary of what will change and a table of missing, invalid, inconsistent, duplicate and cleaned values by field. **Download anomaly report** gives the full list.
10. **Rebuilding the dashboard**, **saving in this browser** and **publishing to the shared link** (GitHub).

## The anomaly report

An Excel file with: Summary (counts per sheet and per issue date), the cleaned data for each sheet with a load status on every row, and **Anomalies** as the last sheet: counts by field, then one line per problem with the sheet, row number, policy number, field, problem, value found and what was done.

## Renewal rules

- Renewed on time: on or before the expiry date. Renewed in grace: within the grace period. Won back: after the grace period.
- In grace: expired, not renewed, grace still running. Win-back pipeline: grace over, still within the win-back window. Lost: past the window (opportunity lost).
- Default grace: Health 30 days, others none. Default win-back window: 90 days after grace. Change them under Renewal → Rules (kept per browser).
- Premium on the renewal pages is the expiring premium.

## What is published

Only the cleaned data, in `data/`. Policy numbers are replaced by a scrambled key, plus the last 4 characters so an RM can find the policy. The anomaly report stays on your computer.

## Band edges

Sum assured: under ₹1L, ₹1–3L, ₹3–5L, ₹5–10L, ₹10–25L, ₹25–50L, ₹50L–1Cr, ₹1Cr+. Premium: under ₹2.5k, ₹2.5–5k, ₹5–10k, ₹10–25k, ₹25–50k, ₹50k–1L, ₹1L+.
