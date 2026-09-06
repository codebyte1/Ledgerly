# Turning on accounts and sync

Ledgerly works with no backend at all. This guide adds sign-in and encrypted
sync across devices. Budget about 30 minutes.

**What you get:** anyone can open your link, create an account, and keep their
own ledger, reachable from every device they sign in on.

**What stays true:** the server stores ciphertext it cannot read. Sign-in
decides *which* rows are yours; your passphrase decides whether anyone can
*read* them, and it never leaves your device.

---

## 1. Create a Supabase project

1. Sign up at [supabase.com](https://supabase.com) — the free tier is enough
   for a personal ledger by a wide margin.
2. **New project.** Pick a name and a strong database password (you won't need
   it again for this app — save it anyway). Choose the region closest to you.
3. Wait a couple of minutes for it to finish provisioning.

## 2. Create the tables

1. In your project: **SQL Editor → New query**.
2. Paste the entire contents of [`supabase/schema.sql`](supabase/schema.sql).
3. **Run.**

That creates two tables and — the important part — the Row Level Security
policies that make Postgres itself refuse to hand any user another user's rows.
Read the comments in that file; they explain why each piece is there. It's safe
to re-run.

## 3. Point the app at your project

In Supabase: **Settings → API**. Copy two values into `js/config.js`:

```js
supabaseUrl:     'https://YOUR-PROJECT-ref.supabase.co',
supabaseAnonKey: 'eyJhbGci...'          // the `anon` `public` key
```

Both are public by design and are meant to ship in client code. On their own
they open nothing: RLS refuses every row to an unauthenticated caller, and
everything stored is encrypted anyway.

> **Never put the `service_role` key here.** That key bypasses RLS entirely.
> If it ever ends up in client code or in a public repo, rotate it immediately.

## 4. Choose sign-in methods

### Email + password — works immediately

On by default. Two things worth knowing:

- Supabase requires email confirmation by default, so new users get a link
  before they can sign in. To change that: **Authentication → Providers →
  Email → Confirm email**.
- The free tier sends a limited number of emails per hour from a shared
  address. For real use, add your own SMTP under **Project Settings → Auth**.

### Google — free, about 10 minutes

1. [Google Cloud Console](https://console.cloud.google.com) → create a project.
2. **APIs & Services → OAuth consent screen.** External. Fill in the app name
   and your email. Add yourself as a test user while you're still testing.
3. **Credentials → Create credentials → OAuth client ID → Web application.**
4. Under *Authorised redirect URIs* add exactly this, from Supabase
   **Authentication → Providers → Google**:
   ```
   https://YOUR-PROJECT-ref.supabase.co/auth/v1/callback
   ```
5. Copy the Client ID and Client Secret into that same Supabase page and enable
   the provider.
6. In `js/config.js` set `providers.google: true`.

### Apple — needs a paid Apple Developer account

Sign in with Apple requires membership at **US$99/year**. If you don't have one,
leave `providers.apple: false`; the button simply won't appear. Setup otherwise
mirrors Google, under **Authentication → Providers → Apple**.

## 5. Tell Supabase where your app lives

This step is the one people miss, and OAuth fails without it.

**Authentication → URL Configuration:**

- **Site URL** — where your app is served, e.g.
  `https://YOUR-USERNAME.github.io/ledgerly/`
- **Redirect URLs** — add the same URL. Add `http://localhost:4173/` too, so
  sign-in works while you're testing locally.

## 6. Lock the CSP to your project (optional, recommended)

`index.html` allows `connect-src https://*.supabase.co`, which permits any
Supabase project. To narrow it to only yours, replace the wildcard with your
exact host:

```
connect-src https://YOUR-PROJECT-ref.supabase.co;
```

Nothing else in the app needs the network, so this stays airtight either way.

## 7. Publish

Follow **Putting it on GitHub Pages** in [README.md](README.md). Your
`config.js` values go into the public repo — that's fine and intended, per
step 3.

---

## Checking it works

1. Open your published URL in a private window. You should see the sign-in
   screen, not the dashboard.
2. Create an account. You'll be asked for an encryption passphrase — this is
   separate from your password, and there is no reset.
3. Add a party and a transaction. The sync chip in the top bar should settle on
   "Synced".
4. In Supabase, open **Table Editor → records.** You should see rows whose
   `ciphertext` is unreadable base64. **If you can read a party name there,
   stop — something is wrong.**
5. Open the same URL in a different browser, sign in, enter the passphrase.
   Your ledger should appear.
6. Sign in as a *second* user in yet another browser. That account must see an
   empty book. If it sees the first user's data, the RLS policies from step 2
   did not apply.

## If something goes wrong

| Symptom | Cause |
|---|---|
| "requested path is invalid" after Google | Step 5 — the redirect URL isn't registered |
| Sign-in works, ledger is empty | Wrong passphrase, or a second vault on the account. Records that can't be decrypted are left untouched, never deleted |
| "Could not reach the sync server" | Offline, or the CSP doesn't allow your Supabase host |
| Sign-up says "email not confirmed" | Check the inbox, or turn confirmation off in step 4 |
| Rows readable in Table Editor | The app was bypassed. Never write to these tables directly |

## The honest limits

- **Metadata is visible to Supabase.** Not your names, amounts, dates or notes
  — but how many records you have, when each changed, and roughly how large it
  is. Hiding that needs padding and cover traffic, which this doesn't do.
- **Forgotten passphrase means gone.** No reset exists, because a reset would
  mean someone else held a key. Keep a JSON backup (Settings → Export backup)
  and write the passphrase down somewhere safe.
- **Conflicts resolve last-writer-wins,** by record. Editing the same
  transaction on two offline devices keeps the later edit and discards the
  other. There is no merge UI.
- **You are the operator now.** With a backend, you're responsible for the
  Supabase project and its availability. The local-only mode had no such
  dependency — that was the trade you made.
