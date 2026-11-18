# Frame

Frame is a static video site backed by Supabase Auth, Postgres, and private Storage. The website is published with GitHub Pages; user accounts, roles, video metadata, and upload access are enforced by Supabase Row Level Security (RLS).

## Set up the backend

1. In the Supabase project, open **SQL Editor**, paste in [`supabase.sql`](./supabase.sql), and run it.
2. In **Authentication → URL Configuration**, set the Site URL to:

   `https://victor-m27.github.io/frame-video-site/`

   Add that URL as a redirect URL as well. Keep email confirmation enabled if you want users to verify ownership of their email before signing in.
3. Open the public site, create your account, and confirm the email if requested.
4. In Supabase SQL Editor, replace the example email with your account email and run the administrator bootstrap statement at the bottom of `supabase.sql`. Reload the site. Admin Studio will then be available.
5. Use Admin Studio to add videos, lock or unlock them, and assign trusted users the admin role.

The site uses only the Supabase project URL and publishable key in the browser. Those are public values; RLS policies are what protect data and actions. Never put a Supabase `secret` or `service_role` key in this repository or website.

## Video access

- Unlocked video records are visible to everyone. Locked records and their uploaded files require a signed-in account; only admins can add videos, change locks, or manage roles.
- Uploaded files use the private `videos-private` bucket and are limited to 50 MB. Playback links are temporary signed URLs.
- When adding a video, Frame captures a small JPEG thumbnail from the video if no thumbnail URL is supplied. This works for uploaded files and for external links that allow cross-origin frame capture; otherwise, provide a thumbnail URL.
- A direct external video URL is not access-controlled by Frame. Anyone with that external URL may be able to watch it outside the site. Already-issued signed upload links can also remain usable until they expire.
- Use direct HTTPS video-file URLs (for example MP4 or WebM), not YouTube watch-page URLs.

If the site reports a database setup error, verify the SQL ran successfully and that the browser URL and publishable key in `index.html` match the same Supabase project.
