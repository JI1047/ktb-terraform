variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "enable_bastion_ssh" {
  type    = bool
  default = false
}

variable "admin_ingress_cidrs" {
  type    = list(string)
  default = []
}

variable "nginx_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
