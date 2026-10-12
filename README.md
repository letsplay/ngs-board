# ViAAS Action Board — self-hosted

Shared, live board of the workshop actions (cards by functional layer × company, dependencies,
waves, people). Static page on **GitHub Pages**, shared data in **Supabase** (free tier),
sign-in by **e-mail magic link**, editors limited to an **allowlist**, every change written to an
**audit table** (who / when / what).

```
index.html            the board (no build step)
config.js             Supabase project URL + anon key  ← the only file you edit
supabase/schema.sql   tables, access rules, audit trigger, realtime
supabase/seed.sql     the 38 workshop cards
```

## 1. Supabase (≈10 min)

1. https://supabase.com → **New project** (free). Pick the EU region (Frankfurt/Paris). Wait for it to start.
2. **SQL editor → New query**: paste `supabase/schema.sql`, edit the last lines
   (`insert into public.allowlist …`) with the e-mail addresses allowed on the board — yours first —
   then **Run**.
3. **SQL editor → New query**: paste `supabase/seed.sql` → **Run**. (38 rows inserted.)
4. **Authentication → Providers → Email**: leave it enabled (default); magic links work with the
   defaults. Anyone can *request* a link, but only allowlisted addresses can *see* anything — the
   allowlist protects the data, not the sign-in screen. (Supabase's built-in mailer is rate-limited
   to a few mails per hour; enough for a team of 15. If it becomes a problem, plug a custom SMTP
   under *Project settings → Authentication → SMTP*.)
5. **Authentication → URL configuration**:
   - *Site URL*: `https://<your-github-user>.github.io/<repo>/`
   - *Redirect URLs*: add the same URL (and `http://localhost:8000/` if you test locally).
6. **Project settings → API**: copy *Project URL* and *anon public* key into `config.js`.
   The anon key is public by design; the rules in `schema.sql` are what restrict access.

## 2. GitHub Pages (≈5 min)

1. Create a repository (private is fine — Pages still publishes the site; the data never lives in the repo).
2. Push these files to the `main` branch root.
3. **Settings → Pages → Build and deployment**: *Deploy from a branch*, branch `main`, folder `/ (root)`.
4. After a minute the board is at `https://<your-github-user>.github.io/<repo>/`.
   Custom domain (e.g. `board.pqe-consulting.com`) can be set in the same Pages screen if you want
   no "github" in the address either.

## 3. Inviting colleagues

- Add their e-mail to `public.allowlist` (SQL editor: `insert into public.allowlist(email) values ('name@crl.com');`
  or Table editor → allowlist → Insert row). Matching is case-insensitive.
- Send them the Pages URL. They type their e-mail, open the link from the mail **in the same browser**,
  and the board unlocks. Someone signed in but not on the list sees the board locked with a clear message.
- Remove access: delete the row. Their next page load is refused.

## What the rules guarantee (tested on Postgres 16 with the same SQL)

- Not on the allowlist → sees 0 cards, updates affect 0 rows (RLS, not UI).
- On the allowlist → full read/write; `updated_by` / `updated_at` stamped server-side from the sign-in e-mail.
- Every insert / update / delete lands in `card_history` with the full row as JSON — the audit trail
  (Table editor → card_history; export CSV when needed).
- Allowlist itself is invisible to the app users; only you (dashboard / service key) can see or edit it.
- Live updates: anyone with the board open sees moves/edits within ~1 s (Supabase Realtime on `cards`).

## Local test

```
python3 -m http.server 8000      # in this folder, then open http://localhost:8000/
```
(add `http://localhost:8000/` to the Supabase redirect URLs first).

## Exporting

SQL editor → `select * from cards order by layer, company;` → *Download CSV*; the columns match
the Excel I gave you (`ViAAS_Workshop_Action_Cards_Miro.xlsx`), so a round-trip to Azure DevOps or Miro
later is a plain import.
