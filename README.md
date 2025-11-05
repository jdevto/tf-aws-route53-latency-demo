# Route 53 Latency Routing Demo

This Terraform configuration demonstrates Route 53 latency-based routing between two App Runner services hosted in different AWS regions.

## Overview

The configuration creates:

- Two App Runner services (one in each region)
- Route 53 latency routing records that route users to the nearest region based on latency

## Prerequisites

- Public hosted zone in Route 53
- AWS credentials configured with permissions for Route 53 and App Runner
- Two AWS providers configured for different regions

## Usage

1. Initialize Terraform:

    ```bash
    terraform init
    ```

2. Create a `terraform.tfvars` file with your values:

    ```hcl
    zone_name   = "your-domain.com"
    record_name = "your-record"
    ```

3. Plan and apply:

    ```bash
    terraform plan
    terraform apply
    ```

## Variables

- `zone_name` (required): Public hosted zone name
- `record_name` (required): DNS record name for latency routing

## Outputs

- `fqdn`: Final FQDN
- `apprunner_service_url_apse2`: App Runner service URL for first region
- `apprunner_service_url_use1`: App Runner service URL for second region

## Validation

Run the validation script:

```bash
./validate.sh <fqdn> <apprunner_url_region1> <apprunner_url_region2>
```

Or use Terraform outputs:

```bash
./validate.sh \
  $(terraform output -raw fqdn) \
  $(terraform output -raw apprunner_service_url_apse2) \
  $(terraform output -raw apprunner_service_url_use1)
```

## Expected Behavior

- Route 53 automatically routes users to the App Runner service with the lowest latency based on their location
- Users closer to one region will be routed to that region's App Runner service

## Notes

- App Runner services use HTTPS by default
- CNAME records are used for routing
- Short TTL (60 seconds) is configured for easy testing
