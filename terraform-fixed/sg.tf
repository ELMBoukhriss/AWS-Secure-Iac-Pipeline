resource "aws_security_group" "ec2" {
  name        = "${var.project}-ec2-sg"
  description = "EC2 security group"
  vpc_id      = aws_vpc.main.id

  # FIXED: SSH removed — access via SSM Session Manager only

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS to AWS APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-ec2-sg" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "RDS security group"
  vpc_id      = aws_vpc.main.id

  # FIXED: only accepts connections from EC2 security group — not 0.0.0.0/0
  ingress {
    description = "Postgres from EC2 only"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = { Name = "${var.project}-rds-sg" }
}