-- Banca MIS – database setup for Supabase.
-- Run once in Supabase → SQL Editor. Running it again is safe: it only adds what is missing and replaces the functions.
-- Who sees what: admins see everything; everyone else sees only rows for the IMD / Sub IMD codes they are tagged to in the sales hierarchy.

-- ============================== tables ==============================
create table if not exists public.business(
  policy_key text primary key, issue_date date not null, prev_key text, imd_code text, sub_imd_code text,
  channel text, bank text, state text, zone text, location text, branch text, lob text, product text, business_type text,
  nop numeric, premium numeric, sum_assured numeric, policy_start date, policy_end date, sub_channel text, branch_code text,
  loaded_at timestamptz not null default now());
create index if not exists business_date_ix on public.business(issue_date);
create index if not exists business_code_ix on public.business(imd_code, sub_imd_code);
create index if not exists business_prev_ix on public.business(prev_key);

create table if not exists public.renewals(
  policy_key text primary key, expiry_date date not null, policy_ref text, imd_code text, sub_imd_code text,
  channel text, bank text, state text, zone text, location text, branch text, lob text, product text,
  premium numeric, sum_assured numeric, renewed_on date, renewed_premium numeric, branch_code text,
  loaded_at timestamptz not null default now());
create index if not exists renewals_date_ix on public.renewals(expiry_date);
create index if not exists renewals_code_ix on public.renewals(imd_code, sub_imd_code);

create table if not exists public.targets(
  id bigserial primary key, month text not null, imd_code text not null, sub_imd_code text, lob text, product text, aop numeric, adj_aop numeric);
create index if not exists targets_month_ix on public.targets(month);

create table if not exists public.sales_map(
  id bigserial primary key, imd_code text not null, sub_imd_code text not null default '', level int not null, email text not null, name text, seq int, title text);
create index if not exists sales_map_email_ix on public.sales_map(email);
create index if not exists sales_map_code_ix on public.sales_map(imd_code, sub_imd_code);

create table if not exists public.admins(email text primary key, name text, added_at timestamptz not null default now());
create table if not exists public.load_log(id bigserial primary key, at timestamptz not null default now(), by_email text, entry jsonb);

create table if not exists public.servicing(
  transaction_no text primary key, policy_key text, transaction_date date not null, transaction_type text, reason text,
  premium_change numeric, sum_assured_change numeric, policy_issue_date date, imd_code text, sub_imd_code text,
  bank text, lob text, product text, business_type text, loaded_at timestamptz not null default now());
create index if not exists servicing_date_ix on public.servicing(transaction_date);
create index if not exists servicing_code_ix on public.servicing(imd_code, sub_imd_code);

create table if not exists public.claims(
  claim_key text primary key, policy_key text, intimation_date date not null, loss_date date, claim_status text,
  paid_amount numeric, outstanding_amount numeric, settlement_date date, claim_type text, imd_code text, sub_imd_code text,
  bank text, lob text, product text, state text, business_type text, policy_issue_date date, loaded_at timestamptz not null default now());
create index if not exists claims_date_ix on public.claims(intimation_date);
create index if not exists claims_code_ix on public.claims(imd_code, sub_imd_code);

create table if not exists public.earned(
  id bigserial primary key, month text not null, imd_code text not null, sub_imd_code text, lob text, product text,
  business_type text, earned_premium numeric, earned_policies numeric);
create index if not exists earned_month_ix on public.earned(month);

create table if not exists public.people(
  email text primary key, emp_code text, name text, designation text, status text, date_of_joining date, exit_date date);

create table if not exists public.branches(
  row_key text primary key, bank text, branch_code text, branch_name text, city text, state text, bank_zone text,
  imd_code text, sub_imd_code text, branch_type text, branch_status text);

create table if not exists public.costs(
  id bigserial primary key, month text not null, imd_code text not null, lob text, product text,
  commission numeric, other_acquisition_cost numeric, operating_expense numeric);
create index if not exists costs_month_ix on public.costs(month);

-- ============================== who is signed in ==============================
create or replace function public.me() returns text language sql stable as $$
  select lower(coalesce(auth.jwt()->>'email', ''))
