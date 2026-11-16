# Loading the data

Everything happens in the browser when an admin clicks **Load data → Check and load**. Nothing changes until **Add to dashboard** is pressed in the pop-up.

## The file

Use `templates/Banca-MIS-Data-Upload.xlsx`. Its **Read me** sheet lists every sheet, how often to send it and which pages use it; **Read me - columns** explains every column with an example. One workbook can hold any of the sheets; send only the sheets that changed. Sheets left with only the header row are skipped. CSV files with the same header row also work (use CSV for a sheet over a million rows). Column names are matched loosely (`Policy No`, `policy_no` and `POLICY NUMBER` are all read), and the sheet is recognised from its header row, not its name.

| Sheet | One row per | How often | Needed |
|---|---|---|---|
| Business | Policy, at issuance | Daily, month to date | Required |
| Renewals Due | Expiring policy | Daily, expiring from 90 days ago to 60 days ahead | Required |
| Servicing | Endorsement, refund or cancellation | Daily, month to date | Required |
| Claims | Claim, with its latest status | Daily, reported or changed in the last 45 days | Required |
| Earned Premium | Month × IMD × Sub IMD × LOB × product | Monthly, after close | Required |
| Targets | Month × IMD (× Sub IMD × LOB × product) | Start of year, and when revised | Required |
| Sales Hierarchy | IMD / Sub IMD code, with L1 … Ln name, email, designation, emp code | When it changes | Required |
| Admins | Person | When it changes | Required |
| People | Person (HR status) | Monthly | Optional |
| Branch Master | Bank branch | Monthly | Optional |
| Commission & Expense | Month × IMD (× LOB × product) | Monthly | Optional |

The first load carries history from 1 Apr 2025, so that growth on last year works for the whole of this financial year. `templates/Banca-MIS-Snowflake-Queries.sql` has a query for each daily sheet and for Earned Premium.

## What the load does

1. **Reads** each .xlsx or .csv and works out which sheet is which from the header row. "Read me" sheets are skipped.
2. **Checks columns**: stops, changing nothing, if a must-have column is missing; lists optional columns that are absent or empty.
3. **Cleans and checks every row.** Each problem is counted as Missing, Invalid, Inconsistent, Duplicate or Cleaned, with what was done. Examples:
   - A date that is missing, not a date, or in the future: the row is not loaded (for Business, Servicing, Claims). Dates more than two years old are loaded and flagged.
   - Premium not a number: row not loaded. Negative, zero or above ₹1 crore for one policy: loaded and flagged. Sum assured below the premium: flagged.
   - Policy end before start, or start more than 45 days before issue: flagged.
   - Business type: New, Renewal, Rollover or Portability (common spellings such as NB, RN, Roll over are understood). A renewal with no previous policy number is flagged, because it cannot be matched to the due list.
   - Servicing: refunds given as positive numbers are made negative; a nil endorsement with a premium change, or a cancellation before the issue date, is flagged.
   - Claims: a closed claim with a reserve still open, an open claim with no reserve, a rejected claim with a payment, or a loss date after the reported date is flagged.
   - Names with extra spaces or different capitals become one spelling (the one already loaded, else the most common in the file). State codes (KA, MH …) become full names and the zone is filled in from the state.
   - A row with no IMD code loads, but only admins see it.
4. **Removes repeats** inside the file: the same row twice keeps one; the same policy, claim or transaction number with different details keeps the last and flags it.
5. **Checks the Sales Hierarchy**: rows with no email at any level are skipped; a gap in the chain (an L3 with no L2) is flagged; repeated lines across loads are merged, so loading the same hierarchy twice changes nothing.
6. **Compares with the data already loaded**:
   - Business, Renewals Due, Servicing, Claims, People, Branch Master: matched by policy number, transaction number, claim number, email, or bank and branch code. Unchanged rows are skipped; changed rows are updated.
   - Targets, Earned Premium, Commission & Expense: each month in the file replaces that month.
   - Sales Hierarchy: each code in the file replaces that code's people; codes not in the file stay. Admins: listed people are added, or removed with role "Inactive" (mainak.adhikary@bajajgeneral.com can never be removed).
   - A Business row whose previous policy number is in the due list marks that policy as renewed on its issue date.
7. **Your review**: a summary of what will change and a table of problems by field. **Download anomaly report** gives the full list.
8. **Saves** to the Banca MIS database (or this browser, if the database is not connected yet) and rebuilds every page.

## The anomaly report

An Excel file with a Summary, the cleaned data of each sheet with a load status on every row, and **Anomalies** as the last sheet: counts by field, then one line per problem with the sheet, row number, policy number as given in your file (the report never leaves your computer), field, problem, value found and what was done.

## How the numbers are worked out

- **GWP** is built the way it is booked: premium at issuance (Business) plus every extra premium, refund and cancellation (Servicing) on its own date. Policy count and sum assured are counted once, from the issuance row.
- **Achievement** = GWP ÷ AOP for the same months. Targets set on an IMD roll up through everyone who shares that IMD; targets with a Sub IMD code also give L1 people their own target.
- **Growth** compares the same dates last year (or last month), on the financial year (Apr–Mar) or calendar year, as chosen.
- **Renewal rate** = policies renewed ÷ policies due. Renewed on time: on or before expiry. In grace: within the grace period (Health 30 days, others none by default). Won back: after grace, within the win-back window (90 days by default). Lost: past the window. Grace and window can be changed under Renewal → Rules.
- **Servicing rate** = policies issued this year that had at least one servicing row ÷ policies issued this year. Servicing on policies issued earlier is shown as "carry-in".
- **Cancellation rate** (issued cohort) = policies issued this year that were later cancelled ÷ policies issued this year. Days to cancel run from the issue date to the cancellation date.
- **Claims ratio** = incurred claims (paid + outstanding) on claims reported in the period ÷ earned premium for the same months. Only months with earned premium loaded are counted, so a missing month never makes the ratio look low. Frequency = claims ÷ earned policies; severity = incurred ÷ claims.
- **P&L proxy** = earned premium − incurred claims, then less commission, acquisition cost and operating expense where Commission & Expense is loaded. Costs given by IMD only come off the total, not the LOB lines.
- **Branch activation** = branches with business ÷ open branches in the Branch Master (without the Branch Master, only branches with business can be counted).
- **Focus / Watch / On pace** use the review lens thresholds in the report card (Default, Strict or Tolerant, or your own, kept per browser).

## What is stored

Only cleaned data. Policy and claim numbers are replaced by a scrambled key; the last 4 characters of a policy number are kept so an RM can find the policy. The anomaly report stays on the admin's computer.

## Band edges

Sum assured: under ₹1L, ₹1–3L, ₹3–5L, ₹5–10L, ₹10–25L, ₹25–50L, ₹50L–1Cr, ₹1Cr+. Premium: under ₹2.5k, ₹2.5–5k, ₹5–10k, ₹10–25k, ₹25–50k, ₹50k–1L, ₹1L+.
