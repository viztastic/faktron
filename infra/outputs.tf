output "name_servers" {
  description = "What Vodien's nameserver fields get, once the records are checked."
  value       = aws_route53_zone.this.name_servers
}

output "zone_id" {
  description = "The Route 53 zone, for checking records against Vodien's."
  value       = aws_route53_zone.this.zone_id
}
