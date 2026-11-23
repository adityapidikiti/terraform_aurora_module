# Guardrails: invalid input must be rejected at plan time.
#   terraform test -filter=validation.tftest.hcl

mock_provider "aws" {}
mock_provider "random" {}

run "accepts_valid_cluster" {
  command = plan

  module {
    source = "../"
  }

  variables {
    name               = "ok"
    subnet_ids         = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_ids = ["sg-0123456789abcdef0"]
    app                = "t"
    managed_by         = "t"
    environment        = "dev"
  }
}

run "rejects_unknown_engine" {
  command = plan

  module {
    source = "../"
  }

  variables {
    name               = "bad"
    subnet_ids         = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_ids = ["sg-0123456789abcdef0"]
    engine             = "aurora-oracle"
    app                = "t"
    managed_by         = "t"
    environment        = "dev"
  }

  expect_failures = [var.engine]
}

run "rejects_single_az" {
  command = plan

  module {
    source = "../"
  }

  variables {
    name               = "bad"
    subnet_ids         = ["subnet-0123456789abcdef0"]
    security_group_ids = ["sg-0123456789abcdef0"]
    app                = "t"
    managed_by         = "t"
    environment        = "dev"
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_invalid_instance_count" {
  command = plan

  module {
    source = "../"
  }

  variables {
    name               = "bad"
    subnet_ids         = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_ids = ["sg-0123456789abcdef0"]
    instance_count     = 0
    app                = "t"
    managed_by         = "t"
    environment        = "dev"
  }

  expect_failures = [var.instance_count]
}

run "rejects_short_password" {
  command = plan

  module {
    source = "../"
  }

  variables {
    name               = "bad"
    subnet_ids         = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_ids = ["sg-0123456789abcdef0"]
    master_password    = "short"
    app                = "t"
    managed_by         = "t"
    environment        = "dev"
  }

  expect_failures = [var.master_password]
}

run "rejects_backup_retention_over_35_days" {
  command = plan

  module {
    source = "../"
  }

  variables {
    name                    = "bad"
    subnet_ids              = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_ids      = ["sg-0123456789abcdef0"]
    backup_retention_period = 40
    app                     = "t"
    managed_by              = "t"
    environment             = "dev"
  }

  expect_failures = [var.backup_retention_period]
}

run "rejects_monitoring_without_role" {
  command = plan

  module {
    source = "../"
  }

  variables {
    name                = "bad"
    subnet_ids          = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_ids  = ["sg-0123456789abcdef0"]
    monitoring_interval = 60
    app                 = "t"
    managed_by          = "t"
    environment         = "dev"
  }

  expect_failures = [var.monitoring_role_arn]
}

run "rejects_invalid_monitoring_interval" {
  command = plan

  module {
    source = "../"
  }

  variables {
    name                = "bad"
    subnet_ids          = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_ids  = ["sg-0123456789abcdef0"]
    monitoring_interval = 45
    monitoring_role_arn = "arn:aws:iam::123456789012:role/monitoring"
    app                 = "t"
    managed_by          = "t"
    environment         = "dev"
  }

  expect_failures = [var.monitoring_interval]
}

run "rejects_invalid_name" {
  command = plan

  module {
    source = "../"
  }

  variables {
    name               = "Bad_Name"
    subnet_ids         = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_ids = ["sg-0123456789abcdef0"]
    app                = "t"
    managed_by         = "t"
    environment        = "dev"
  }

  expect_failures = [var.name]
}
