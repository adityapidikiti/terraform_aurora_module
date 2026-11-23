locals {
  cluster_identifier = var.cluster_identifier != null ? var.cluster_identifier : var.name

  # A generated password keeps credentials out of configuration. 20 bytes of
  # base64, filtered to alphanumerics, produces a value safe for every engine
  # without escaping.
  # one() rather than [0]: the resource has count = 0 when a password is
  # supplied, and indexing an empty list fails at plan time even though the
  # conditional would never evaluate that branch.
  generated_password = var.master_password == null ? replace(one(random_password.master_password[*].result), "/[^A-Za-z0-9]/", "") : null
  master_password    = var.master_password != null ? var.master_password : local.generated_password

  default_port = var.engine == "aurora-mysql" ? 3306 : 5432
  port         = var.port != null ? var.port : local.default_port

  # Production guards. Both are overridable only in the safe direction: prod
  # cannot be made deletable, non-prod cannot be made protected by accident.
  is_prod             = var.environment == "prod"
  deletion_protection = local.is_prod ? true : var.deletion_protection
  skip_final_snapshot = local.is_prod ? false : var.skip_final_snapshot

  final_snapshot_identifier = var.final_snapshot_identifier != null ? var.final_snapshot_identifier : (var.skip_final_snapshot ? null : "${var.name}-final-${one(random_id.final_snapshot[*].hex)}")

  # Autoscaling only when asked for a ceiling above the starting count.
  autoscaling_enabled = var.max_instance_count != null && var.max_instance_count > var.instance_count

  parameter_family = var.engine == "aurora-mysql" ? "aurora-mysql8.0" : "aurora-postgresql15"

  tags = merge(
    {
      Name        = var.name
      App         = var.app
      ManagedBy   = var.managed_by
      Environment = var.environment
      Provisioner = "Terraform"
    },
    var.custom_tags
  )
}

resource "random_password" "master_password" {
  count = var.master_password == null ? 1 : 0

  length  = 20
  special = false
}

resource "random_id" "final_snapshot" {
  count = var.skip_final_snapshot ? 0 : 1

  byte_length = 4
}

resource "aws_db_subnet_group" "this" {
  count = var.db_subnet_group_name == null ? 1 : 0

  name        = var.name
  description = "${var.name} Aurora subnet group"
  subnet_ids  = var.subnet_ids

  tags = local.tags
}

# Parameter groups are optional. The engine defaults are fine for many
# workloads; a custom group is what you need for log settings or tuning.

resource "aws_db_parameter_group" "this" {
  count = var.create_parameter_groups ? 1 : 0

  name        = "${var.name}-instance-params"
  family      = local.parameter_family
  description = "Instance parameter group for ${var.name}"

  dynamic "parameter" {
    for_each = var.db_parameter_group_parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = try(parameter.value.apply_method, null)
    }
  }

  tags = local.tags
}

resource "aws_rds_cluster_parameter_group" "this" {
  count = var.create_parameter_groups ? 1 : 0

  name        = "${var.name}-cluster-params"
  family      = local.parameter_family
  description = "Cluster parameter group for ${var.name}"

  dynamic "parameter" {
    for_each = var.db_cluster_parameter_group_parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = try(parameter.value.apply_method, null)
    }
  }

  tags = local.tags
}

locals {
  db_parameter_group_name = var.create_parameter_groups ? aws_db_parameter_group.this[0].name : var.db_parameter_group_name
  cluster_parameter_group = var.create_parameter_groups ? aws_rds_cluster_parameter_group.this[0].name : var.db_cluster_parameter_group_name
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = local.cluster_identifier
  engine             = var.engine
  engine_version     = var.engine_version
  port               = local.port

  database_name   = var.database_name
  master_username = var.master_username
  master_password = local.master_password

  db_subnet_group_name   = var.db_subnet_group_name != null ? var.db_subnet_group_name : aws_db_subnet_group.this[0].name
  vpc_security_group_ids = var.security_group_ids

  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  snapshot_identifier       = var.snapshot_identifier
  final_snapshot_identifier = var.skip_final_snapshot ? null : local.final_snapshot_identifier
  skip_final_snapshot       = local.skip_final_snapshot
  deletion_protection       = local.deletion_protection

  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  db_cluster_parameter_group_name = local.cluster_parameter_group

  apply_immediately = var.apply_immediately

  tags = local.tags

  lifecycle {
    # A generated password is written to state on creation. Without this, any
    # later regeneration would try to rotate it on every plan.
    ignore_changes = [master_password]
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${local.cluster_identifier}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this.id

  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  publicly_accessible  = false
  db_subnet_group_name = var.db_subnet_group_name != null ? var.db_subnet_group_name : aws_db_subnet_group.this[0].name

  db_parameter_group_name = local.db_parameter_group_name

  preferred_maintenance_window = var.preferred_maintenance_window
  apply_immediately            = var.apply_immediately

  monitoring_role_arn = var.monitoring_role_arn
  monitoring_interval = var.monitoring_interval

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_id

  auto_minor_version_upgrade = true

  tags = merge(local.tags, { Name = "${var.name}-${count.index + 1}" })

  lifecycle {
    # Engine upgrades roll themselves; pinning here would fight AWS's own
    # minor version automation.
    ignore_changes = [engine_version]
  }
}

resource "aws_appautoscaling_target" "readers" {
  count = local.autoscaling_enabled ? 1 : 0

  service_namespace  = "rds"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  resource_id        = "cluster:${aws_rds_cluster.this.cluster_identifier}"

  min_capacity = var.instance_count
  max_capacity = var.max_instance_count
}

resource "aws_appautoscaling_policy" "readers" {
  count = local.autoscaling_enabled ? 1 : 0

  name               = "${var.name}-reader-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.readers[0].service_namespace
  resource_id        = aws_appautoscaling_target.readers[0].resource_id
  scalable_dimension = aws_appautoscaling_target.readers[0].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling_cpu_target
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageCPUUtilization"
    }
  }
}
