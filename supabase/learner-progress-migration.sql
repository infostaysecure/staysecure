-- StaySecure learner progress and course awards (additive migration)
-- Run in Supabase SQL Editor after supabase/schema.sql.
-- Learners may read their own awards; browsers cannot insert or alter awards.

create table if not exists public.course_progress (
 user_id uuid not null references auth.users(id) on delete cascade,
 course_id uuid not null references public.content_items(id) on delete cascade,
 completed_lesson_ids uuid[] not null default '{}',
 last_lesson_id uuid references public.content_lessons(id) on delete set null,
 updated_at timestamptz not null default now(),
 primary key(user_id,course_id)
);
create table if not exists public.course_awards (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 course_id uuid not null references public.content_items(id) on delete cascade,
 award_code text not null,
 awarded_at timestamptz not null default now(),
 unique(user_id,course_id),
 unique(user_id,award_code)
);
alter table public.course_progress enable row level security;
alter table public.course_awards enable row level security;
drop policy if exists "Learners can read own course progress" on public.course_progress;
create policy "Learners can read own course progress" on public.course_progress for select to authenticated using(user_id=auth.uid() or public.is_staysecure_admin());
drop policy if exists "Learners can create own course progress" on public.course_progress;
create policy "Learners can create own course progress" on public.course_progress for insert to authenticated with check(user_id=auth.uid());
drop policy if exists "Learners can update own course progress" on public.course_progress;
create policy "Learners can update own course progress" on public.course_progress for update to authenticated using(user_id=auth.uid() or public.is_staysecure_admin()) with check(user_id=auth.uid() or public.is_staysecure_admin());
drop policy if exists "Learners can read own course awards" on public.course_awards;
create policy "Learners can read own course awards" on public.course_awards for select to authenticated using(user_id=auth.uid() or public.is_staysecure_admin());
-- No learner INSERT/UPDATE/DELETE policy is granted on course_awards.
-- Add server-verified assessment submission before enabling shield issuance.
