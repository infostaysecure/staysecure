# StaySecure preview

This branch is a development preview. It is not the production website and does not change staysecure.com.

## Content Studio setup

The private editor is `admin.html`. It uses Supabase Auth and Postgres so drafts and published content persist across devices.

1. Create a Supabase project on the free tier.
2. Open **SQL Editor** in Supabase and run all of `supabase/schema.sql`.
3. Open **Project Settings → API** (or the project's API keys page) and copy the Project URL and the publishable key (or legacy anon key). Never use the `service_role` / secret key in browser code.
4. In `supabase/config.js`, replace the two placeholder values. Alternatively, enter the URL and public key directly in the editor; those values are saved only in your current browser.
5. Deploy this branch to a Cloudflare Pages preview or test it on a local static web server. Open `admin.html`, connect, then sign up your admin user using Supabase Authentication. For the first admin, you can temporarily enable sign-up in Supabase Auth and create your account through a Supabase Auth client or dashboard-supported invite.
6. In Supabase **Authentication → Users**, copy your account UUID. In SQL Editor run:
   ```sql
   insert into public.profiles (user_id, display_name, role)
   values ('YOUR-AUTH-USER-UUID', 'StaySecure Admin', 'admin')
   on conflict (user_id) do update set role = 'admin', display_name = excluded.display_name;
   ```
7. Return to `admin.html`, sign in. Only a profile with role `admin` can create or publish content.
8. Create a course or blog post as a draft, preview it, and publish when ready. The current editor supports content items and ordered lessons.

## Important current limitations

- The editor is an initial CMS foundation. The public homepage still has showcase cards; public dynamic course/blog listing and full lesson-reader pages are the next integration step.
- Premium items are not exposed by the public read policy. Do not sell premium content until authentication entitlements and payment webhooks have been implemented and tested.
- Do not put a Supabase service-role key or Stripe secret key in any browser file.
- Free-tier Supabase projects have usage limits and may pause during extended inactivity. Review current plan details before launch.
- Keep production DNS and the current `staysecure.com` hosting untouched until you explicitly approve a tested launch.
