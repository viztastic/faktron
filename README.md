# faktron.com

Faktron's website and the AWS pieces under it. It lives in BTW's AWS account (`873310976934`,
signed in as `btw-admin`), tagged `project=faktron`, and shares nothing with BTW's stack except the
bucket its OpenTofu state sits in.

## What is where

| What | Where |
|---|---|
| DNS | Route 53 zone `faktron.com` (`infra/main.tf`), copied from Vodien on 12 October 2026 |
| Mail | Google Workspace: one MX, `smtp.google.com`. `mail.` still names Vodien's old hosting |
| The site | Not yet moved. The bare domain, www and the wildcard still point at Figma Sites, which no longer serves the domain |
| Registration | Still with Vodien; moving to Route 53 Domains once the nameservers have settled |

## Applying

```sh
aws login --profile btw-admin --region ap-southeast-2
export AWS_PROFILE=btw-admin AWS_REGION=ap-southeast-2

cd infra
tofu init && tofu plan -out=faktron.tfplan && tofu apply faktron.tfplan
tofu output name_servers
```

Read every plan before applying it. The zone is `prevent_destroy`.
