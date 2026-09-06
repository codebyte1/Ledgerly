# Ledgerly — a private khata for Bhawani Traders

A Khatabook/Vyapar-style credit ledger that runs entirely in your browser. Add
parties, record udhaar given and received, watch balances, chase due dates,
and produce CSV/PDF reports — with your financial data never leaving this
device.

No accounts. No server. No cloud. No analytics. No AI.

---

## How to run locally

**Double-click `run.command`.**

It starts a small static file server on your own machine and opens
<http://localhost:4173>. Press `Ctrl+C` in the terminal window to stop it.

Or from a terminal:

```bash
cd ledgerly && python3 serve.py
```

Nothing to install — macOS ships with Python 3. There is no `npm install`, no
build step, and no bundler; the files you see are the files that run.

### Why a local server instead of double-clicking `index.html`?

`index.html` is a **folder-based** app: it loads `styles/*.css` and `js/*.js`
from alongside itself. It works opened directly, but only while the whole
folder is intact next to it. Browsers also treat `file://` as an origin-less
context, which costs one thing that matters:

| | `file://` | `http://localhost` |
|---|---|---|
| IndexedDB | usually fine, falls back to localStorage if blocked | works properly |
| Encrypted backups (`crypto.subtle`) | **unavailable** — not a secure context | available |

`run.command` is one double-click and avoids that, so it's the supported way to
run it on this Mac.

---

## Copying it to another device

**Copy `Ledgerly.html`. That one file, nothing else.**

Do **not** copy `index.html` on its own. It is not the app — it's the shell that
loads the app from the `styles/` and `js/` folders beside it. On its own it
opens as unstyled text with no working buttons, because none of the code it
needs came with it.

`Ledgerly.html` is a complete build with every stylesheet and script inlined.
Email it to yourself, AirDrop it, put it on a USB stick — open it and it runs,
with no folders, no internet and no install. Verified: opened alone from a
`file://` path in Chrome it renders fully, and `connect-src 'none'` is still
enforced (the browser blocks fetch, sendBeacon and WebSocket, confirmed via the
`securitypolicyviolation` event).

Regenerate it after any edit to the real sources:

```bash
cd /Users/akshatbaid/Desktop/Claude/Freelance/ledgerly && python3 build.py
```

Two caveats:

- **Every device keeps its own separate book.** The file is copied; the data is
  not, and never syncs. Move a ledger with Settings → Export backup on one
  device and Restore from file on the other.
- Opened from `file://`, encrypted backups are unavailable (no secure context)
  and Settings says so. Plain JSON export still works. Serving the same file
  over HTTPS — via GitHub Pages, below — restores encryption. The server is `127.0.0.1`-only — nothing else on your network,
café wifi included, can reach it — and it only ever hands out the HTML, CSS and
JS. Your ledger never passes through it.

### First run

The book starts empty. Either add your first party, or go to
**Settings → Sample data → Load sample data** for seven example parties and
eighteen transactions to explore with. Sample data is ordinary data: edit or
delete any of it.

---

## Putting it on GitHub Pages (use it on any device)

This is the best way to reach the app from a tablet or phone. GitHub Pages
serves it over HTTPS, which means a proper secure context: IndexedDB is
reliable, encrypted backups work, and the `connect-src 'none'` policy in
`index.html` is fully enforced — the same guarantees you get locally. No Mac
needs to be switched on, and no account is needed on the device.

**One thing to understand first: free GitHub Pages only works from a *public*
repository.** That publishes the *code*, not your data — there is no backend,
so there is nothing on GitHub to leak. Your ledger stays in whichever browser
you typed it into. Two caveats worth a moment's thought:

- Your business name is the default in `js/store.js`, so it would be visible in
  the source. Change it there before pushing if you'd rather it wasn't.
- `.gitignore` already blocks `ledgerly-*.json` and `*.encrypted.json`, so a
  backup file dropped into this folder cannot be committed by accident. Keep it
  that way. **Never commit a backup to a public repo** — that file *is* your
  whole ledger in plain text.

A private repo with Pages needs a paid GitHub plan.

### Route A — no terminal

1. On github.com, click **New repository**. Name it `ledgerly`, set it
   **Public**, and don't add a README (this folder has one).
2. On the empty repo's page, click **uploading an existing file**, then drag in
   everything from this folder — including the `js/` and `styles/` folders.
   Commit.
3. Go to **Settings → Pages**. Under *Build and deployment*, set Source to
   **Deploy from a branch**, branch **main**, folder **/ (root)**. Save.
4. Wait about a minute, then open `https://<your-username>.github.io/ledgerly/`.

### Route B — terminal

This folder is already a git repository with your first commit made, so once
you've created the empty repo on github.com (step 1 above):

```bash
cd /Users/akshatbaid/Desktop/Claude/Freelance/ledgerly && git remote add origin https://github.com/<your-username>/ledgerly.git && git push -u origin main
```

