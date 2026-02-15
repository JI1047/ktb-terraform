output "bastion_nat_instance_id" {
  value = aws_instance.bastion_nat.id
}

output "bastion_nat_public_ip" {
  value = aws_instance.bastion_nat.public_ip
}

output "bastion_nat_public_dns" {
  value = aws_instance.bastion_nat.public_dns
}

output "fe_private_ip" {
  value = aws_instance.fe.private_ip
}

output "nginx_public_ip" {
  value = aws_instance.nginx.public_ip
}

output "nginx_public_dns" {
  value = aws_instance.nginx.public_dns
}
