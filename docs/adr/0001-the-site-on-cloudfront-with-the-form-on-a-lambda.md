# ADR-0001, The site is static on S3 and CloudFront, with the form on a Lambda

## Context
Faktron's brand site was designed on the owner's design canvas (two pages, Home and Contact) to
replace the Figma Sites page at www.faktron.com, which Figma had already stopped serving. The owner
asked for it to go on faktron.com in BTW's AWS account (2026-10-12). The domain's zone was moved
into Route 53 in this repo first, as a copy of Vodien's records, with the nameserver switch left to
the owner at the registrar.

Two shapes were on the table: the site as a second Caddy site on BTW's box, synced down from S3 as
BTW's own brand site is, or the site on S3 behind CloudFront with nothing of BTW's touched. The
site has one dynamic part, the enquiry form, and neither shape has anything that sends email.

## Decision
1. **S3 and CloudFront, not BTW's box.** `site/` is plain HTML and CSS, exported from the canvas
   by hand with the design's own values. `deploy/site.sh` uploads it to a private, versioned bucket
   and invalidates the distribution; the bucket admits only the distribution. This shares nothing
   with BTW's box, compose file or Caddy, so BTW's repo needs no change, a BTW rebuild cannot take
   the site down, and the pages are served from every CloudFront edge, Sydney included.
2. **One distribution for the bare name and www.** A CloudFront Function sends www to faktron.com,
   turns a folder address into its `index.html`, and gives `/contact` its trailing slash, so every
   page has one address. The certificate is ACM's, in Virginia as CloudFront requires, proved by
   records in the zone. The managed security-headers policy sets HSTS and the rest.
3. **The enquiry form posts to a Lambda** (`enquiry/handler.mjs`) behind a function URL, which
   checks the fields and sends one email through SES to `info@faktron.com`, with the enquirer as
   the reply-to. The page calls it cross-origin, with CORS pinned to `https://faktron.com`; a hidden
   field catches bots. SES stays in the sandbox: the function sends from the domain to one verified
   inbox and nowhere else. The function's URL is the one generated file in the site, written by the
   deploy from the stack's output.
4. **The zone keeps what Vodien had, minus the wildcard.** The MX and `mail.` stay as copied; the
   bare domain and `www` become aliases of the distribution; SES's three DKIM records are added.
   The wildcard that answered every other name with Figma's address is dropped, since nothing named
   relied on it. SPF, DMARC and Google's DKIM are the owner's separate decision.
5. **The stack stays in this repo, in BTW's account, under its own state key**, applied as
   `btw-admin`. It is applied after the nameservers have moved, because the certificate and the
   DKIM records are proved through the zone.
6. **What a person does, not a script:** move the nameservers at Vodien, click SES's verification
   link in the inbox, and push the repo.

## Consequences
- The site costs about a dollar a month: the zone, cents of S3 and CloudFront, and a Lambda that
  mostly sleeps. It sits in BTW's account and budget, tagged `project=faktron`.
- A change to the site is a commit and `./deploy/site.sh`. A change to the function or the records
  is a commit and `tofu apply`. Nothing on BTW's side is involved.
- The enquiry emails are DKIM-signed by SES as faktron.com, so Google Workspace accepts them as the
  domain's own. If the site ever emails anyone other than the inbox, SES production access is a
  separate request to AWS.
- If Faktron ever leaves BTW's account, the zone, the bucket, the distribution and the function
  move together; nothing in the pages changes but the one generated file.
