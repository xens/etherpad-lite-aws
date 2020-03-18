resource "aws_acm_certificate" "etherpad" {
  domain_name = "your.record.proxied.behind.cloudflare"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}
