# Copyright 2021 @apichick
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module "project" {
  source              = "./modules/project"
  billing_account     = var.billing_account_id
  name                = var.project_id
  parent              = var.parent
  auto_create_network = true
  services = [
    "cloudbuild.googleapis.com",
    "pubsub.googleapis.com",
    "dataflow.googleapis.com"
  ]
}

resource "google_app_engine_application" "app" {
  project     = module.project.project_id
  location_id = var.app_engine_location
}

module "tweet-publisher-sa" {
  source       = "./modules/iam-service-account"
  project_id   = module.project.project_id
  name         = "tweet-publisher"
  generate_key = true
}

module "tweet-processor-sa" {
  source       = "./modules/iam-service-account"
  project_id   = module.project.project_id
  name         = "tweet-processor"
  generate_key = false
  iam_project_roles = {
    (module.project.project_id) = [
      "roles/dataflow.worker",
      "roles/pubsub.editor",
      "roles/storage.objectAdmin",
      "roles/viewer"
    ]
  }
}

module "bucket" {
  source     = "./modules/gcs"
  project_id = module.project.project_id
  name       = module.project.project_id
  location = var.bucket_location
}

module "tweets-pubsub" {
  source     = "./modules/pubsub"
  project_id = module.project.project_id
  name       = "tweets"
  iam = {
    "roles/pubsub.publisher" = [
      module.tweet-publisher-sa.iam_email
    ]
  }
}

module "trends-pubsub" {
  source     = "./modules/pubsub"
  project_id = module.project.project_id
  name       = "trends"
  iam = {
    "roles/pubsub.publisher" = [
      module.tweet-processor-sa.iam_email
    ]
  }
  subscriptions = {
    trends-push = null
  }
  push_configs = {
    trends-push = {
      endpoint   = "https://${google_app_engine_application.app.default_hostname}/notify"
      attributes = null
      oidc_token = null
    }
  }
}

resource "local_file" "tweet-publisher-sa-key-file" {
  content  = base64decode(module.tweet-publisher-sa.key.private_key)
  filename = "${path.module}/tweet-publisher-sa-key.json"
}

resource "google_cloudbuild_trigger" "trigger" {
  provider = google-beta
  project = module.project.project_id
  filename = "cloudbuild.yaml"

  github {
    owner = var.github_organization
    name = var.github_repo
    push {
      branch = ".*"
    }
  }

  substitutions = {
      _IMAGE_NAME = "tweettrends"
      _TEMPLATE_GCS_LOCATION = "gs://${module.bucket.name}/dataflow/templates/tweettrends.json"
  }
}