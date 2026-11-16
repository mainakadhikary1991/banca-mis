# One-time setup

About 30 minutes, once. After that, the daily load is done from the dashboard itself. Menu names below are as they appear in Supabase and Brevo today; they move around now and then.

What you end up with:

- **GitHub Pages** hosts the dashboard page (code and sample data only).
- **Supabase** (database, Mumbai region) stores the data, sends the sign-in code and decides who can read which rows.
- **Brevo** delivers the sign-in emails, so they come from your own sender address and are not capped at Supabase's built-in few per hour.

## 1. Database tables and access rules (Supabase)

1. Open the project in Supabase → **SQL Editor** → **New query**.
2. Paste the whole of `supabase/setup.sql` and click **Run**. It is safe to run again later: it creates what is missing and replaces the functions.
3. It creates the tables (business, renewals, servicing, claims, earned, targets, sales_map, admins, people, branches, costs, load_log), the access rules, and the functions the dashboard uses to load data. mainak.adhikary@bajajgeneral.com is set up as the first admin.

## 2. Sign-in by email code

1. **Authentication → Sign In / Providers → Email**: Email on. Confirm email on. Email OTP expiration **600** seconds. Email OTP length **6**. Save.
2. **Authentication → URL Configuration**: Site URL `https://mainakadhikary1991.github.io/banca-mis/`. Save.
3. **Authentication → Auth Hooks → Add hook → Before User Created**: type Postgres, schema `public`, function `hook_before_user_created`. Save. This stops anyone who is not in the Sales Hierarchy or Admins sheet from getting a code at all.

## 3. Sending the code through Brevo

1. In Brevo → **Senders, domains & dedicated IPs → Senders**: add the sender address (for example `banca.mis@bajajgeneral.com`) and verify it from the email Brevo sends.
2. **Domains**: to send as `@bajajgeneral.com`, IT has to add Brevo's DKIM and DMARC records for that domain (Brevo shows the exact records). Without them, company mail filters may quarantine or reject the code emails. If that takes time, use a sender on a domain you control for now.
3. **SMTP & API → SMTP**: note the SMTP login, then click **Generate a new SMTP key** and copy it. Brevo shows it once. Don't paste it into chats or emails.
4. In Supabase → **Authentication → Emails → SMTP Settings**: Enable custom SMTP. Sender email = the verified address. Sender name `Banca MIS`. Host `smtp-relay.brevo.com`. Port `587`. Username = the Brevo SMTP login. Password = the SMTP key. Save.
5. **Authentication → Rate Limits**: raise "emails sent per hour" to cover everyone signing in on a busy morning.

## 4. The code email

In Supabase → **Authentication → Emails → Templates**, for both **Magic Link** and **Confirm signup**:

- Subject: `{{ .Token }} is your Banca MIS sign-in code`
- Body: paste the whole of `supabase/email-code.html` (switch the editor to source / HTML first).

Send yourself a code to check it looks right in Outlook and on the phone.

## 5. Connect the dashboard to the database

1. Supabase → **Project Settings → API Keys**: copy the **Project URL** and the **publishable (anon) key**.
2. In `index.html`, find `const SUPA={url:'',anon:''};` and put them in:
   `const SUPA={url:'https://<project-ref>.supabase.co',anon:'<publishable key>'};`
3. The publishable key is meant to sit in the page; the access rules from step 1 are what protect the data. **Never** put the secret / service_role key in the file.

## 6. Put the page on GitHub Pages

1. In the `banca-mis` repository on GitHub: **Add file → Upload files**. Drag in `index.html`, `README.md`, `PIPELINE.md`, `SETUP.md` and the `templates` and `supabase` folders. **Commit changes**.
2. **Settings → Pages**: Source **Deploy from a branch**, branch **main**, folder **/ (root)**. Save. The link is live in a minute or two.
3. If the repository has a `data/` folder from the old GitHub-publishing version, delete it so old data is not left public.

## 7. The first real load

1. Open the link, sign in with mainak.adhikary@bajajgeneral.com and the code from the email.
2. **Load data** → drop the filled template (all 11 sheets, history from 1 Apr 2025). Large sheets can go as separate .csv files with the same header row.
3. Check the pop-up. Tick **Replace all existing data** for the very first load. Click **Add to dashboard**.
4. Sign in as an L1 and an L3 person (or ask one) and check they see only their own codes.

## Every day after that

Load data → drop the day's file (usually Business, Renewals Due, Servicing and Claims) → review → Add to dashboard. Earned Premium, Commission & Expense, People and Branch Master once a month. Targets and the Sales Hierarchy when they change.

## If something goes wrong

- **No code arrives**: check Brevo → Transactional → Logs. "Blocked" or "Deferred" usually means the sender domain is not authenticated (step 3.2). Also check the person is in the Sales Hierarchy or Admins sheet: the hook refuses anyone else with "This email is not set up for the Banca MIS."
- **"That code is wrong or has expired"**: codes work for 10 minutes and once. Ask for a new one.
- **A person sees nothing**: their email in the Sales Hierarchy must match the one they sign in with, and their codes must match the codes in the Business sheet (same spelling).
- **Load refused with "Only an admin can load data"**: the signed-in email is not in the Admins sheet.
