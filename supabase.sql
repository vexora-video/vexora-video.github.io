-- Vexora video platform schema.
-- Run once in Supabase Dashboard -> SQL Editor using the project owner account.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'Member',
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 160),
  description text not null default '' check (char_length(description) <= 2000),
  category text not null check (char_length(category) between 1 and 40),
  thumbnail_url text,
  source_type text not null check (source_type in ('url', 'upload')),
  video_url text,
  storage_path text unique,
  is_locked boolean not null default false,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint videos_source_matches_type check (
    (source_type = 'url' and video_url is not null and storage_path is null)
    or (source_type = 'upload' and video_url is null and storage_path is not null)
  )
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Member'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists create_profile_after_signup on auth.users;
create trigger create_profile_after_signup
after insert on auth.users
for each row execute procedure public.create_profile_for_new_user();

alter table public.profiles enable row level security;
alter table public.videos enable row level security;

drop policy if exists "Profiles visible to owner and admins" on public.profiles;
create policy "Profiles visible to owner and admins"
on public.profiles for select
to authenticated
using (id = auth.uid() or public.is_admin());

drop policy if exists "Admins manage profile roles" on public.profiles;
create policy "Admins manage profile roles"
on public.profiles for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Read public videos and member videos when signed in" on public.videos;
create policy "Read public videos and member videos when signed in"
on public.videos for select
to anon, authenticated
using (not is_locked or auth.uid() is not null);

drop policy if exists "Admins add videos" on public.videos;
create policy "Admins add videos"
on public.videos for insert
to authenticated
with check (public.is_admin() and created_by = auth.uid());

drop policy if exists "Admins update videos" on public.videos;
create policy "Admins update videos"
on public.videos for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins delete videos" on public.videos;
create policy "Admins delete videos"
on public.videos for delete
to authenticated
using (public.is_admin());

grant select on public.profiles to authenticated;
grant update on public.profiles to authenticated;
grant select on public.videos to anon, authenticated;
grant insert, update, delete on public.videos to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'videos-private',
  'videos-private',
  false,
  52428800,
  array['video/mp4', 'video/webm', 'video/ogg', 'video/quicktime']
)
on conflict (id) do update
set public = false,
    file_size_limit = 52428800,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Read video files allowed by video access" on storage.objects;
create policy "Read video files allowed by video access"
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'videos-private'
  and exists (
    select 1
    from public.videos
    where storage_path = name
      and (not is_locked or auth.uid() is not null)
  )
);

drop policy if exists "Admins upload video files for their video entries" on storage.objects;
create policy "Admins upload video files for their video entries"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'videos-private'
  and public.is_admin()
  and exists (
    select 1 from public.videos
    where storage_path = name and created_by = auth.uid()
  )
);

drop policy if exists "Admins update video files" on storage.objects;
create policy "Admins update video files"
on storage.objects for update
to authenticated
using (bucket_id = 'videos-private' and public.is_admin())
with check (bucket_id = 'videos-private' and public.is_admin());

drop policy if exists "Admins delete video files" on storage.objects;
create policy "Admins delete video files"
on storage.objects for delete
to authenticated
using (bucket_id = 'videos-private' and public.is_admin());

-- Bootstrap the first administrator only after registering that account on the site.
-- Replace the email below with the exact account email, then run this separately:
-- update public.profiles
-- set role = 'admin'
-- where id = (select id from auth.users where lower(email) = lower('you@example.com'));
