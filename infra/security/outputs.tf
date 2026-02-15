output "bastion_nat_sg_id" {
  value = aws_security_group.bastion_nat.id
}

output "nginx_sg_id" {
  value = aws_security_group.nginx.id
}

output "fe_sg_id" {
  value = aws_security_group.fe.id
}
