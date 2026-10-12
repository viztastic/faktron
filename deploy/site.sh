#!/usr/bin/env bash
#
# Puts the site (site/) live, then checks it answers (ADR-0001).
#
#   ./deploy/site.sh
#
# The files go to the site bucket (infra/site.tf; versioned, so a bad upload can be put back for
# thirty days), CloudFront is told to drop what it cached, and the distribution's own name is
# asked for the page. Before anything goes, the one generated file is written fresh from the
# stack: where the contact form posts. Every call signs in as BTW's btw-admin profile.
set -euo pipefail
cd "$(dirname "$0")/.."

export MSYS_NO_PATHCONV=1   # Git Bash on Windows rewrites anything path-like on its way to aws.exe
AWS_PROFILE="${AWS_PROFILE:-btw-admin}"
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
export AWS_PROFILE AWS_REGION

say()  { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok()   { printf '  ok    %-24s %s\n' "$1" "${2:-}"; }
fail() { printf '\033[31mREFUSING: %s\033[0m\n' "$1" >&2; exit 1; }
output() { tofu -chdir=infra output -raw "$1" 2>/dev/null || fail "infra has no output '$1'; apply the stack first (docs/HOSTING.md)"; }

say "Checking what this needs"
git diff --quiet HEAD -- site || fail "site/ has uncommitted changes; what goes up is a commit"
command -v aws >/dev/null || fail "the AWS command line is not on this machine"
command -v tofu >/dev/null || fail "tofu is not on this machine; the stack's outputs say where the site goes"
command -v node >/dev/null || fail "node is not on this machine"
aws sts get-caller-identity --query Account --output text >/dev/null 2>&1 \
  || fail "not signed in to AWS as $AWS_PROFILE. Run: aws login --profile $AWS_PROFILE"
SITE_BUCKET="$(output site_bucket)"
DISTRIBUTION_ID="$(output distribution_id)"
CLOUDFRONT_DOMAIN="$(output cloudfront_domain)"
ENQUIRY_URL="$(output enquiry_url)"
[[ "$ENQUIRY_URL" == https://*.lambda-url.*.on.aws/ ]] || fail "enquiry_url does not look like a function URL: $ENQUIRY_URL"
ok "bucket" "s3://$SITE_BUCKET"
ok "distribution" "$DISTRIBUTION_ID ($CLOUDFRONT_DOMAIN)"
ok "enquiries" "$ENQUIRY_URL"

say "Writing site/enquiry.generated.js"
printf '%s\n' '// Written by deploy/site.sh from `tofu output -raw enquiry_url`; not committed.' \
  "window.faktronEnquiry = { url: $(node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$ENQUIRY_URL") }" \
  > site/enquiry.generated.js
ok "enquiry.generated.js" "points at the function"

say "Uploading site/"
site="$(cygpath -m "$PWD/site" 2>/dev/null || echo site)"
# Pictures and the logo may sit in a browser for a day; the pages and the stylesheet for five
# minutes, so an edit shows soon even where the invalidation below has not reached.
aws s3 sync --delete --only-show-errors --cache-control "public, max-age=86400" "$site/assets" "s3://$SITE_BUCKET/assets"
aws s3 sync --delete --only-show-errors --exclude "assets/*" --cache-control "public, max-age=300" "$site" "s3://$SITE_BUCKET"
ok "uploaded" "$(find site -type f | wc -l | tr -d ' ') files"

say "Telling CloudFront to forget what it cached"
invalidation="$(aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/*" --query Invalidation.Id --output text)"
aws cloudfront wait invalidation-completed --distribution-id "$DISTRIBUTION_ID" --id "$invalidation"
ok "invalidation" "$invalidation, done"

say "Checking it answers"
# The distribution's own name answers whether or not the domain's nameservers have moved yet.
if curl -fsS --max-time 10 "https://$CLOUDFRONT_DOMAIN/" | grep -q 'Designed'; then
  ok "https://$CLOUDFRONT_DOMAIN/" "the page"
else
  fail "https://$CLOUDFRONT_DOMAIN/ did not answer with the page"
fi
if curl -fsS --max-time 10 "https://faktron.com/" 2>/dev/null | grep -q 'Designed'; then
  ok "https://faktron.com/" "the page"
else
  printf '  note  https://faktron.com/ did not answer with the page yet; the nameservers may still be settling\n'
fi
