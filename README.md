# faktron.com

Faktron's website and the AWS pieces under it. It lives in BTW's AWS account (`873310976934`,
signed in as `btw-admin`), tagged `project=faktron`, and shares nothing with BTW's stack except the
bucket its OpenTofu state sits in. `docs/adr/0001-the-site-on-cloudfront-with-the-form-on-a-lambda.md`
is why it is shaped this way; `docs/HOSTING.md` is how to run it.

## What is where

| What | Where |
|---|---|
| The site | `site/`: `index.html`, `contact/index.html`, `404.html`, `site.css`, `enquiry.js` and `assets/`. Plain HTML, no build. `enquiry.generated.js` is written by the deploy, never by hand |
| The enquiry form | `enquiry/handler.mjs`, a Lambda that emails `info@faktron.com` through SES; `handler.test.mjs` beside it |
| DNS | Route 53 zone `faktron.com` (`infra/main.tf`), copied from Vodien on 12 October 2026, with the bare domain and www at CloudFront |
| Mail | Google Workspace: one MX, `smtp.google.com`. `mail.` still names Vodien's old hosting |
| Hosting | S3 and CloudFront (`infra/site.tf`), the certificate from ACM |
| Deploy | `./deploy/site.sh` |
| Registration | Still with Vodien |

The design lives on the owner's design canvas ("Faktron brand site"); the pages here carry its
values by hand, so a change to the words or the look is made in both places.

## Running it

```sh
pnpm install          # once, for the tests
pnpm test             # the enquiry function
./deploy/site.sh      # the site, once the stack is applied (docs/HOSTING.md)
```

## Applying the stack

```sh
aws login --profile btw-admin --region ap-southeast-2
export AWS_PROFILE=btw-admin AWS_REGION=ap-southeast-2

cd infra
tofu init && tofu plan -out=faktron.tfplan && tofu apply faktron.tfplan
tofu output
```

Read every plan before applying it. The zone is `prevent_destroy`. The certificate and SES's DKIM
are proved through the zone, so the stack is applied after the nameservers have moved
(`docs/HOSTING.md`, in order).
