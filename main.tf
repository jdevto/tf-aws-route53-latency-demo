# Data source for Route 53 hosted zone
data "aws_route53_zone" "main" {
  name = var.zone_name
}

# App Runner Service for ap-southeast-2
resource "aws_apprunner_service" "apse2" {
  service_name = "${var.record_name}-apse2"

  source_configuration {
    auto_deployments_enabled = false

    image_repository {
      image_identifier      = "public.ecr.aws/docker/library/httpd:latest"
      image_repository_type = "ECR_PUBLIC"
      image_configuration {
        port = "80"
      }
    }
  }

  instance_configuration {
    cpu    = "0.25 vCPU"
    memory = "0.5 GB"
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }
}

# App Runner Service for us-east-1
resource "aws_apprunner_service" "use1" {
  provider     = aws.use1
  service_name = "${var.record_name}-use1"

  source_configuration {
    auto_deployments_enabled = false

    image_repository {
      image_identifier      = "public.ecr.aws/docker/library/httpd:latest"
      image_repository_type = "ECR_PUBLIC"
      image_configuration {
        port = "80"
      }
    }
  }

  instance_configuration {
    cpu    = "0.25 vCPU"
    memory = "0.5 GB"
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }
}

# Route 53 Latency Records pointing to App Runner
# Note: App Runner doesn't support alias records, so we use CNAME records
resource "aws_route53_record" "apse2" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.record_name
  type    = "CNAME"
  ttl     = 60

  records = [replace(aws_apprunner_service.apse2.service_url, "https://", "")]

  latency_routing_policy {
    region = "ap-southeast-2"
  }

  set_identifier = "ap-southeast-2"
}

resource "aws_route53_record" "use1" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.record_name
  type    = "CNAME"
  ttl     = 60

  records = [replace(aws_apprunner_service.use1.service_url, "https://", "")]

  latency_routing_policy {
    region = "us-east-1"
  }

  set_identifier = "us-east-1"
}
