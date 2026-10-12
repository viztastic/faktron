# Hosting

Faktron's site is static files on S3 behind CloudFront, an enquiry function on Lambda, and the
domain and mail identities in Route 53 and SES, all in BTW's AWS account and all in OpenTofu under
`infra/` (ADR-0001). Everything signs in as BTW's `btw-admin` profile: `aws login --profile
btw-admin` first when a session has expired.

| What | Where |
|---|---|
| The site | `https://faktron.com` (www. is sent to it): `site/`, served by CloudFront from the site bucket |
| The enquiry form | posts to the function URL in `site/enquiry.generated.js` (`tofu output enquiry_url`); the function emails `info@faktron.com` through SES |
| The stack | `infra/`, state at `s3://btw-tfstate-<account>-apse2/faktron/terraform.tfstate` |
| The site's files | `s3://faktron-site-<account>-apse2/` (versioned, thirty days) |
| The function's logs | CloudWatch `/aws/lambda/faktron-enquiry`, thirty days |
| The domain | `faktron.com`'s zone in Route 53 (`infra/main.tf`); the registration is with Vodien |

Tools: the AWS CLI v2, OpenTofu 1.10 or later, Node 22, and `pnpm install` once for the tests.

## Going live, in order

The order matters: the certificate and SES's DKIM are proved through records in the zone, and
the zone only answers for the domain once the nameservers point at it.

1. **Move the nameservers at Vodien.** `tofu -chdir=infra output name_servers` gives the four
   names; replace `ns1/ns2/ns3.vodien.com` with them in Vodien's panel. Mail keeps working through
   the switch because the MX is the same on both sides. Vodien's answers stay cached for up to four
   hours. Check with `dig NS faktron.com` (or `nslookup -type=NS faktron.com`) until the four
   `awsdns` names come back.

2. **Apply the stack.**

   ```sh
   export AWS_PROFILE=btw-admin AWS_REGION=ap-southeast-2
   cd infra
   tofu init && tofu plan -out=faktron.tfplan && tofu apply faktron.tfplan
   tofu output
   ```

   Read the plan before applying it. On top of the zone it makes the site bucket, the certificate
   (it waits for the proof, a few minutes once the zone answers), the distribution, the function
   and its URL, and the two SES identities; the bare domain and `www` become aliases of the
   distribution, and the wildcard goes. SES emails `info@faktron.com` a verification link at once.

3. **Click SES's link** in the info@faktron.com inbox. Until then SES refuses the function's
   emails (the account is in SES's sandbox, which only delivers to verified addresses).

4. **Deploy the site.**

   ```sh
   ./deploy/site.sh
   ```

   It writes `site/enquiry.generated.js` from the stack, uploads `site/`, invalidates CloudFront,
   and asks the distribution's own name for the page, then the domain's.

5. **Send one enquiry from the live form** and see it arrive in the inbox with the enquirer as the
   reply-to. The function's log group has the rest.

## Deploying a change

- The pages, the stylesheet or a picture: commit, then `./deploy/site.sh`.
- The enquiry function: `pnpm test`, commit, then `cd infra && tofu plan -out=faktron.tfplan &&
  tofu apply faktron.tfplan` (the zip is built from `enquiry/handler.mjs` on every plan).
- The domain's records, or where enquiries go (`enquiry_to` in `infra/main.tf`; the new inbox gets
  SES's link to click): edit, plan, apply.

## Putting the site back

The site bucket is versioned. The simplest way back is to check out the earlier commit and run
`./deploy/site.sh`. For a single file, restore its previous version in S3 (console or
`aws s3api list-object-versions`) and invalidate:

```sh
aws cloudfront create-invalidation --profile btw-admin --distribution-id "$(tofu -chdir=infra output -raw distribution_id)" --paths "/*"
```

## What was there before

Until the nameservers move, `www.faktron.com` still names the Figma Sites page, which Figma no
longer serves, and the bare domain names Vodien's parking host. After they move, both are the new
site. Vodien's own record list is worth a glance while in the panel: the zone carries what could be
found by asking Vodien's nameserver name by name (the MX, `mail.`, the wildcard, the Figma CNAME),
and a record nobody guessed, a Google verification TXT most likely, would need adding to
`infra/main.tf`.
