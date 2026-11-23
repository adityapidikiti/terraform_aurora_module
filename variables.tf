variable "name" {
  type        = string
  description = "Name used for the cluster identifier, subnet group and tags."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.name))
    error_message = "name must start with a letter and contain only lowercase letters, digits and hyphens."
  }
}

variable "cluster_identifier" {
  type        = string
  description = "Override for the cluster identifier. Defaults to name."
  default     = null
}

variable "engine" {
  type        = string
  description = "Aurora engine: aurora-mysql or aurora-postgresql."
  default     = "aurora-postgresql"

  validation {
    condition     = contains(["aurora-mysql", "aurora-postgresql"], var.engine)
    error_message = "engine must be aurora-mysql or aurora-postgresql."
  }
}

variable "engine_version" {
  type        = string
  description = "Engine version, for example 15.4 or 8.0.mysql_aurora.3.08.0. Leave null to let AWS pick the default for the engine."
  default     = null
}

variable "instance_class" {
  type        = string
  description = "Instance class for the cluster instances, for example db.t4g.medium."
  default     = "db.t4g.medium"
}

variable "instance_count" {
  type        = number
  description = "Number of cluster instances. One writer, the rest readers."
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 15
    error_message = "instance_count must be between 1 and 15."
  }
}

# Network

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the cluster. Must span at least two availability zones."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Aurora requires subnets in at least two availability zones."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups applied to the cluster."
}

variable "db_subnet_group_name" {
  type        = string
  description = "Use an existing DB subnet group instead of creating one from subnet_ids."
  default     = null
}

# Database

variable "database_name" {
  type        = string
  description = "Name of the database created on the cluster. Leave null to create none."
  default     = null
}

variable "master_username" {
  type        = string
  description = "Master username."
  default     = "dbadmin"
}

variable "master_password" {
  type        = string
  description = "Master password. Leave null to generate one and expose it through the password output."
  default     = null
  sensitive   = true

  validation {
    condition     = var.master_password == null || length(var.master_password) >= 8
    error_message = "master_password must be at least 8 characters."
  }
}

variable "port" {
  type        = number
  description = "Port the cluster listens on. Defaults to 5432 for Aurora PostgreSQL and 3306 for Aurora MySQL."
  default     = null
}

# Backups

variable "backup_retention_period" {
  type        = number
  description = "Days to retain automated backups. 1 to 35; 0 disables backups."
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35."
  }
}

variable "preferred_backup_window" {
  type        = string
  description = "Daily backup window in UTC, for example 09:00-10:00."
  default     = "09:00-10:00"
}

variable "preferred_maintenance_window" {
  type        = string
  description = "Weekly maintenance window in UTC, for example sun:10:10-sun:11:00."
  default     = "sun:10:10-sun:11:00"
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip the final snapshot when the cluster is destroyed. Forced to false when environment is prod."
  default     = true
}

variable "final_snapshot_identifier" {
  type        = string
  description = "Identifier for the final snapshot. A random suffix keeps it unique across destroys."
  default     = null
}

variable "snapshot_identifier" {
  type        = string
  description = "Restore the cluster from this snapshot."
  default     = null
}

# Protection

variable "deletion_protection" {
  type        = bool
  description = "Block deletion of the cluster. Forced to true when environment is prod."
  default     = false
}

variable "apply_immediately" {
  type        = bool
  description = "Apply changes immediately instead of during the maintenance window."
  default     = false
}

# Encryption

variable "storage_encrypted" {
  type        = bool
  description = "Encrypt storage at rest."
  default     = true
}

variable "kms_key_id" {
  type        = string
  description = "Customer-managed KMS key for storage encryption. Leave null for the AWS-managed key."
  default     = null
}

# Monitoring

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "Log types to export to CloudWatch, for example postgresql or audit for Postgres, audit or error for MySQL."
  default     = []
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Enable Performance Insights on the cluster instances."
  default     = false
}

variable "performance_insights_kms_key_id" {
  type        = string
  description = "KMS key for Performance Insights data."
  default     = null
}

variable "monitoring_interval" {
  type        = number
  description = "Enhanced monitoring interval in seconds: 0, 1, 5, 10, 15, 30 or 60."
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be 0, 1, 5, 10, 15, 30 or 60."
  }
}

variable "monitoring_role_arn" {
  type        = string
  description = "IAM role allowing the cluster to publish enhanced monitoring metrics. Required when monitoring_interval is non-zero."
  default     = null

  validation {
    condition     = var.monitoring_interval == 0 || var.monitoring_role_arn != null
    error_message = "monitoring_role_arn is required when monitoring_interval is non-zero."
  }
}

# Parameter groups

variable "create_parameter_groups" {
  type        = bool
  description = "Create DB and cluster parameter groups. Set false to use the engine defaults."
  default     = false
}

variable "db_parameter_group_name" {
  type        = string
  description = "Existing DB parameter group to use. Only applicable when create_parameter_groups is false."
  default     = null
}

variable "db_cluster_parameter_group_name" {
  type        = string
  description = "Existing cluster parameter group to use. Only applicable when create_parameter_groups is false."
  default     = null
}

variable "db_parameter_group_parameters" {
  type        = list(any)
  description = "Parameters for the created DB parameter group, each with name and value, and optionally apply_method."
  default     = []
}

variable "db_cluster_parameter_group_parameters" {
  type        = list(any)
  description = "Parameters for the created cluster parameter group, each with name and value, and optionally apply_method."
  default     = []
}

# Autoscaling

variable "max_instance_count" {
  type        = number
  description = "Upper bound for the read replica autoscaler. Set equal to instance_count to disable autoscaling."
  default     = null
}

variable "autoscaling_cpu_target" {
  type        = number
  description = "Target average CPU utilisation percentage for read replica autoscaling."
  default     = 70

  validation {
    condition     = var.autoscaling_cpu_target > 0 && var.autoscaling_cpu_target <= 100
    error_message = "autoscaling_cpu_target must be between 1 and 100."
  }
}

variable "autoscaling_scale_in_cooldown" {
  type        = number
  description = "Seconds before another scale-in is allowed."
  default     = 300
}

variable "autoscaling_scale_out_cooldown" {
  type        = number
  description = "Seconds before another scale-out is allowed."
  default     = 300
}

# Tags

variable "app" {
  type        = string
  description = "Application the database belongs to, used for the App tag."
}

variable "managed_by" {
  type        = string
  description = "Team responsible for the database, used for the ManagedBy tag."
}

variable "environment" {
  type        = string
  description = "Deployment environment, used for the Environment tag and the prod safety rules."
}

variable "custom_tags" {
  type        = map(string)
  description = "Additional tags merged over the standard set."
  default     = {}
}
