resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = [aws_subnet.public.id]
  tags       = { Name = "${var.project}-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project}-db"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "icorpdb"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # FIXED: encrypted at rest — PCI DSS requirement
  storage_encrypted       = true
 # FIXED: no public endpoint — only reachable within VPC
  publicly_accessible     = false
   # FIXED: 7 days of automated backups
  backup_retention_period = 7
  skip_final_snapshot     = false
  auto_minor_version_upgrade          = true
  deletion_protection                 = true        
  copy_tags_to_snapshot               = true          
  iam_database_authentication_enabled = true          
  enabled_cloudwatch_logs_exports     = ["postgresql"] 

  tags = { Name = "${var.project}-db" }
}