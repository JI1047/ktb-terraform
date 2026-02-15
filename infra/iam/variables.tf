variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project" {
  type = string
}

variable "ec2_role_name" {
  type    = string
  default = "doktori-fe-ec2-role"
}

variable "ec2_instance_profile_name" {
  type    = string
  default = "doktori-fe-ec2-profile"
}
