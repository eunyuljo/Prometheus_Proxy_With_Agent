terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

module "vpc_1" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "vpc-1"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  public_subnet_tags = {
    Name = "vpc-1-public"
    Type = "public"
  }

  private_subnet_tags = {
    Name = "vpc-1-private"
    Type = "private"
  }

  tags = {
    Name = "vpc-1"
  }
}

module "vpc_2" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "vpc-2"
  cidr = "10.1.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets = ["10.1.11.0/24", "10.1.12.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  public_subnet_tags = {
    Name = "vpc-2-public"
    Type = "public"
  }

  private_subnet_tags = {
    Name = "vpc-2-private"
    Type = "private"
  }

  tags = {
    Name = "vpc-2"
  }
}

