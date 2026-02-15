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
