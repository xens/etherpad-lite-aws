variable "aws_region" { default = "yourAWSRegion" }

provider "aws" {
    region = "${var.aws_region}"
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["Main"]
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = data.aws_vpc.main.id
  filter {
    name   = "tag:Name"
    values = ["Public Main"]
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.main.id
  filter {
    name   = "tag:Name"
    values = ["Private Main"]
  }
}

output "subnet_cidr_blocks" {
  value = data.aws_subnet_ids.public
}
