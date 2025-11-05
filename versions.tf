terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