$$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select public.me() = 'mainak.adhikary@bajajgeneral.com' or exists(select 1 from public.admins a where a.email = public.me())
$$;
-- codes tagged to me: 'IMD|SUB' pairs, and IMDs tagged without a Sub IMD (whole IMD)
create or replace function public.my_pairs() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(distinct imd_code || '|' || sub_imd_code), '{}') from public.sales_map where email = public.me() and sub_imd_code <> ''
$$;
create or replace function public.my_whole() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(distinct imd_code), '{}') from public.sales_map where email = public.me() and sub_imd_code = ''
$$;
-- IMDs I see in full: tagged whole, or tagged to every Sub IMD of that IMD (targets set on an IMD show only to these people)
create or replace function public.my_full_imds() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(distinct i), '{}') from (
    select imd_code i from public.sales_map where email = public.me() and sub_imd_code = ''
    union
    select a.imd_code from
      (select imd_code, count(distinct sub_imd_code) n from public.sales_map where sub_imd_code <> '' group by imd_code) a
      join (select imd_code, count(distinct sub_imd_code) n from public.sales_map where email = public.me() and sub_imd_code <> '' group by imd_code) b
      on a.imd_code = b.imd_code and a.n = b.n) x
$$;
create or replace function public.my_people() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(distinct m.email), '{}') from public.sales_map m
   where m.imd_code = any(public.my_whole()) or (m.imd_code || '|' || m.sub_imd_code) = any(public.my_pairs())
$$;

-- ============================== row level security ==============================
alter table public.business  enable row level security;
alter table public.renewals  enable row level security;
alter table public.targets   enable row level security;
alter table public.sales_map enable row level security;
alter table public.admins    enable row level security;
alter table public.load_log  enable row level security;
alter table public.servicing enable row level security;
alter table public.claims    enable row level security;
alter table public.earned    enable row level security;
alter table public.people    enable row level security;
alter table public.branches  enable row level security;
alter table public.costs     enable row level security;

do $$
declare t text;
begin
  -- policy-level tables: my IMD (whole) or my exact IMD / Sub IMD pair
  foreach t in array array['business','renewals','servicing','claims'] loop
    execute format('drop policy if exists %1$s_read on public.%1$s', t);
    execute format($p$create policy %1$s_read on public.%1$s for select to authenticated using (
      (select public.is_admin()) or imd_code = any((select public.my_whole())::text[])
      or (coalesce(imd_code,'') || '|' || coalesce(sub_imd_code,'')) = any((select public.my_pairs())::text[]))$p$, t);
  end loop;
  -- tables set by IMD, optionally by Sub IMD: a Sub IMD row follows the pair rule, an IMD-only row needs the whole IMD
  foreach t in array array['targets','earned'] loop
    execute format('drop policy if exists %1$s_read on public.%1$s', t);
    execute format($p$create policy %1$s_read on public.%1$s for select to authenticated using (
      (select public.is_admin())
      or (coalesce(sub_imd_code,'') <> '' and (imd_code = any((select public.my_whole())::text[]) or (imd_code || '|' || sub_imd_code) = any((select public.my_pairs())::text[])))
      or (coalesce(sub_imd_code,'') = '' and imd_code = any((select public.my_full_imds())::text[])))$p$, t);
  end loop;
  -- every table: only admins write
  foreach t in array array['business','renewals','targets','sales_map','admins','load_log','servicing','claims','earned','people','branches','costs'] loop
    execute format('drop policy if exists %1$s_admin on public.%1$s', t);
    execute format('create policy %1$s_admin on public.%1$s for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()))', t);
  end loop;
end $$;

drop policy if exists sales_map_read on public.sales_map;
create policy sales_map_read on public.sales_map for select to authenticated using (
  email = (select public.me()) or imd_code = any((select public.my_whole())::text[]) or (imd_code || '|' || sub_imd_code) = any((select public.my_pairs())::text[]));
drop policy if exists costs_read on public.costs;
create policy costs_read on public.costs for select to authenticated using (imd_code = any((select public.my_full_imds())::text[]));
drop policy if exists people_read on public.people;
create policy people_read on public.people for select to authenticated using (email = (select public.me()) or email = any((select public.my_people())::text[]));
drop policy if exists branches_read on public.branches;
create policy branches_read on public.branches for select to authenticated using (true);

