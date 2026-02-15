variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "private_route_table_id" {
  type = string
}

variable "bastion_nat_sg_id" {
  type = string
}

variable "nginx_sg_id" {
  type = string
}

variable "fe_sg_id" {
  type = string
}

variable "instance_profile_name" {
  type    = string
  default = null
}

variable "key_name" {
  type    = string
  default = null
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "fe_app_port" {
  type    = number
  default = 3000
}

variable "ami_id" {
  type    = string
  default = null
}
