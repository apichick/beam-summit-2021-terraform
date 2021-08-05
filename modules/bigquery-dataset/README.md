# Google Cloud Bigquery Module

This module allows managing a single BigQuery dataset, including access configuration, tables and views.

## TODO

- [ ] check for dynamic values in tables and views
- [ ] add support for external tables

## Examples

### Simple dataset with access configuration

Access configuration defaults to using the separate `google_bigquery_dataset_access` resource, so as to leave the default dataset access rules untouched.

You can choose to manage the `google_bigquery_dataset` access rules instead via the `dataset_access` variable, but be sure to always have at least one `OWNER` access and to avoid duplicating accesses, or `terraform apply` will fail.

The access variables are split into `access_roles` and `access_identities` variables, so that dynamic values can be passed in for identities (eg a service account email generated by a different module or resource). The `access_views` variable is separate, so as to allow proper type constraints.

```hcl
module "bigquery-dataset" {
  source     = "./modules/bigquery-dataset"
  project_id = "my-project"
  id          = "my-dataset"
  access = {
    reader-group   = { role = "READER", type = "group" }
    owner          = { role = "OWNER", type = "user" }
    project_owners = { role = "OWNER", type = "special_group" }
    view_1         = { role = "READER", type = "view" }
  }
  access_identities = {
    reader-group   = "playground-test@ludomagno.net"
    owner          = "ludo@ludomagno.net"
    project_owners = "projectOwners"
    view_1         = "my-project|my-dataset|my-table"
  }
}
# tftest:modules=1:resources=5
```

### IAM roles

Access configuration can also be specified via IAM instead of basic roles via the `iam` variable. When using IAM, basic roles cannot be used via the `access` family variables.

```hcl
module "bigquery-dataset" {
  source     = "./modules/bigquery-dataset"
  project_id = "my-project"
  id          = "my-dataset"
  iam = {
    "roles/bigquery.dataOwner" = ["user:user1@example.org"]
  }
}
# tftest:modules=1:resources=2
```

roles/bigquery.dataOwner

### Dataset options

Dataset options are set via the `options` variable. all options must be specified, but a `null` value can be set to options that need to use defaults.

```hcl
module "bigquery-dataset" {
  source     = "./modules/bigquery-dataset"
  project_id = "my-project"
  id         = "my-dataset"
  options = {
    default_table_expiration_ms     = 3600000
    default_partition_expiration_ms = null
    delete_contents_on_destroy      = false
  }
}
# tftest:modules=1:resources=1
```

### Tables and views

Tables are created via the `tables` variable, or the `view` variable for views. Support for external tables will be added in a future release.

```hcl
locals {
  countries_schema = jsonencode([
    { name = "country", type = "STRING" },
    { name = "population", type = "INT64" },
  ])
}

module "bigquery-dataset" {
  source     = "./modules/bigquery-dataset"
  project_id = "my-project"
  id         = "my_dataset"
  tables = {
    countries = {
      friendly_name       = "Countries"
      labels              = {}
      options             = null
      partitioning        = null
      schema              = local.countries_schema
      deletion_protection = true
    }
  }
}
# tftest:modules=1:resources=2
```

If partitioning is needed, populate the `partitioning` variable using either the `time` or `range` attribute.

```hcl
locals {
  countries_schema = jsonencode([
    { name = "country", type = "STRING" },
    { name = "population", type = "INT64" },
  ])
}

module "bigquery-dataset" {
  source     = "./modules/bigquery-dataset"
  project_id = "my-project"
  id         = "my-dataset"
  tables = {
    table_a = {
      friendly_name = "Table a"
      labels        = {}
      options       = null
      partitioning = {
        field = null
        range = null # use start/end/interval for range
        time  = { type = "DAY", expiration_ms = null }
      }
      schema              = local.countries_schema
      deletion_protection = true
    }
  }
}
# tftest:modules=1:resources=2
```

To create views use the `view` variable. If you're querying a table created by the same module `terraform apply` will initially fail and eventually succeed once the underlying table has been created. You can probably also use the module's output in the view's query to create a dependency on the table.

```hcl
locals {
  countries_schema = jsonencode([
    { name = "country", type = "STRING" },
    { name = "population", type = "INT64" },
  ])
}

module "bigquery-dataset" {
  source     = "./modules/bigquery-dataset"
  project_id = "my-project"
  id         = "my_dataset"
  tables = {
    countries = {
      friendly_name       = "Countries"
      labels              = {}
      options             = null
      partitioning        = null
      schema              = local.countries_schema
      deletion_protection = true
    }
  }
  views = {
    population = {
      friendly_name       = "Population"
      labels              = {}
      query               = "SELECT SUM(population) FROM my_dataset.countries"
      use_legacy_sql      = false
      deletion_protection = true
    }
  }
}

# tftest:modules=1:resources=3
```

<!-- BEGIN TFDOC -->
## Variables