-- ============================== access for signed-in users only ==============================
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- ============================== helpers used by the dashboard ==============================
create or replace function public.csvq(v text) returns text language sql immutable as $$
  select case when v is null then '' when v ~ '[",\r\n]' then '"' || replace(v, '"', '""') || '"' else v end
$$;
create or replace function public.mis_cols(p_table text) returns text[] language sql immutable as $$
  select case p_table
    when 'business'  then array['issue_date','policy_key','prev_key','imd_code','sub_imd_code','channel','bank','state','zone','location','branch','lob','product','business_type','nop','premium','sum_assured','policy_start','policy_end','sub_channel','branch_code']
    when 'renewals'  then array['expiry_date','policy_key','policy_ref','imd_code','sub_imd_code','channel','bank','state','zone','location','branch','lob','product','premium','sum_assured','renewed_on','renewed_premium','branch_code']
    when 'targets'   then array['month','imd_code','sub_imd_code','lob','product','aop','adj_aop']
    when 'sales_map' then array['imd_code','sub_imd_code','level','email','name','seq','title']
    when 'admins'    then array['email','name']
    when 'servicing' then array['transaction_no','policy_key','transaction_date','transaction_type','reason','premium_change','sum_assured_change','policy_issue_date','imd_code','sub_imd_code','bank','lob','product','business_type']
    when 'claims'    then array['claim_key','policy_key','intimation_date','loss_date','claim_status','paid_amount','outstanding_amount','settlement_date','claim_type','imd_code','sub_imd_code','bank','lob','product','state','business_type','policy_issue_date']
    when 'earned'    then array['month','imd_code','sub_imd_code','lob','product','business_type','earned_premium','earned_policies']
    when 'people'    then array['email','emp_code','name','designation','status','date_of_joining','exit_date']
    when 'branches'  then array['row_key','bank','branch_code','branch_name','city','state','bank_zone','imd_code','sub_imd_code','branch_type','branch_status']
    when 'costs'     then array['month','imd_code','lob','product','commission','other_acquisition_cost','operating_expense']
  end
$$;
create or replace function public.mis_key(p_table text) returns text language sql immutable as $$
  select case p_table when 'business' then 'policy_key' when 'renewals' then 'policy_key' when 'servicing' then 'transaction_no'
    when 'claims' then 'claim_key' when 'people' then 'email' when 'branches' then 'row_key' end
$$;
create or replace function public.mis_datecol(p_table text) returns text language sql immutable as $$
  select case p_table when 'business' then 'issue_date' when 'renewals' then 'expiry_date' when 'servicing' then 'transaction_date' when 'claims' then 'intimation_date' end
$$;
create or replace function public.mis_need_admin() returns void language plpgsql stable as $$
begin if not public.is_admin() then raise exception 'Only an admin can load data.'; end if; end $$;

