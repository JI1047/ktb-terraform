locals {
  common_tags = {
    Project = var.project
    Stack   = "security"
  }
}

resource "aws_security_group" "bastion_nat" {
  name        = "${var.project}-bastion-nat-sg"
  description = "Bastion + NAT instance SG"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project}-bastion-nat-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each = var.enable_bastion_ssh ? toset(var.admin_ingress_cidrs) : toset([])

  security_group_id = aws_security_group.bastion_nat.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "bastion_nat_from_vpc" {
  security_group_id = aws_security_group.bastion_nat.id
  ip_protocol       = "-1"
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion_nat.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "nginx" {
  name        = "${var.project}-nginx-sg"
  description = "Nginx reverse proxy SG"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project}-nginx-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "nginx_80" {
  for_each = toset(var.nginx_ingress_cidrs)

  security_group_id = aws_security_group.nginx.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "nginx_443" {
  for_each = toset(var.nginx_ingress_cidrs)

  security_group_id = aws_security_group.nginx.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "nginx_22_from_bastion" {
  security_group_id            = aws_security_group.nginx.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion_nat.id
}

resource "aws_vpc_security_group_egress_rule" "nginx_all" {
  security_group_id = aws_security_group.nginx.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "fe" {
  name        = "${var.project}-fe-sg"
  description = "Private FE server SG"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project}-fe-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "fe_3000_from_nginx" {
  security_group_id            = aws_security_group.fe.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.nginx.id
}

resource "aws_vpc_security_group_ingress_rule" "fe_22_from_bastion" {
  security_group_id            = aws_security_group.fe.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion_nat.id
}

resource "aws_vpc_security_group_egress_rule" "fe_all" {
  security_group_id = aws_security_group.fe.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
