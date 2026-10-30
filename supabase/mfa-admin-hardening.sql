-- StaySecure admin MFA enforcement
-- Run this in Supabase SQL Editor after deploying the MFA-enabled admin page.
-- Admin reads/writes that use is_staysecure_admin() require an MFA-verified AAL2 session.
-- Public published-free content policies are unchanged.

create or replace function public.is_staysecure_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
    and exists (
      select 1
      from public.profiles
      where user_id = auth.uid()
        and role = 'admin'
    );
$$;

revoke all on function public.is_staysecure_admin() from public;
grant execute on function public.is_staysecure_admin() to anon, authenticated;
