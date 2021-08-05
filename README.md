# Terraform

This is the Terraform configuration that needs to provision the infrastructure required in Google Cloud to run [this](https://github.com/apichick/beam-summit-2021-flex-templates-cicd-demo.git) demo.

## Pre-requisities

The following sfotware needs to be installed in the machine where you are running this:

* [Terraform](https://www.terraform.io/)
* gcloud CLI

## Provisioning resources in Google Cloud

To proceed with the provisioning in Google Cloud follow the steps below:

1. Authenticate to Google Cloud

        gcloud auth application-default login

2. Clone this Github repository

        git clone git@github.com:apichick/beam-summit-2021-terraform.git

3. Change to the ```beam-summit-2021-terraform``` directory

        cd beam-summit-2021-terraform

4. Create a file ```terraform.tfvars``` and assign a value to the following variables:

        billing_account_id=
        parent=
        project_id=
        app_engine_location=
        bucket_location=
        github_organization=
        github_repo=

    | Name   |      Description      |  Type |
    |----------|-------------|------|
    | billing_account_id | The id of your Google Cloud billing account | string |
    | parent | The id of the organization (organizations/ORGANIZATION_ID) or folder (folders/FOLDER_ID) where the project will be created |   string |
    | project_id | The id of the project | string |
    | app_engine_location | The location of the App Engine application (e.g., europe-west) | string |
    | bucket_location | The location of the bucket where the flex template will be created (e.g., EU) | string |
    | github_organization | The Github organization where the repo containing the flex template code is |   string |
    | github_rep | The Github repo where the code of the flex table is available |    $1 |

5. Initialize terraform

        terraform init

6. Apply the changes

        terraform apply
