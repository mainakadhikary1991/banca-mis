# Banca MIS dashboard

The whole dashboard is one file, `index.html`. It runs in the browser. Everyone signs in with their work email and sees only the business under them, rolled up from RM to TL to ZH to NC to bank to vertical head to channel.

Live link: https://mainakadhikary1991.github.io/banca-mis/ · [SETUP.md](SETUP.md) has the setup steps.

Until real data is loaded, the dashboard shows **sample data**. The people, banks and numbers in it are made up.

## Menus

1. **Target vs Achievement**: AOP, Adj AOP (the internal stretch target above AOP), achieved, Ach % against both, renewal and fresh share of achieved, renewal rate, last year, growth vs the same dates last month, YTD growth and MTD growth. "Show levels" picks any mix of Channel, Vertical Head, Bank, NC, ZH, TL and RM. The percentile filter works on the lowest level shown.
2. **Channel**: two-way boxes, such as bank × LOB, bank × product, bank × SA band and state × bank, with a trend view.
3. **LOB**: LOB and product boxes against channel, bank, SA band, premium band, zone and business type.
4. **Renewal**, with two views:
   - **Performance**: for policies due in a period, how many were renewed on time, renewed in grace or won back, and how many sit in grace, in the win-back pipeline or are lost (opportunity lost). Cut by bank, channel, VH, NC, ZH, TL, RM, LOB, product, premium size, SA band, state or zone. Includes the win-back pipeline by days since expiry and renewal % by expiry month.
   - **Operations**: what needs action now: win-back, in grace, due today, due in 1–5, 6–10, 11–15, 16–30 and 31–60 days, plus policies already renewed early. Shown as policies or premium, in bands or cumulative. Click any number to list the policies.

Colours run from red through orange to green: behind pace or falling is red, on pace or growing is green. In the boxes, "Performance" colour compares each box with the overall mix, and "Size" colour shows how big it is.

## Loading data

Only the Channel Head and MIS Admin see **Load data**. Drop the day's Excel file (one row per policy) and the dashboard:

- reads every sheet and works out which is Business, Renewals Due, Targets or Users
- checks and cleans every row, removes repeats, and checks issue dates
- shows a pop-up with each step, what will change and a count of missing, invalid, inconsistent, duplicate and cleaned values by field
- adds the data only after you confirm, keeps a copy in the browser, and publishes it to GitHub so the shared link updates
- gives you an anomaly report (.xlsx) whose last sheet lists every problem with its row number

[PIPELINE.md](PIPELINE.md) explains the file and every check.

## Files

| Path | What it holds |
|---|---|
| `index.html` | The whole dashboard |
| `templates/Banca-MIS-Data-Template.xlsx` | The file to fill every day |
| `data/` | Created by the first load: `manifest.json`, `business/YYYY-MM.csv`, `renewals/YYYY-MM.csv`, `targets.csv`, `users.csv` |
| `SETUP.md` | Setting up the GitHub account, the link and the token |
| `PIPELINE.md` | The data file and what the load does |

## Before real data goes in

A GitHub Pages site is public, and the sign-in only checks that an email is on the list. Anyone who has the link can open the data files. Policy numbers are never published, only a scrambled key and the last 4 characters, but names and amounts are. Real MIS needs a host with a proper login (company SSO through IT, or a service such as Cloudflare Access) and, for strict separation between people, a server that sends each person only their own slice.
