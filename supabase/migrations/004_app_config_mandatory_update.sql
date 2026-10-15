-- Mandatory app update gate (applied to Supabase as migration "app_config_mandatory_update")
create table if not exists public.app_config (
  platform text primary key,
  min_version_code integer not null default 1,
  latest_version_name text,
  update_url text,
  message text,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

drop policy if exists "app_config_public_read" on public.app_config;
create policy "app_config_public_read"
  on public.app_config
  for select
  to anon, authenticated
  using (true);

create or replace function public.app_config_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists app_config_touch on public.app_config;
create trigger app_config_touch
  before update on public.app_config
  for each row execute function public.app_config_touch_updated_at();

insert into public.app_config (platform, min_version_code, latest_version_name, update_url, message)
values (
  'android',
  1,
  '2.9.0',
  'https://play.google.com/store/apps/details?id=com.syncdub.livedub',
  'SyncDub AI का नया version आ गया है। App चलाने के लिए update करना ज़रूरी है।'
)
on conflict (platform) do nothing;

-- To force an update later (blocks every build below this versionCode):
-- update public.app_config set min_version_code = 8, latest_version_name = '3.0.0' where platform = 'android';
