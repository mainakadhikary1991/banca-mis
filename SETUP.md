# Setting up the shared link on a new GitHub ID

About 15 minutes, once. After that, the daily load is done from the dashboard itself.

## 1. Create the GitHub account

Sign up at github.com with the ID you want in the link. The link will be `https://<id>.github.io/<repository>/`. Use this ID only for this dashboard: other pages hosted under the same ID could read what the dashboard keeps in the browser, including the token.

## 2. Create the repository and upload the files

1. Click **+ → New repository**. Name it, for example `banca-mis`. Choose **Public** (GitHub Pages is free only for public repositories). Tick **Add a README file**. Click **Create repository**.
2. Click **Add file → Upload files**. Drag in `index.html`, `README.md`, `PIPELINE.md`, `SETUP.md` and the `templates` folder. Click **Commit changes**.

## 3. Turn on the link

1. In the repository, open **Settings → Pages**.
2. Under **Build and deployment**, set Source to **Deploy from a branch**, Branch to **main** and folder to **/ (root)**. Click **Save**.
3. After a minute or two the page shows "Your site is live at …". That is the link to share. It opens on sample data.

## 4. Create the access token the dashboard uses to publish

1. Click your profile photo → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
2. Name it `Banca MIS loader`. Set an expiry date (up to a year).
3. Repository access: **Only select repositories** → pick `banca-mis`.
4. Permissions → Repository permissions → **Contents: Read and write**. Leave everything else as it is.
5. Click **Generate token** and copy it (it starts with `github_pat_`). GitHub shows it only once. Don't paste it into chats or emails.

## 5. Connect the dashboard

1. Open the link. In the sample sign-in list, click **MIS Admin**.
2. Click **Load data → Shared link (GitHub)**. Fill in the GitHub ID, the repository name, branch `main`, and paste the token.
3. Click **Test connection**. It should say "Connected" and show the link. The token stays in this browser only.

## 6. The first real load

1. Fill the template with real data, including the **Users** sheet with at least yourself as MIS Admin or Channel Head.
2. Load data → drop the file → **Check and load**. "Replace all existing data" is ticked automatically because the dashboard is on sample data.
3. Check the pop-up, then click **Add to dashboard**. It saves, publishes, and the link shows the real data in about a minute.
4. Sign out and sign in with your own email.

## Every day after that

Load data → drop the day's file → Check and load → review → Add to dashboard. Download the anomaly report if the pop-up shows problems.

## If something goes wrong

- **"GitHub did not accept the access token"**: the token expired or was mistyped. Make a new one (step 4) and paste it under Shared link.
- **"The shared data was changed from another browser"**: someone else published first. Reload the page and load your file again.
- **Publishing failed for another reason**: the data is still saved in your browser. Use Load data → Shared link → **Publish now** to retry.
- **Starting over**: in the repository, delete the `data` folder. The link goes back to sample data.
