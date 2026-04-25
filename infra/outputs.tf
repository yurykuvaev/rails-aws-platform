output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ec2_instance_id" {
  value = aws_instance.app.id
}

output "ec2_private_ip" {
  value = aws_instance.app.private_ip
}

output "rds_endpoint" {
  value     = aws_db_instance.main.endpoint
  sensitive = true
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}
