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


-- Starter content: free launch courses and blog articles. Safe to re-run by slug.
insert into public.content_items
  (kind, slug, title, excerpt, category, author, access_tier, status, estimated_minutes, published_at, body)
values
('course','cybersecurity-fundamentals','Cybersecurity Fundamentals','Learn the everyday habits that protect your accounts, devices, and personal information.','Cybersecurity Fundamentals','StaySecure Team','free','published',45,now(),
'## What you will learn

This beginner-friendly course introduces the core ideas behind personal cybersecurity. You will learn to recognize common risks, choose safer account settings, keep devices updated, and respond calmly when something seems suspicious.

## Learning objectives

- Explain confidentiality, integrity, and availability in plain language.
- Build a stronger password and multi-factor authentication routine.
- Recognize common signs of phishing and social engineering.
- Know what to do after a suspected account compromise.

## Before you begin

Think about the accounts and devices you use every day. As you work through the lessons, choose one practical change you can make today.'),
('course','phishing-and-online-scams','Phishing & Online Scams','Practice spotting suspicious messages, fake login pages, and pressure tactics before you click.','Threat Awareness','StaySecure Team','free','published',35,now(),
'## What you will learn

Phishing messages try to make you act quickly, reveal information, open an attachment, or visit a deceptive website. They can arrive by email, text, phone, social media, or collaboration tools.

## Learning objectives

- Spot mismatched sender addresses and unexpected requests.
- Check links safely without opening suspicious destinations.
- Verify payment, password, and sensitive-data requests through a separate trusted channel.
- Report suspicious messages and recover safely if you clicked.

## Key principle

Pause before acting. Urgency, secrecy, fear, and unexpected rewards are common pressure tactics, not proof that a message is genuine.'),
('blog','strong-passwords-and-passkeys','Stronger Passwords: Password Managers and Passkeys','Learn how unique passwords, password managers, and passkeys reduce the risk of account takeover.','Everyday Security','StaySecure Team','free','published',6,now(),
'## Use a unique password for every account

Password reuse lets an attacker use credentials stolen from one site to try to access another. A password manager can create and store long, unique passwords so you do not have to memorize them all.

## Turn on multi-factor authentication

Use an authenticator app, security key, or passkey where supported. Protect your email account especially carefully because it can be used to reset other passwords.

## What about passkeys?

Passkeys can replace passwords on supported services and are designed to resist common phishing attacks. Create them only through the legitimate service and keep your account recovery options current.

## Start today

Choose your most important account, replace any reused password, enable multi-factor authentication, and save recovery codes somewhere secure.'),
('blog','spot-phishing-messages','How to Spot a Phishing Message','A practical checklist for recognizing suspicious email, texts, and direct messages.','Threat Awareness','StaySecure Team','free','published',5,now(),
'## Look for the context

Were you expecting the message? Does the request make sense for the sender? A familiar display name alone does not prove the message is legitimate.

## Check the details

Watch for unusual sender addresses, unexpected attachments, look-alike domains, and links that do not match the claimed destination. Spelling mistakes can occur, but polished writing is not proof of safety either.

## Verify separately

Do not use the contact details or links in a suspicious message. Visit the organization through a known bookmark or official app, or call a trusted number you already have.

## If you clicked

Close the page, do not enter more information, and report the message. If you submitted a password, change it from a trusted device and review multi-factor authentication and active sessions.'),
('blog','multi-factor-authentication-guide','Multi-Factor Authentication: A Practical Guide','Add another layer of protection to important accounts and learn which methods to prefer.','Security Basics','StaySecure Team','free','published',6,now(),
'## Why MFA helps

Multi-factor authentication asks for another proof of identity beyond a password. It can reduce the damage caused by stolen or reused passwords.

## Prefer stronger options when available

Passkeys and hardware security keys offer strong phishing resistance. Authenticator apps are generally preferable to SMS when those stronger options are unavailable. Any MFA is usually better than relying on a password alone.

## Set it up safely

Start with your email, financial, and work accounts. Follow the service’s official security settings, save recovery codes securely, and review which devices and methods are registered.

## Watch for push fatigue

Do not approve an authentication prompt you did not initiate. Repeated unexpected prompts can mean someone knows your password.'),
('blog','secure-your-phone-and-computer','Simple Ways to Secure Your Phone and Computer','Updates, screen locks, backups, and app hygiene make a meaningful difference.','Device Security','StaySecure Team','free','published',5,now(),
'## Keep software current

Enable automatic updates for your operating system, browser, and frequently used apps. Updates often fix security weaknesses.

## Use a screen lock

Set a strong PIN or password and enable the device’s built-in biometric unlock if appropriate. Configure automatic locking and device-finding features.

## Install apps carefully

Use official app stores or vendor websites, check the publisher, and remove apps you no longer need. Be cautious with unexpected browser extensions.

## Back up important data

Maintain a backup that is protected from accidental deletion and ransomware. Periodically confirm that you can restore important files.'),
('blog','avoid-online-shopping-scams','How to Avoid Online Shopping and Payment Scams','A few checks can help you avoid fake stores, fraudulent payment requests, and too-good-to-be-true offers.','Scam Awareness','StaySecure Team','free','published',5,now(),
'## Check the seller

Search for independent information about the business, review return policies, and look for signs that a site has copied another brand. A padlock in the browser only indicates an encrypted connection; it does not prove the seller is trustworthy.

## Use safer payment methods

Prefer payment methods with dispute protections. Be cautious when a seller insists on gift cards, cryptocurrency, wire transfers, or other hard-to-reverse payments.

## Resist urgency

Unexpected countdowns, unusually low prices, and pressure to pay immediately deserve extra scrutiny. Compare the offer with the official seller.

## If something goes wrong

Contact your payment provider promptly, change any password you reused, and report the listing or message through the relevant platform.')
on conflict (slug) do nothing;

insert into public.content_lessons (course_id,title,body,position,estimated_minutes)
select c.id, l.title, l.body, l.position, l.minutes
from public.content_items c
cross join (values
  ('cybersecurity-fundamentals','Start with the security basics',
   'Cybersecurity is the practice of protecting accounts, devices, networks, and information. A useful starting point is to reduce avoidable risk: keep software updated, use unique passwords, enable multi-factor authentication, and think before responding to unexpected requests.',1,10),
  ('cybersecurity-fundamentals','Protect your accounts and devices',
   'Use a password manager to generate unique passwords. Enable multi-factor authentication, beginning with email and financial accounts. Install updates promptly, lock your devices, and maintain backups of important files.',2,12),
  ('cybersecurity-fundamentals','Recognize threats and respond',
   'Pause when a message creates urgency or asks for secrets or payment. Verify the request through a separate trusted channel. If you think an account is compromised, change its password from a trusted device, revoke unknown sessions, and contact the provider.',3,12),
  ('phishing-and-online-scams','Spot the warning signs',
   'Look at the sender and the context, not just the display name. Unexpected attachments, look-alike domains, unusual requests, and pressure to act quickly deserve caution. Attackers can write polished messages, so grammar alone is not a reliable test.',1,10),
  ('phishing-and-online-scams','Verify links and requests',
   'Avoid clicking links in unexpected messages. Open the official app or type a known address yourself. Confirm payment or sensitive-data requests by contacting the person or organization through a separate trusted method.',2,10),
  ('phishing-and-online-scams','Report and recover safely',
   'Report suspicious messages using your organization’s process or the service’s built-in tools. If you entered a password, change it from a trusted device, change any reused passwords, review account sessions, and enable multi-factor authentication.',3,10)
) as l(slug,title,body,position,minutes)
where c.slug = l.slug and c.kind = 'course'
  and not exists (select 1 from public.content_lessons old where old.course_id = c.id and old.position = l.position);

insert into public.content_items
  (kind, slug, title, excerpt, category, author, access_tier, status, estimated_minutes, published_at, body)
values
('blog','protect-your-personal-information','Protecting Your Personal Information Online','Review privacy settings, limit oversharing, and reduce the amount of personal data exposed online.','Privacy Basics','StaySecure Team','free','published',5,now(),
'## Share less by default

Personal details can help scammers make convincing messages or attempt account recovery. Review what is public on social profiles and avoid posting information such as travel plans, full birth dates, or answers to common security questions.

## Review app permissions

Check which apps can access your location, contacts, microphone, camera, and photos. Turn off permissions that are not needed for the app to work.

## Watch for unexpected data requests

Before sharing personal or financial information, confirm why it is needed and whether the request is legitimate. Use official websites and trusted contact channels.

## Make privacy a habit

Review privacy settings periodically, remove unused accounts, and use unique passwords with multi-factor authentication on important services.')
on conflict (slug) do nothing;
