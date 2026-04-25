data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public_1a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # jq is required by the SSM deploy script to parse Secrets Manager JSON
    dnf install -y docker jq
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user

    # AWS CLI is pre-installed on Amazon Linux 2023
    aws --version

    # Log into ECR — account ID resolved at runtime, region hardcoded
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REGISTRY="$${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"

    aws ecr get-login-password --region us-east-1 \
      | docker login --username AWS --password-stdin "$${ECR_REGISTRY}"
  EOF

  tags = {
    Name        = "rails-app-dev"
    Environment = var.environment
  }
}
