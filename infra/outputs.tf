output "name_servers" {
  description = "What Vodien's nameserver fields get, once the records are checked."
  value       = aws_route53_zone.this.name_servers
}

output "zone_id" {
  description = "The Route 53 zone, for checking records against Vodien's."
  value       = aws_route53_zone.this.zone_id
}

output "site_bucket" {
  description = "Where deploy/site.sh uploads site/; CloudFront reads it from there."
  value       = aws_s3_bucket.site.bucket
}

output "distribution_id" {
  description = "The CloudFront distribution, for the invalidation deploy/site.sh sends after an upload."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain" {
  description = "The distribution's own name, which answers before the domain does: for checking a deploy."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "enquiry_url" {
  description = "Where the contact form posts; deploy/site.sh writes it into site/enquiry.generated.js."
  value       = aws_lambda_function_url.enquiry.function_url
}

output "enquiry_log_group" {
  description = "The enquiry function's logs, thirty days of them."
  value       = aws_cloudwatch_log_group.enquiry.name
}
