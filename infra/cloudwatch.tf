resource "aws_cloudwatch_log_group" "app" {
  name              = "/rails-app/dev"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs"
    Environment = var.environment
  }
}