-- a table as CSV text (row level security applies, so each person gets only their rows)
create or replace function public.mis_csv(p_table text, p_from date default null, p_to date default null) returns text language plpgsql stable as $$
declare cols text[]; sel text; q text; res text; dcol text;
begin
  if p_table = 'sales_keys' then
    select 'imd_code,sub_imd_code' || E'\n' || coalesce(string_agg(public.csvq(imd_code) || ',' || public.csvq(sub_imd_code), E'\n'), '')
      into res from (select distinct imd_code, sub_imd_code from public.sales_map) k;
    return res;
  end if;
  cols := public.mis_cols(p_table);
  if cols is null then raise exception 'Unknown table %', p_table; end if;
  select string_agg(format('public.csvq(t.%I::text)', c), ' || '','' || ') into sel from unnest(cols) c;
  q := format('select %L || coalesce(string_agg(%s, E''\n''), '''') from public.%I t', array_to_string(cols, ',') || E'\n', sel, p_table);
  dcol := public.mis_datecol(p_table);
  if dcol is not null then q := q || format(' where ($1 is null or t.%1$I >= $1) and ($2 is null or t.%1$I <= $2)', dcol); end if;
  execute q into res using p_from, p_to;
  return res;
end $$;

-- the people already loaded for the given codes ('IMD|Sub IMD'), to show what a hierarchy load changes
create or replace function public.mis_map_for(p_pairs text[]) returns text language plpgsql stable as $$
declare res text;
begin
  perform public.mis_need_admin();
  select 'imd_code,sub_imd_code,level,email,name,seq,title' || E'\n' || coalesce(string_agg(
      public.csvq(imd_code) || ',' || public.csvq(sub_imd_code) || ',' || public.csvq(level::text) || ',' || public.csvq(email) || ','
      || public.csvq(name) || ',' || public.csvq(seq::text) || ',' || public.csvq(title), E'\n' order by imd_code, sub_imd_code, level, seq), '')
    into res from public.sales_map where (imd_code || '|' || sub_imd_code) = any(p_pairs);
  return res;
end $$;

-- months that have data (so the dashboard loads month by month)
create or replace function public.mis_meta() returns json language plpgsql stable as $$
declare r json; adm boolean := public.is_admin();
begin
  select json_build_object(
    'email', public.me(), 'is_admin', adm,
    'months_business',  (select coalesce(json_agg(m order by m), '[]') from (select distinct to_char(issue_date, 'YYYY-MM') m from public.business) x),
    'months_renewals',  (select coalesce(json_agg(m order by m), '[]') from (select distinct to_char(expiry_date, 'YYYY-MM') m from public.renewals) x),
    'months_servicing', (select coalesce(json_agg(m order by m), '[]') from (select distinct to_char(transaction_date, 'YYYY-MM') m from public.servicing) x),
    'months_claims',    (select coalesce(json_agg(m order by m), '[]') from (select distinct to_char(intimation_date, 'YYYY-MM') m from public.claims) x),
    'updated', (select to_char(max(at) at time zone 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI am') from public.load_log),
    'log', case when adm then (select coalesce(json_agg(entry order by at desc), '[]') from (select entry, at from public.load_log order by at desc limit 40) l) else '[]'::json end)
  into r;
  return r;
end $$;

create or replace function public.mis_by_keys(p_table text, p_keys text[]) returns text language plpgsql stable as $$
declare cols text[]; sel text; res text; k text;
begin
  perform public.mis_need_admin();
  cols := public.mis_cols(p_table); k := public.mis_key(p_table);
  if cols is null or k is null then raise exception 'Unknown table %', p_table; end if;
  select string_agg(format('public.csvq(t.%I::text)', c), ' || '','' || ') into sel from unnest(cols) c;
  execute format('select %L || coalesce(string_agg(%s, E''\n''), '''') from public.%I t where t.%I = any($1)', array_to_string(cols, ',') || E'\n', sel, p_table, k)
    into res using p_keys;
  return res;
end $$;

create or replace function public.mis_count_dates(p_table text, p_dates date[]) returns int language plpgsql stable as $$
declare n int; d text := public.mis_datecol(p_table);
begin
  perform public.mis_need_admin();
  if d is null then raise exception 'Unknown table %', p_table; end if;
  execute format('select count(*) from public.%I where %I = any($1)', p_table, d) into n using p_dates;
  return n;
end $$;

create or replace function public.mis_delete_dates(p_table text, p_dates date[]) returns int language plpgsql as $$
declare n int; d text := public.mis_datecol(p_table);
begin
  perform public.mis_need_admin();
  if d is null then raise exception 'Unknown table %', p_table; end if;
  execute format('delete from public.%I where %I = any($1)', p_table, d) using p_dates;
  get diagnostics n = row_count; return n;
end $$;

-- targets, earned premium and costs: the months in the file replace what was there
create or replace function public.mis_replace_months(p_table text, p_months text[], p_rows jsonb) returns int language plpgsql as $$
declare cols text[]; lst text; n int;
begin
  perform public.mis_need_admin();
  if p_table not in ('targets','earned','costs') then raise exception 'Unknown table %', p_table; end if;
  cols := public.mis_cols(p_table); lst := (select string_agg(format('%I', c), ',') from unnest(cols) c);
  execute format('delete from public.%I where month = any($1)', p_table) using p_months;
  execute format('insert into public.%1$I (%2$s) select %2$s from jsonb_populate_recordset(null::public.%1$I, $1)', p_table, lst) using p_rows;
  get diagnostics n = row_count; return n;
