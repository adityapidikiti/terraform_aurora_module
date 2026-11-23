provider "aws" {
  region = "us-east-1"
}

locals {
  subnets = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  sgs     = ["sg-0123456789abcdef0"]
}

# Minimal: Postgres, two instances, no autoscaling, no parameter groups.
module "postgres" {
  source = "../"

  name               = "example-pg"
  subnet_ids         = local.subnets
  security_group_ids = local.sgs

  app         = "terraform-aurora-tests"
  managed_by  = "platform"
  environment = "dev"
}

# MySQL, autoscaling between 1 and 4 readers, custom parameter groups.
module "mysql" {
  source = "../"

  name               = "example-mysql"
  subnet_ids         = local.subnets
  security_group_ids = local.sgs

  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.08.0"
  instance_class = "db.t4g.medium"
  instance_count = 1
  database_name  = "appdb"

  max_instance_count = 4

  create_parameter_groups = true

  db_parameter_group_parameters = [
    { name = "slow_query_log", value = "1" },
  ]

  db_cluster_parameter_group_parameters = [
    { name = "server_audit_logging", value = "1", apply_method = "immediate" },
  ]

  enabled_cloudwatch_logs_exports = ["audit", "error"]

  app         = "terraform-aurora-tests"
  managed_by  = "platform"
  environment = "dev"
}

# Production, to exercise the safety guards.
module "production" {
  source = "../"

  name               = "example-prod"
  subnet_ids         = local.subnets
  security_group_ids = local.sgs

  app         = "terraform-aurora-tests"
  managed_by  = "platform"
  environment = "prod"

  custom_tags = {
    Owner = "data-team"
  }
}

# Explicit password, existing subnet group.
module "existing" {
  source = "../"

  name               = "example-existing"
  subnet_ids         = local.subnets
  security_group_ids = local.sgs

  db_subnet_group_name = "my-existing-subnet-group"
  master_password      = "supplied-password-123"

  app         = "terraform-aurora-tests"
  managed_by  = "platform"
  environment = "stage"
}
