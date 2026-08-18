resource "random_password" "master" {
  count = var.master_password != "" ? 0 : 1

  length      = 20
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

locals {
  master_password = length(random_password.master) > 0 ? random_password.master[0].result : var.master_password
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  })
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project}-${var.environment}-mssql-ex-pg"
  family = "sqlserver-ex-16.0"

  parameter {
    name         = "in-doubt xact resolution"
    value        = "1"
    apply_method = "immediate"
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-mssql-ex-pg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_option_group" "main" {
  name                 = "${var.project}-${var.environment}-msdtc"
  engine_name          = "sqlserver-ex"
  major_engine_version = "16.00"

  option {
    option_name = "MSDTC"
    port        = 5000

    vpc_security_group_memberships = [var.security_group_id]

    option_settings {
      name  = "AUTHENTICATION"
      value = "NONE"
    }

    option_settings {
      name  = "TRANSACTION_LOG_SIZE"
      value = "4"
    }

    option_settings {
      name  = "ALLOW_INBOUND_CONNECTIONS"
      value = "true"
    }

    option_settings {
      name  = "ALLOW_OUTBOUND_CONNECTIONS"
      value = "true"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-msdtc"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}-db"

  engine         = "sqlserver-ex"
  engine_version = var.engine_version
  instance_class = var.instance_class
  license_model  = "license-included"

  allocated_storage     = var.allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  max_allocated_storage = 0

  username = var.master_username
  password = local.master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  parameter_group_name = aws_db_parameter_group.main.name
  option_group_name    = aws_db_option_group.main.name

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  backup_retention_period    = 1
  auto_minor_version_upgrade = false

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db"
  })

  depends_on = [aws_db_option_group.main, aws_db_parameter_group.main]
}
