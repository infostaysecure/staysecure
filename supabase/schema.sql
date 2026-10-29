-- StaySecure content CMS schema (Supabase/Postgres)
-- Run in Supabase SQL Editor after creating a project.
-- After creating your own account, grant yourself admin with the final UPDATE below.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'learner' check (role in ('learner', 'admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.content_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('course', 'blog')),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title text not null,
  excerpt text not null default '',
  body text not null default '',
  category text not null default 'Security Basics',
  author text not null default 'StaySecure Team',
  access_tier text not null default 'free' check (access_tier in ('free', 'premium')),
  status text not null default 'draft' check (status in ('draft', 'published')),
  estimated_minutes integer not null default 5 check (estimated_minutes between 1 and 600),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.content_lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.content_items(id) on delete cascade,
  title text not null,
  body text not null default '',
  position integer not null default 1 check (position > 0),
  estimated_minutes integer not null default 10 check (estimated_minutes between 1 and 600),
  created_at timestamptz not null default now(),
  unique(course_id, position)
);

create index if not exists content_items_public_listing_idx
  on public.content_items (kind, status, access_tier, published_at desc);
create index if not exists content_lessons_course_position_idx
  on public.content_lessons (course_id, position);

create or replace function public.is_staysecure_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where user_id = auth.uid() and role = 'admin'
  );
$$;

alter table public.profiles enable row level security;
alter table public.content_items enable row level security;
alter table public.content_lessons enable row level security;

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
  on public.profiles for select
  to authenticated
  using (user_id = auth.uid() or public.is_staysecure_admin());

drop policy if exists "Users can create own learner profile" on public.profiles;
create policy "Users can create own learner profile"
  on public.profiles for insert
  to authenticated
  with check (user_id = auth.uid() and role = 'learner');

drop policy if exists "Admins can update profiles" on public.profiles;
create policy "Admins can update profiles"
  on public.profiles for update
  to authenticated
  using (public.is_staysecure_admin())
  with check (public.is_staysecure_admin());

drop policy if exists "Published free content is public" on public.content_items;
create policy "Published free content is public"
  on public.content_items for select
  to anon, authenticated
  using (status = 'published' and access_tier = 'free');

drop policy if exists "Admins can read all content" on public.content_items;
create policy "Admins can read all content"
  on public.content_items for select
  to authenticated
  using (public.is_staysecure_admin());

drop policy if exists "Admins can create content" on public.content_items;
create policy "Admins can create content"
  on public.content_items for insert
  to authenticated
  with check (public.is_staysecure_admin());

drop policy if exists "Admins can edit content" on public.content_items;
create policy "Admins can edit content"
  on public.content_items for update
  to authenticated
  using (public.is_staysecure_admin())
  with check (public.is_staysecure_admin());

drop policy if exists "Admins can delete content" on public.content_items;
create policy "Admins can delete content"
  on public.content_items for delete
  to authenticated
  using (public.is_staysecure_admin());

drop policy if exists "Published lessons for free courses are public" on public.content_lessons;
create policy "Published lessons for free courses are public"
  on public.content_lessons for select
  to anon, authenticated
  using (
    exists (
      select 1 from public.content_items c
      where c.id = course_id and c.kind = 'course'
        and c.status = 'published' and c.access_tier = 'free'
    )
  );

drop policy if exists "Admins can read all lessons" on public.content_lessons;
create policy "Admins can read all lessons"
  on public.content_lessons for select
  to authenticated
  using (public.is_staysecure_admin());

drop policy if exists "Admins can create lessons" on public.content_lessons;
create policy "Admins can create lessons"
  on public.content_lessons for insert
  to authenticated
  with check (public.is_staysecure_admin());

drop policy if exists "Admins can edit lessons" on public.content_lessons;
create policy "Admins can edit lessons"
  on public.content_lessons for update
  to authenticated
  using (public.is_staysecure_admin())
  with check (public.is_staysecure_admin());

drop policy if exists "Admins can delete lessons" on public.content_lessons;
create policy "Admins can delete lessons"
  on public.content_lessons for delete
  to authenticated
  using (public.is_staysecure_admin());

-- After you sign up in the app, find your user UUID in Supabase Authentication > Users,
-- then run this statement with your UUID to grant yourself editor access:
-- insert into public.profiles (user_id, display_name, role)
-- values ('YOUR-AUTH-USER-UUID', 'StaySecure Admin', 'admin')
-- on conflict (user_id) do update set role = 'admin', display_name = excluded.display_name;

-- Do not put a Supabase service-role key in any website file.