Then do step 3 above to switch Pages on. Git will ask for your GitHub username
and a personal access token (not your password) the first time.

### Then, on each device

Open the Pages URL and use **Add to Home Screen** for an app icon. Remember that
**every device keeps its own separate book** — the site is shared, the data is
not. Move a ledger between devices with Settings → Export backup on one and
Restore from file on the other.

---

## Project structure

```
ledgerly/
├── index.html                  Single page: CSP, icon sprite, app shell
├── Ledgerly.html               GENERATED single-file build — copy this to other devices
├── ledgerly-single-file.html   GENERATED body-only build, for an embedding host
├── build.py                    Regenerates both builds from the sources below
├── run.command                 Double-click launcher (macOS)
├── serve.py                    Local static server, 127.0.0.1 only, no-cache
├── README.md
├── styles/
│   ├── tokens.css              Reset + design tokens (colours, metrics, fonts)
│   ├── layout.css              App shell, sidebar, top bar, responsive rules
│   ├── components.css          Cards, buttons, pills, tables, forms, modal
│   └── print.css               The PDF export (see below)
└── js/
    ├── format.js               Money/date formatting; the ONLY paise↔string code
    ├── dom.js                  el() — textContent-only rendering (XSS barrier)
    ├── db.js                   IndexedDB, with a localStorage fallback
    ├── model.js                Pure business rules: balances, filters, series
    ├── store.js                CRUD + change events; the single door to data
    ├── chart.js                Hand-rolled SVG cash-flow chart (no library)
    ├── csv.js                  CSV builder + file saver (injection-safe)
    ├── backup.js               JSON export/import + AES-GCM encryption
    ├── router.js               Hash router
    ├── app.js                  Bootstrap, modals, forms, toasts, search
    ├── views/                  dashboard, parties, party, ledger,
    │                           reminders, reports, settings
    └── optional-remote-backup.js.example   Disabled. Not loaded. See below.
```

Load order matters: `app.js` must come before `js/views/*` because each view
captures `Ledgerly.ui` at load time.

---

## What it does

**Dashboard** — what you'll receive and pay, credit given this month against
last, total overdue, a 14-day cash-flow chart, reminders due now, and recent
transactions.

**Parties** — searchable by name, phone or note; filter by receivable/payable/
settled; sort by balance, name or recency. Export to CSV.

**Ledger** — every transaction, filterable by search, type, party and date
range, with a running net.

**Party detail** — one party's entries in date order with a running balance,
plus their totals. Export to CSV or print.

**Reminders** — credit given that carries a due date, grouped into overdue,
due today and upcoming. A party who settles up drops off the list
automatically, so it never nags about paid dues. "Settle" pre-fills a payment
for exactly what is outstanding.

**Reports** — pick a range (this month, last month, last 30/90 days, Indian
financial year, or custom), filter by type and party, then export CSV or save
as PDF.

**Settings** — business identity, currency symbol and number format, backup and
restore, sample data, and delete-everything.

### A note on the two transaction types

| Type | Meaning | Effect on balance |
|---|---|---|
| **Udhaar given** | you gave goods or cash on credit | party owes you *more* |
| **Udhaar received** | the party paid you back | party owes you *less* |

`party balance = Σ given − Σ received`. Positive means "you'll receive";
negative means "you'll pay".

### PDF export

There is no PDF library in this project. **Print / Save as PDF** calls
`window.print()`, and `styles/print.css` strips the sidebar, top bar, filters
and buttons, then lays out an A4 report with a header naming your business and
the date range, repeating table headers across pages, and a footer.

This is deliberate. A bundled PDF library would mean ~350KB of minified
third-party code sitting next to your financial data that you cannot
realistically audit — and its built-in fonts have no ₹ glyph, so amounts would
print as "Rs." unless a font were embedded too. Printing uses your real system
fonts, so ₹ renders correctly.

The app sets `document.title` to a sensible filename (e.g.
`ledgerly-report-2026-09-01_to_2026-09-30`) just before the print dialog opens,
because that is what browsers suggest as the PDF filename.

---

## Security & Privacy Notes

### What is stored, and where

| Data | Where it lives |
|---|---|
| Parties, transactions, settings | IndexedDB database `ledgerly` in this browser, on this device |
| Fallback if IndexedDB is blocked | `localStorage` key `ledgerly:db`, same browser, same device |
| Exported backups and CSVs | Wherever you chose to save them on your disk |

That's the complete list. Inspect it yourself: **DevTools → Application →
IndexedDB → ledgerly**.

There is no server-side component, no database elsewhere, no account, no
device-to-device sync, and no session that expires.

### What is never sent anywhere

**Nothing.** Not a name, not an amount, not a usage statistic, not a crash
report.

This is enforced by the browser, not by good intentions. `index.html` carries:

```
connect-src 'none'
```

which makes the browser refuse `fetch`, `XMLHttpRequest`, `WebSocket`,
`EventSource` and `navigator.sendBeacon` from this page. Even a bug, or code
someone slipped in, could not transmit your ledger — the request is blocked
before it leaves. You can verify this in one minute:

