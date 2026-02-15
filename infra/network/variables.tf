variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_a_cidr" {
  type    = string
  default = "10.0.11.0/24"
}

variable "private_subnet_b_cidr" {
  type    = string
  default = "10.0.12.0/24"
}

variable "az_a" {
  type    = string
  default = "ap-northeast-2a"
}

variable "az_b" {
  type    = string
  default = "ap-northeast-2b"
}
