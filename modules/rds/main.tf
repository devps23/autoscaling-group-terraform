resource "aws_db_instance" "db_instance" {
  allocated_storage    = 20
  db_name              = var.db_name
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  username             = jsondecode(data.vault_generic_secret.my_secret.data_json).rds_username
  password             = jsondecode(data.vault_generic_secret.my_secret.data_json).rds_password
  parameter_group_name = aws_db_parameter_group.pg.id
  skip_final_snapshot  = true
  storage_type         = var.storage_type
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name = aws_db_subnet_group.subnet_group.name
  identifier           = "rds-dev"
  multi_az             = false
  storage_encrypted    = true
  kms_key_id           = var.kms_key_id
#   to take snapshot in rds
  backup_retention_period = 35
  backup_window           = "09:46-10:16"
}
resource "aws_db_parameter_group" "pg" {
  name   = "${var.env}-${var.component}-rds"
  family = "mysql8.0"
  }
resource "aws_db_subnet_group" "subnet_group" {
  name       = "${var.env}-${var.component}-sbgrp"
  subnet_ids = var.subnet_id

  tags = {
    Name = "${var.env}-${var.component}-sbgrp"
  }
}
resource "aws_security_group" "rds" {
  name        = "${var.env}-vsg-${var.component}-db"
  description = "${var.env}-vsg-${var.component}-db"
  vpc_id      = var.vpc_id
  ingress {
    from_port   =  var.rds_app_port
    to_port     =  var.rds_app_port
    protocol    = "TCP"
    cidr_blocks = var.server_app_port_cidr
  }
  egress {
    from_port   =  0
    to_port     =  0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.env}-vsg-${var.component}-db"
  }
}