1. Open DevTools → Network, filter to Fetch/XHR.
2. Use every screen in the app: add parties, record transactions, run reports.
3. The list stays empty after the initial page load.

The rest of the policy — `default-src 'none'; script-src 'self'; style-src
'self'; img-src 'self' data:; form-action 'none'; base-uri 'none'; object-src
'none'` — means no CDN scripts, no web fonts, no remote images, no form can
POST anywhere, and no `<base>` tag can redirect a relative URL.

### Why an AI assistant cannot read your ledger

- **Nothing is ever logged.** No party, transaction or amount is written to the
  browser console anywhere in `js/`. Console output is exactly what gets caught
  in screen recordings and pasted wholesale into a chat window; there is nothing
  there to catch.
- **Nothing is transmitted.** See above — the page cannot make a request.
- **Nothing is in the URL.** Routing uses hash fragments (`#/parties/…`), which
  browsers never send to a server, and party ids are random rather than derived
  from names.
- The only way an assistant sees a figure is if **you** copy and paste it.

### Other defences

- **XSS.** All user data reaches the DOM through `dom.js`'s `el()`, which sets
  `textContent` and *throws* if you pass it raw HTML. A party named
  `<img src=x onerror=…>` displays as those literal characters. There is no
  `innerHTML` touching user data anywhere, and no inline `onclick` in the HTML —
  every handler is an `addEventListener`.
- **CSV injection.** Spreadsheets execute a cell that begins with `=`, `+`, `-`
  or `@`. Every such cell is prefixed with an apostrophe on export, so a party
  named `=HYPERLINK("http://evil"…)` cannot run when you open the file in Excel.
- **Money is integer paise.** Balances are never held in floating point, because
  `0.1 + 0.2 !== 0.3` is not acceptable in a ledger. `format.js` is the only
  place that converts to and from a display string.
- **Imported data is distrusted.** Records from a backup file are re-validated
  and re-typed on the way in, and transactions pointing at a party that isn't in
  the file are dropped rather than silently distorting your totals.

### Encrypted backups

Inside the browser your ledger is protected by the origin sandbox. The moment
you export it, it's a plain file that anything can read. Ticking **Protect the
backup with a passphrase** encrypts it first, using the browser's own WebCrypto:

```
key  = PBKDF2(passphrase, random 16-byte salt, 310,000 rounds, SHA-256)
file = AES-256-GCM(payload, random 12-byte IV)
```

AES-GCM is authenticated, so a wrong passphrase or a tampered file fails loudly
rather than quietly returning garbage. **There is no recovery.** Forget the
passphrase and that backup is gone permanently — write it down somewhere safe.

Recommended whenever the file will touch a USB stick, a shared computer, or a
cloud drive.

### Back up regularly

Your ledger exists in exactly one place. Clearing your browser's site data,
reinstalling the browser, using a private window, or losing this device will
lose the book. Nobody can restore it for you, because nobody else has a copy —
that is the whole point of the design, and it's also its one sharp edge.

**Settings → Backup & restore → Export backup.** Do it often.

---

## If you modify the code

Things to avoid, in rough order of how badly they would undo the above:

1. **Don't widen `connect-src`.** It is the one line that makes "nothing is
   sent anywhere" a fact rather than a promise. If you must (see below), name a
   single host — never `*`.
2. **Don't add analytics, telemetry, error reporting, or a "just this one"
   third-party script.** Every one of them exists to send data somewhere.
3. **Don't load fonts, icons, or libraries from a CDN.** A font request tells
   that CDN your IP and which page you're on, every time you open the app. Keep
   everything in this folder.
4. **Don't `console.log` a party, transaction or amount**, not even temporarily
   while debugging. Log a record count or an operation name instead.
5. **Don't use `innerHTML`, `insertAdjacentHTML`, or template literals with
   user data.** Use `Ledgerly.dom.el()`, which cannot be handed raw HTML.
6. **Don't store money as a float.** Integer paise, always.
7. **Don't put anything sensitive in a URL**, including the hash. Ids only.

### Adding your own self-hosted backup later

`js/optional-remote-backup.js.example` sketches it, and is deliberately kept as
`.example` so it cannot run — `index.html` does not reference it. Enabling it
takes three deliberate steps: widen `connect-src` to your one host, rename the
file and add a `<script>` tag, then call `Ledgerly.remoteBackup.push()` from a
button you add.

Encrypt before uploading — `Ledgerly.backup.encrypt(payload, passphrase)` is the
same AES-GCM used for file backups — so your server only ever holds ciphertext
it cannot read. The example refuses to send plaintext by default.

---

## Browser support

Any current Chrome, Edge, Firefox or Safari, on desktop or phone. The layout is
responsive: below 900px the sidebar becomes a bottom tab bar and a floating "+"
opens the transaction form.
