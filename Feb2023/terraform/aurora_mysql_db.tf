module "techtalks_db" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "7.6.0"

  name           = "tech-talks"
  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.02.0"
  instance_class = "db.r5.large"
  instances = {
    one = {}
  }

  autoscaling_enabled      = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 5

  vpc_id                 = module.vpc.vpc_id
  db_subnet_group_name   = aws_db_subnet_group.aurora_techtalks.name
  create_db_subnet_group = false
  create_security_group  = true
  allowed_cidr_blocks    = module.vpc.private_subnets_cidr_blocks

  database_name                       = "techtalks"
  master_username                     = "root"
  master_password                     = random_password.techtalks_db_master.result
  create_random_password              = false
  iam_database_authentication_enabled = true

  apply_immediately = true

  db_parameter_group_name         = aws_db_parameter_group.techtalks_db.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.techtalks_db.id
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  security_group_use_name_prefix = false

  backup_retention_period = 7
  preferred_backup_window = "02:00-03:00"
  skip_final_snapshot     = true

  tags = local.tags
}

resource "random_password" "techtalks_db_master" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "techtalks_db_password" {
  #checkov:skip=CKV_AWS_149:"Ensure that Secrets Manager secret is encrypted using KMS CMK"
  name                    = "techtalks-db-password"
  recovery_window_in_days = "0"
}

resource "aws_secretsmanager_secret_version" "techtalks_db_password" {
  secret_id     = aws_secretsmanager_secret.techtalks_db_password.id
  secret_string = random_password.techtalks_db_master.result
}

resource "aws_db_subnet_group" "aurora_techtalks" {

  name        = "techtalks-subnet-group"
  description = "For Aurora cluster TechTalks"
  subnet_ids  = module.vpc.database_subnets

}

resource "aws_db_parameter_group" "techtalks_db" {
  name        = "techtalksdb"
  family      = "aurora-mysql8.0"
  description = "techtalksdb"
  tags        = local.tags
}

resource "aws_rds_cluster_parameter_group" "techtalks_db" {
  name        = "techtalksdb-cluster"
  family      = "aurora-mysql8.0"
  description = "techtalksdb-cluster"
  tags        = local.tags

  # parameter {
  #   name         = "innodb_file_format"
  #   value        = "barracuda"
  #   apply_method = "pending-reboot"
  # }
}

