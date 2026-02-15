data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  resolved_ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.al2023.id

  common_tags = {
    Project = var.project
    Stack   = "compute"
  }
}

resource "aws_instance" "bastion_nat" {
  ami                    = local.resolved_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.bastion_nat_sg_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name

  associate_public_ip_address = true
  source_dest_check           = false

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              sysctl -w net.ipv4.ip_forward=1
              grep -q "net.ipv4.ip_forward" /etc/sysctl.conf || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

              dnf install -y iptables-services || true
              iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE || iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
              iptables -C FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
              iptables -C FORWARD -i eth0 -o eth0 -j ACCEPT || iptables -A FORWARD -i eth0 -o eth0 -j ACCEPT

              service iptables save || true
              systemctl enable iptables || true
              EOF

  tags = merge(local.common_tags, {
    Name = "${var.project}-bastion-nat"
    Role = "bastion-nat"
  })
}

resource "aws_route" "private_default_via_nat_instance" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.bastion_nat.primary_network_interface_id
}

resource "aws_instance" "fe" {
  ami                    = local.resolved_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.fe_sg_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name

  associate_public_ip_address = false

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              dnf update -y
              dnf install -y nodejs npm
              # TODO: replace with actual FE deploy script for Next.js SSR.
              EOF

  tags = merge(local.common_tags, {
    Name = "${var.project}-fe"
    Role = "fe"
  })
}

resource "aws_instance" "nginx" {
  ami                    = local.resolved_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.nginx_sg_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name

  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/nginx-user-data.sh.tftpl", {
    fe_private_ip = aws_instance.fe.private_ip
    fe_app_port   = var.fe_app_port
  })

  tags = merge(local.common_tags, {
    Name = "${var.project}-nginx"
    Role = "nginx"
  })
}
