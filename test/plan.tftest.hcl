# Provider is mocked, so this needs no AWS credentials and creates nothing.
#   terraform test -filter=plan.tftest.hcl

mock_provider "aws" {}
mock_provider "random" {}

run "postgres_defaults" {
  command = plan

  assert {
    condition     = module.postgres.password_generated == true
    error_message = "A password should be generated when none is supplied."
  }

  assert {
    condition     = module.postgres.cluster_port == 5432
    error_message = "Aurora PostgreSQL should default to port 5432."
  }

  assert {
    condition     = length(module.postgres.instance_ids) == 2
    error_message = "Two cluster instances should be created by default."
  }

  assert {
    condition     = module.postgres.autoscaling_enabled == false
    error_message = "Autoscaling should be off unless a max_instance_count is given."
  }
}

run "tags_follow_the_module_standard" {
  command = plan

  assert {
    condition     = module.postgres.tags["Name"] == "example-pg"
    error_message = "The Name tag should follow the name input."
  }

  assert {
    condition     = module.postgres.tags["Provisioner"] == "Terraform"
    error_message = "The Provisioner tag should always be Terraform."
  }

  assert {
    condition     = length(module.postgres.tags) == 5
    error_message = "Exactly five standard tags should be applied by default."
  }

  assert {
    condition     = !contains(keys(module.postgres.tags), "BusinessUnit")
    error_message = "BusinessUnit is a legacy tag and should not be applied."
  }

  assert {
    condition     = length(module.production.tags) == 6
    error_message = "Five standard tags plus one custom tag should be present."
  }
}

run "mysql_uses_its_own_port_and_engine" {
  command = plan

  assert {
    condition     = module.mysql.cluster_port == 3306
    error_message = "Aurora MySQL should default to port 3306."
  }

  assert {
    condition     = module.mysql.autoscaling_enabled == true
    error_message = "Autoscaling should engage when max_instance_count exceeds instance_count."
  }
}

run "production_is_protected" {
  command = plan

  assert {
    condition     = module.production.deletion_protection == true
    error_message = "Deletion protection must be forced on in prod."
  }

  assert {
    condition     = module.production.skip_final_snapshot == false
    error_message = "Prod must take a final snapshot on destroy."
  }

  assert {
    condition     = module.postgres.deletion_protection == false
    error_message = "Non-prod should not have deletion protection by default."
  }
}

run "supplied_password_is_not_regenerated" {
  command = plan

  assert {
    condition     = module.existing.password_generated == false
    error_message = "A supplied password should be used as-is."
  }

  assert {
    condition     = module.existing.master_password == "supplied-password-123"
    error_message = "The supplied password should flow through to the output."
  }
}

run "existing_subnet_group_is_respected" {
  command = plan

  assert {
    condition     = module.existing.db_subnet_group_name == "my-existing-subnet-group"
    error_message = "A supplied db_subnet_group_name should be used instead of creating one."
  }
}
