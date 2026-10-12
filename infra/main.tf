# faktron.com in Route 53.
#
# The zone started as a copy of what Vodien served on 12 October 2026 (found by asking Vodien's own
# nameserver for each name), so moving the nameservers changes nothing anybody relies on: Google
# Workspace mail keeps its MX, and mail. still names Vodien's old hosting. The bare domain, www and
# the wildcard still point where Figma Sites had them, though Figma no longer serves the domain;
# they move to the new site when it lands.
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

locals {
  domain = "faktron.com"

  # Figma Sites: the address Vodien gave the bare domain and every other name.
  figma_ip = "204.69.207.1"

  # Vodien's old hosting, which mail. still names.
  legacy_host_ip = "103.11.189.189"
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

# ,, The site, as Figma had it, until the new one lands ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.this.zone_id
  name    = local.domain
  type    = "A"
  ttl     = 300
  records = [local.figma_ip]
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "www.${local.domain}"
  type    = "CNAME"
  ttl     = 300
  records = ["sites.figma.net"]
}

# Vodien answered every other name (webmail., ftp., anything) with Figma's address.
resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "*.${local.domain}"
  type    = "A"
  ttl     = 300
  records = [local.figma_ip]
}
