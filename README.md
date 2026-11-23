# terraform_aurora_module

Terraform module for an Aurora cluster, MySQL or PostgreSQL, with optional
parameter groups, read replica autoscaling and production safety guards.

## Quick start

```hcl
module "database" {
  source = "git@github.com:adityapidikiti/terraform_aurora_module.git"

  name = "app-db"

  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids = [aws_security_group.db.id]

  app         = "my-app"
  managed_by  = "platform"
  environment = "dev"
}
```

Creates an Aurora PostgreSQL cluster with two instances and a generated master
password. Only `name`, `subnet_ids`, `security_group_ids`, `app`, `managed_by`
and `environment` are required.

## Postgres or MySQL

`engine` defaults to `aurora-postgresql`. For MySQL:

```hcl
  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.08.0"
```

The port follows the engine unless `port` is set: 5432 for PostgreSQL, 3306 for
MySQL.

## Password

Leave `master_password` unset and the module generates a 20-character
alphanumeric password, exposed only through the `sensitive` `master_password`
output. Supply your own when integrating with an existing secret store.

A generated password is written to Terraform state, so state must be stored
somewhere appropriately restricted.

## Production guards

When `environment = "prod"` the module forces:

- `deletion_protection = true` — the cluster cannot be deleted until this is
  turned off
- `skip_final_snapshot = false` — a final snapshot is always taken

Both apply regardless of what you pass. Non-prod uses your values, which
default to protection off and snapshot skipped.

## Parameter groups

By default the engine's parameter groups are used. To customise:

```hcl
  create_parameter_groups = true

  db_parameter_group_parameters = [
    { name = "slow_query_log", value = "1" },
  ]

  db_cluster_parameter_group_parameters = [
    { name = "server_audit_logging", value = "1", apply_method = "immediate" },
  ]
```

Or point at existing groups with `db_parameter_group_name` and
`db_cluster_parameter_group_name` while leaving `create_parameter_groups` false.

## Read replica autoscaling

```hcl
  instance_count     = 1
  max_instance_count = 4
```

Attaches an Application Auto Scaling target tracking policy on average reader
CPU, scaling between `instance_count` and `max_instance_count`. Leave
`max_instance_count` null to disable — the module then creates no autoscaling
resources at all.

## Monitoring and logs

```hcl
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  performance_insights_enabled = true

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
```

`monitoring_role_arn` is required as soon as `monitoring_interval` is non-zero,
and `monitoring_interval` must be one of 0, 1, 5, 10, 15, 30 or 60.

## Network

Pass `subnet_ids` directly, spanning at least two availability zones, or supply
an existing `db_subnet_group_name` to skip creating one. The module does not
discover subnets by naming convention — it uses whatever you give it.

## Tags

```hcl
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
```

## Testing

```bash
cd test
terraform init
terraform test -filter=plan.tftest.hcl        # 6 runs
terraform test -filter=validation.tftest.hcl  # 9 runs
```

All 15 use `mock_provider`, so no credentials are needed and no database is
created.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name for the cluster identifier, subnet group and tags. | `string` | n/a | yes |
| subnet_ids | Subnets for the cluster, at least two AZs. | `list(string)` | n/a | yes |
| security_group_ids | Security groups applied to the cluster. | `list(string)` | n/a | yes |
| app | Application the database belongs to. | `string` | n/a | yes |
| managed_by | Team responsible for the database. | `string` | n/a | yes |
| environment | Deployment environment; drives the prod guards. | `string` | n/a | yes |
| apply_immediately | Apply changes immediately rather than in the maintenance window. | `bool` | `false` | no |
| autoscaling_cpu_target | Reader CPU target percentage. | `number` | `70` | no |
| autoscaling_scale_in_cooldown | Scale-in cooldown, seconds. | `number` | `300` | no |
| autoscaling_scale_out_cooldown | Scale-out cooldown, seconds. | `number` | `300` | no |
| backup_retention_period | Days of automated backups, 0 to 35. | `number` | `7` | no |
| cluster_identifier | Override the cluster identifier. | `string` | `null` | no |
| create_parameter_groups | Create parameter groups. | `bool` | `false` | no |
| custom_tags | Additional tags merged over the standard set. | `map(string)` | `{}` | no |
| database_name | Database created on the cluster. | `string` | `null` | no |
| db_cluster_parameter_group_name | Existing cluster parameter group. | `string` | `null` | no |
| db_cluster_parameter_group_parameters | Parameters for the created cluster group. | `list(any)` | `[]` | no |
| db_parameter_group_name | Existing DB parameter group. | `string` | `null` | no |
| db_parameter_group_parameters | Parameters for the created DB group. | `list(any)` | `[]` | no |
| db_subnet_group_name | Existing DB subnet group. | `string` | `null` | no |
| deletion_protection | Block deletion. Forced true in prod. | `bool` | `false` | no |
| enabled_cloudwatch_logs_exports | Log types to export. | `list(string)` | `[]` | no |
| engine | aurora-mysql or aurora-postgresql. | `string` | `"aurora-postgresql"` | no |
| engine_version | Engine version. | `string` | `null` | no |
| final_snapshot_identifier | Identifier for the final snapshot. | `string` | `null` | no |
| instance_class | Instance class. | `string` | `"db.t4g.medium"` | no |
| instance_count | Number of cluster instances. | `number` | `2` | no |
| kms_key_id | Customer-managed KMS key for storage. | `string` | `null` | no |
| master_password | Master password; generated when null. | `string` | `null` | no |
| master_username | Master username. | `string` | `"dbadmin"` | no |
| max_instance_count | Upper bound for reader autoscaling. | `number` | `null` | no |
| monitoring_interval | Enhanced monitoring interval. | `number` | `0` | no |
| monitoring_role_arn | Role for enhanced monitoring. | `string` | `null` | no |
| performance_insights_enabled | Enable Performance Insights. | `bool` | `false` | no |
| performance_insights_kms_key_id | KMS key for Performance Insights. | `string` | `null` | no |
| port | Port the cluster listens on. | `number` | `null` | no |
| preferred_backup_window | Daily backup window, UTC. | `string` | `"09:00-10:00"` | no |
| preferred_maintenance_window | Weekly maintenance window, UTC. | `string` | `"sun:10:10-sun:11:00"` | no |
| skip_final_snapshot | Skip the final snapshot. Forced false in prod. | `bool` | `true` | no |
| snapshot_identifier | Restore from this snapshot. | `string` | `null` | no |
| storage_encrypted | Encrypt storage at rest. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| autoscaling_enabled | Whether reader autoscaling is attached. |
| cluster_arn | ARN of the cluster. |
| cluster_endpoint | Writer endpoint. |
| cluster_id | Identifier of the cluster. |
| cluster_port | Port the cluster listens on. |
| cluster_reader_endpoint | Reader endpoint. |
| database_name | Database created, or null. |
| db_subnet_group_name | Subnet group in use. |
| deletion_protection | Effective deletion protection. |
| instance_endpoints | Endpoints of the cluster instances. |
| instance_ids | Identifiers of the cluster instances. |
| master_password | Master password. Sensitive. |
| master_username | Master username. |
| password_generated | Whether the password was generated. |
| skip_final_snapshot | Effective final snapshot setting. |
| tags | Tags applied to the cluster. |
