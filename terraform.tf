terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.22"
    }
  }

  backend "s3" {
    bucket = "ndx-try-tf-state"
    key = "state/terraform.tfstate"
    region = "us-west-2"
    
  }

  required_version = ">= 1.14"
}