end $$;

-- sales hierarchy: the IMD / Sub IMD codes in the file replace what was there for those codes
create or replace function public.mis_replace_map(p_pairs text[], p_rows jsonb, p_fresh boolean) returns int language plpgsql as $$
declare n int;
begin
  perform public.mis_need_admin();
  if p_fresh then delete from public.sales_map;
  else delete from public.sales_map where (imd_code || '|' || sub_imd_code) = any(p_pairs); end if;
  insert into public.sales_map(imd_code, sub_imd_code, level, email, name, seq, title)
    select imd_code, coalesce(sub_imd_code, ''), level, lower(email), name, seq, title
      from jsonb_populate_recordset(null::public.sales_map, p_rows);
  get diagnostics n = row_count; return n;
end $$;

create or replace function public.mis_set_admins(p_add jsonb, p_remove text[]) returns int language plpgsql as $$
begin
  perform public.mis_need_admin();
  insert into public.admins(email, name) select lower(email), name from jsonb_populate_recordset(null::public.admins, p_add)
    on conflict (email) do update set name = excluded.name;
  delete from public.admins where email = any(p_remove) and email <> 'mainak.adhikary@bajajgeneral.com';
  return (select count(*) from public.admins);
end $$;

create or replace function public.mis_clear_all() returns void language plpgsql as $$
begin
  perform public.mis_need_admin();
  delete from public.business; delete from public.renewals; delete from public.targets; delete from public.sales_map;
  delete from public.servicing; delete from public.claims; delete from public.earned; delete from public.costs;
  delete from public.people; delete from public.branches;
end $$;

-- a due policy is renewed when a business row names it as the previous policy
create or replace function public.mis_match_renewals() returns int language plpgsql as $$
declare n int;
begin
  perform public.mis_need_admin();
  update public.renewals r set renewed_on = b.issue_date, renewed_premium = b.premium
    from (select distinct on (prev_key) prev_key, issue_date, premium from public.business where prev_key is not null and prev_key <> '' order by prev_key, issue_date) b
   where b.prev_key = r.policy_key and r.renewed_on is null;
  get diagnostics n = row_count; return n;
end $$;

create or replace function public.mis_log(p_entry jsonb) returns void language plpgsql as $$
begin
  perform public.mis_need_admin();
  insert into public.load_log(by_email, entry) values (public.me(), p_entry);
end $$;

-- ============================== who may get a sign-in code ==============================
-- Supabase → Authentication → Hooks → "Before user created" → this function.
-- Only emails in the sales hierarchy or the admin list can create a sign-in.
create or replace function public.hook_before_user_created(event jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare e text := lower(coalesce(event->'user'->>'email', ''));
begin
  if e = 'mainak.adhikary@bajajgeneral.com' or exists(select 1 from public.admins where email = e) or exists(select 1 from public.sales_map where email = e) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', 'This email is not set up for the Banca MIS.'));
end $$;

-- ============================== function access ==============================
do $$
declare f text;
begin
  foreach f in array array['me()','is_admin()','my_pairs()','my_whole()','my_full_imds()','my_people()','csvq(text)','mis_cols(text)','mis_key(text)','mis_datecol(text)','mis_need_admin()',
    'mis_csv(text,date,date)','mis_meta()','mis_by_keys(text,text[])','mis_map_for(text[])','mis_count_dates(text,date[])','mis_delete_dates(text,date[])','mis_replace_months(text,text[],jsonb)',
    'mis_replace_map(text[],jsonb,boolean)','mis_set_admins(jsonb,text[])','mis_clear_all()','mis_match_renewals()','mis_log(jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
revoke execute on function public.hook_before_user_created(jsonb) from public, anon, authenticated;
grant execute on function public.hook_before_user_created(jsonb) to supabase_auth_admin;
grant usage on schema public to supabase_auth_admin;

insert into public.admins(email, name) values ('mainak.adhikary@bajajgeneral.com', 'Mainak Adhikary') on conflict (email) do nothing;
