resource "aws_lb" "etherpad" {
  name               = "etherpad"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.public.ids

  enable_deletion_protection = true

  tags = {
    Name = "Etherpad ALB"
  }
}

resource "aws_lb_listener" "etherpad" {
  load_balancer_arn = "${aws_lb.etherpad.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.etherpad.arn

  default_action {
    type             = "fixed-response"
      fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_target_group" "etherpad" {
  name     = "etherpad"
  port     = 9001
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id
  target_type = "ip"
}

resource "aws_lb_listener_rule" "etherpad" {
  listener_arn = aws_lb_listener.etherpad.arn
  priority     = 99
  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.etherpad.arn}"
  }
  condition {
    host_header {
      values = ["your.record.proxied.behind.cloudflare"]
    }
  }
}
