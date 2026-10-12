terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  # Faktron lives in BTW's AWS account, so its state sits in BTW's state bucket under a key of its
  # own, locked by a file beside it (OpenTofu 1.10+). Nothing in BTW's stack reads or writes it.
  backend "s3" {
    bucket       = "btw-tfstate-873310976934-apse2"
    key          = "faktron/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
