-- ViAAS Action Board – database schema. Run once in Supabase → SQL editor.
-- Tables: cards (the board), card_history (audit trail), allowlist (who may read/edit).

create table if not exists public.allowlist (
  email      text primary key,
  added_at   timestamptz not null default now()
);

create table if not exists public.cards (
  id          text primary key,
  title       text not null default '',
  layer       text not null,
  company     text not null,
  owner       text not null default '',
  follower    text not null default '',
  prio        text not null default 'P2'   check (prio in ('D','P1','P2','P3')),
  status      text not null default 'open' check (status in ('open','in progress','done','blocked')),
  due         text not null default '',
  deps        text[] not null default '{}',
  note        text not null default '',
  source      text not null default '',
  updated_at  timestamptz not null default now(),
  updated_by  text
);

create table if not exists public.card_history (
  hid         bigserial primary key,
  card_id     text not null,
  action      text not null,
  data        jsonb,
  changed_at  timestamptz not null default now(),
  changed_by  text
);

-- Who is an editor: any signed-in user whose e-mail is on the allowlist (case-insensitive).
create or replace function public.is_editor()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.allowlist
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
grant execute on function public.is_editor() to authenticated;

-- Audit trail + updated_by / updated_at stamping.
create or replace function public.cards_audit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    insert into public.card_history(card_id, action, data, changed_by)
    values (old.id, 'delete', to_jsonb(old), auth.jwt() ->> 'email');
    return old;
  end if;
  new.updated_at := now();
  new.updated_by := coalesce(auth.jwt() ->> 'email', 'seed');
  insert into public.card_history(card_id, action, data, changed_by)
  values (new.id, lower(tg_op), to_jsonb(new), new.updated_by);
  return new;
end $$;

drop trigger if exists cards_audit on public.cards;
create trigger cards_audit before insert or update or delete on public.cards
  for each row execute function public.cards_audit();

-- Row-level security: only allowlisted, signed-in users can read or change cards.
alter table public.cards        enable row level security;
alter table public.card_history enable row level security;
alter table public.allowlist    enable row level security;   -- no policy = only you (SQL editor / service role) can see it

drop policy if exists cards_editors on public.cards;
create policy cards_editors on public.cards
  for all to authenticated
  using (public.is_editor()) with check (public.is_editor());

drop policy if exists history_editors on public.card_history;
create policy history_editors on public.card_history
  for select to authenticated using (public.is_editor());

-- Live updates for everyone who has the board open.
alter publication supabase_realtime add table public.cards;

-- Editors: add one line per person (the e-mail they will sign in with).
insert into public.allowlist(email) values
  ('you@your-company.com')
on conflict do nothing;
