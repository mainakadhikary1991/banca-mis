# Banca MIS dashboard

The whole dashboard is one file, `index.html`, and it runs in the browser. Everyone signs in with their work email and a one-time code sent to that email, and sees only the business of the IMD and Sub IMD codes they are tagged to in the Sales Hierarchy, rolled up from L1 (closest to the IMD) to L2, L3 and above.

Live link: https://mainakadhikary1991.github.io/banca-mis/ · [SETUP.md](SETUP.md) has the one-time setup · [PIPELINE.md](PIPELINE.md) explains the data file and the daily load.

Until real data is loaded, the dashboard shows **sample data**. The people, banks and numbers in it are made up.

## Menus

1. **Target vs Achievement**: AOP, Adj AOP (the stretch target above AOP), achieved, Ach % against both, renewal and new business share, renewal rate, last year, growth. The hierarchy tree runs from the top level a person can see down to IMD and Sub IMD code. Percentile bands work on the lowest level shown.
2. **Channel**: two-way boxes such as bank × LOB, bank × product, bank × SA band and state × bank. Premium or growth, FTD / FTW / FTM / FTQ / FTY, growth on financial or calendar year.
3. **LOB**: LOB and product boxes against channel, bank, SA band, premium band, zone and business type, with the same switches.
4. **Renewal**: *Performance* (renewed on time, in grace, won back, lost, win-back pipeline) and *Operations* (win-back, in grace, due today, due in 1–5 … 31–60 days). Click any number for the policy list. The "who acts" list goes to the L1 person on the code.
5. **Performance Report Card**: a 16-section review pack for any cut (channel, sub-channel, bank, LOB, product, zone, state, any hierarchy level), on financial or calendar year:
   Executive scorecard · Growth · Target vs achievement · Channel, sub-channel and bank · Geography · People · Product and LOB · Premium and sum-insured cuts · Renewal · Policy servicing · Cancellation diagnostic · Claims hygiene · P&L proxy · Branch activation and capacity · 30 / 60 / 90 day actions · Priority watchlist.
   The review lens sets the Focus / Watch thresholds for pace, renewal, claims and cancellation (Default, Strict or Tolerant presets, or your own). A section whose data has not been loaded says so instead of showing zeros.

Every page has the same filters at the top, and the hierarchy filters cascade: picking an L3 limits the L2 and L1 lists to the people under that L3.

## Who sees what

- **Admins** (the Admins sheet, plus mainak.adhikary@bajajgeneral.com, which can never be removed) see everything and can load data.
- **Everyone else** sees only the codes they are tagged to. A person tagged to an IMD with the Sub IMD left blank sees the whole IMD. IMD-level targets show only to people who cover every Sub IMD of that IMD.
- With the database connected, this is enforced by the database itself (row-level security): each person's browser receives only their own rows, so nobody can read someone else's data by opening the page source.

## Loading data

Only admins see **Load data**. Drop the day's Excel or CSV files. The dashboard works out which sheet is which, checks and cleans every row, removes repeats, shows what will change and a count of problems by field, and adds the data only after you confirm. The anomaly report (.xlsx) lists every problem with its row number.

The template is `templates/Banca-MIS-Data-Upload.xlsx`: 11 data sheets (Business, Renewals Due, Servicing, Claims, Earned Premium, Targets, Sales Hierarchy, Admins, People, Branch Master, Commission & Expense), with a guide to every column. `templates/Banca-MIS-Snowflake-Queries.sql` has a query for each daily feed.

## Files

| Path | What it holds |
|---|---|
| `index.html` | The whole dashboard |
| `templates/Banca-MIS-Data-Upload.xlsx` | The data template, with a "Read me" and a column guide |
| `templates/Banca-MIS-Data-Upload-Sample.xlsx` | The same template with a few made-up rows in every sheet, to show the format (not for loading into the live dashboard) |
| `templates/Banca-MIS-Snowflake-Queries.sql` | Snowflake queries for Business, Renewals Due, Servicing, Claims and Earned Premium |
| `supabase/setup.sql` | Database tables, access rules and load functions (run once) |
| `supabase/email-code.html` | The sign-in code email |
| `SETUP.md` | One-time setup: database, sign-in email, the link |
| `PIPELINE.md` | The data file, the checks, and how each number is worked out |

## Where the data lives

- **Database connected** (Supabase, Mumbai region): the data is stored in the database; the page on GitHub holds only the dashboard code and sample data. Policy and claim numbers are stored only as scrambled keys; the last 4 characters of a policy number are kept so an RM can find the policy.
- **Database not connected**: the sign-in works without a code, and loads are kept in that one browser only. Fine for trying the dashboard, not for sharing real data.
