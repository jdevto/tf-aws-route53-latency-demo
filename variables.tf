variable "zone_name" {
  description = "Public hosted zone name (e.g., example.com)"
  type        = string
}

variable "record_name" {
  description = "DNS record name for latency routing (e.g., demo)"
  type        = string
}
