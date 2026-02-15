output "ec2_role_name" {
  value = aws_iam_role.fe_ec2.name
}

output "ec2_role_arn" {
  value = aws_iam_role.fe_ec2.arn
}

output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.fe_ec2.name
}

output "ec2_instance_profile_arn" {
  value = aws_iam_instance_profile.fe_ec2.arn
}