| name | description | type | required | default |
|---|---|:---: |:---:|:---:|
| id | Dataset id. | <code title="">string</code> | ✓ |  |
| project_id | Id of the project where datasets will be created. | <code title="">string</code> | ✓ |  |
| *access* | Map of access rules with role and identity type. Keys are arbitrary and must match those in the `access_identities` variable, types are `domain`, `group`, `special_group`, `user`, `view`. | <code title="map&#40;object&#40;&#123;&#10;role &#61; string&#10;type &#61; string&#10;&#125;&#41;&#41;">map(object({...}))</code> |  | <code title="&#123;&#125;&#10;validation &#123;&#10;condition &#61; can&#40;&#91;&#10;for k, v in var.access :&#10;index&#40;&#91;&#34;OWNER&#34;, &#34;READER&#34;, &#34;WRITER&#34;&#93;, v.role&#41;&#10;&#93;&#41;&#10;error_message &#61; &#34;Access role must be one of &#39;OWNER&#39;, &#39;READER&#39;, &#39;WRITER&#39;.&#34;&#10;&#125;&#10;validation &#123;&#10;condition &#61; can&#40;&#91;&#10;for k, v in var.access :&#10;index&#40;&#91;&#34;domain&#34;, &#34;group&#34;, &#34;special_group&#34;, &#34;user&#34;, &#34;view&#34;&#93;, v.type&#41;&#10;&#93;&#41;&#10;error_message &#61; &#34;Access type must be one of &#39;domain&#39;, &#39;group&#39;, &#39;special_group&#39;, &#39;user&#39;, &#39;view&#39;.&#34;&#10;&#125;">...</code> |
| *access_identities* | Map of access identities used for basic access roles. View identities have the format 'project_id|dataset_id|table_id'. | <code title="map&#40;string&#41;">map(string)</code> |  | <code title="">{}</code> |
| *dataset_access* | Set access in the dataset resource instead of using separate resources. | <code title="">bool</code> |  | <code title="">false</code> |
| *encryption_key* | Self link of the KMS key that will be used to protect destination table. | <code title="">string</code> |  | <code title="">null</code> |
| *friendly_name* | Dataset friendly name. | <code title="">string</code> |  | <code title="">null</code> |
| *iam* | IAM bindings in {ROLE => [MEMBERS]} format. Mutually exclusive with the access_* variables used for basic roles. | <code title="map&#40;list&#40;string&#41;&#41;">map(list(string))</code> |  | <code title="">{}</code> |
| *labels* | Dataset labels. | <code title="map&#40;string&#41;">map(string)</code> |  | <code title="">{}</code> |
| *location* | Dataset location. | <code title="">string</code> |  | <code title="">EU</code> |
| *options* | Dataset options. | <code title="object&#40;&#123;&#10;default_table_expiration_ms     &#61; number&#10;default_partition_expiration_ms &#61; number&#10;delete_contents_on_destroy      &#61; bool&#10;&#125;&#41;">object({...})</code> |  | <code title="&#123;&#10;default_table_expiration_ms     &#61; null&#10;default_partition_expiration_ms &#61; null&#10;delete_contents_on_destroy      &#61; false&#10;&#125;">...</code> |
| *tables* | Table definitions. Options and partitioning default to null. Partitioning can only use `range` or `time`, set the unused one to null. | <code title="map&#40;object&#40;&#123;&#10;friendly_name &#61; string&#10;labels        &#61; map&#40;string&#41;&#10;options &#61; object&#40;&#123;&#10;clustering      &#61; list&#40;string&#41;&#10;encryption_key  &#61; string&#10;expiration_time &#61; number&#10;&#125;&#41;&#10;partitioning &#61; object&#40;&#123;&#10;field &#61; string&#10;range &#61; object&#40;&#123;&#10;end      &#61; number&#10;interval &#61; number&#10;start    &#61; number&#10;&#125;&#41;&#10;time &#61; object&#40;&#123;&#10;expiration_ms &#61; number&#10;type &#61; string&#10;&#125;&#41;&#10;&#125;&#41;&#10;schema              &#61; string&#10;deletion_protection &#61; bool&#10;&#125;&#41;&#41;">map(object({...}))</code> |  | <code title="">{}</code> |
| *views* | View definitions. | <code title="map&#40;object&#40;&#123;&#10;friendly_name       &#61; string&#10;labels              &#61; map&#40;string&#41;&#10;query               &#61; string&#10;use_legacy_sql      &#61; bool&#10;deletion_protection &#61; bool&#10;&#125;&#41;&#41;">map(object({...}))</code> |  | <code title="">{}</code> |

## Outputs

| name | description | sensitive |
|---|---|:---:|
| dataset | Dataset resource. |  |
| dataset_id | Dataset id. |  |
| id | Fully qualified dataset id. |  |
| self_link | Dataset self link. |  |
| table_ids | Map of fully qualified table ids keyed by table ids. |  |
| tables | Table resources. |  |
| view_ids | Map of fully qualified view ids keyed by view ids. |  |
| views | View resources. |  |
<!-- END TFDOC -->
