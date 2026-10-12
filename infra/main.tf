# faktron.com in Route 53, and the providers everything else here uses.
#
# The zone started as a copy of what Vodien served on 12 October 2026 (found by asking Vodien's own
# nameserver for each name), so moving the nameservers changes nothing anybody relies on: Google
# Workspace mail keeps its MX, and mail. still names Vodien's old hosting. The bare domain and www
# now point at the site's CloudFront distribution (site.tf); the wildcard Vodien answered every
# other name with is gone, since nothing named relied on it (ADR-0001).
#
# Nothing here moves the nameservers. That is done at the registrar, by a person, once the zone's
# records have been checked against Vodien's own list.

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      project    = "faktron"
      managed_by = "opentofu"
    }
  }
}

# CloudFront only accepts certificates made in Virginia, wherever the viewers are.
provider "aws" {
  alias  = "virginia"
  region = "us-east-1"

  default_tags {
    tags = {
      project    = "faktron"
      managed_by = "opentofu"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  domain     = "faktron.com"
  account_id = data.aws_caller_identity.current.account_id

  # Vodien's old hosting, which mail. still names.
  legacy_host_ip = "103.11.189.189"

  # Where the enquiry form's emails go, and the address they come from (ses.tf, enquiry.tf).
  enquiry_to   = "info@faktron.com"
  enquiry_from = "enquiry@faktron.com"
}

resource "aws_route53_zone" "this" {
  name    = local.domain
  comment = "Faktron's domain, moved from Vodien's nameservers"

  lifecycle {
    prevent_destroy = true
  }
}

# ,, Mail ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

# Google Workspace mail: one MX, smtp.google.com, as Google now asks for.
resource "aws_route53_record" "mx" {
  zone_id = aws_route53_zone.this.zone_id
  name    = local.domain
  type    = "MX"
  ttl     = 3600
  records = ["1 smtp.google.com"]
}

resource "aws_route53_record" "legacy_mail" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "mail.${local.domain}"
  type    = "A"
  ttl     = 3600
  records = [local.legacy_host_ip]
}

# DKIM for SES (ses.tf): the three CNAMEs SES asks for, which prove the enquiry emails come from
# the domain. SES marks the identity verified once the zone answers for them. Google's own DKIM,
# SPF and DMARC are the owner's call, separately.
resource "aws_route53_record" "ses_dkim" {
  count = 3

  zone_id = aws_route53_zone.this.zone_id
  name    = "${aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens[count.index]}._domainkey.${local.domain}"
  type    = "CNAME"
  ttl     = 3600
  records = ["${aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens[count.index]}.dkim.amazonses.com"]
}

# ,, The site ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

# The bare domain and www, both at the distribution; the distribution sends www to the bare name.
resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.this.zone_id
  name    = local.domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "www.${local.domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# The same two names over IPv6, which the distribution answers on.
resource "aws_route53_record" "ipv6" {
  for_each = toset([local.domain, "www.${local.domain}"])

  zone_id = aws_route53_zone.this.zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
