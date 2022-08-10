# Automated CI/CD Pipeline

The goal behind the automation of the CI/CD pipeline is to be able
to provision the Synapse Analytics Pipeline in different environments
with the ability to override the parameters used by the pipeline.
These parameters are used both in the pipeline itself _and_ the
initialization SQL scripts that are triggered in the workspace.

To date, Azure Synapse Analytics doesn't support the interpolation
of parameters in workspace initialization scripts. For this reason,
this repository includes a custom GitHub Workflow that scans for
references to parameters (with the `parameters('key')` notation)
in the pipeline's ARM template and dynamically adds them to the
parameters file. This automation allows you to provision the pipeline
in new environments (e.g., Test -> Staging -> Prod) while ensuring
all parameter substitutions are respected.

## Copy the Workflow Files to the Publish Branch

After you run and publish the pipeline from Azure Synapse Analytics,
and assuming you've linked the Synapse Analytics workspace to the
GitHub repository, a new branch named `workspace_publish` should be
created automatically. This branch includes the ARM templates that
Azure Synapse Analytics needs in order to synchronize the state of
the pipeline with the GitHub repository.

In order for the automation to work, you'll need to copy two files
from the `main` branch to the automatically created
`workspace_publish` branch:

1. [`./scripts/autoinject_params.py`](../scripts/autoinject_params.py):
   This Python script is executed by a GitHub workflow each time
   a commit is pushed to the `workspace_publish` branch.
2. [`./.github/workflows/autoinject_params.yaml`](../.github/workflows/autoinject_params.yaml):
   This is the GitHub Workflow definition that executes the Python
   script and eventually commits the changes to the same branch.

You can create the files manually in the `workspace_publish` branch,
or alternatively, use your Git client to cherry-pick the files from
the `main` branch in the following way:

```shell
# Ensure you're up to date with the upstream repository:
git pull

# Ensure you're on "workspace_publish" branch:
git checkout workspace_publish

# Copy the files 
git checkout main ./scripts/autoinject_params.py
git checkout main ./.github/workflows/autoinject_params.yaml

# Stage, commit, and push the changes to the upstream GitHub repo:
git add .
git commit -m "Add automation workflow"
git push origin workspace_publish
```

## Validate the Workflow

The name of the directory under the `workspace_publish` branch that
Azure Synapse Analytics will create is derived from the workspace name
(e.g., `./medalionsynapse12`).

If the directory created under that branch has a different name, you will
need to change the values of the environment variables in the GitHub
Workflow (`./.github/workflows/autoinject_params.yaml`), e.g.:

```yaml
env:
  TEMPLATE_FILE: ./<TEMPLATES DIRECTORY>/TemplateForWorkspace.json
  PARAM_FILE: ./<TEMPLATES DIRECTORY>/TemplateParametersForWorkspace.json
  OUTPUT_FILE: ./injected_params/MedalionParams.json
```

## Test the changes

Once you've pushed the two automation files to the `workspace_publish`
branch, any change to the pipeline that you publish from Azure
Synapse Analytics will trigger the GitHub Action that's derived from
the workflow you've copied. To validate the success of the workflow,
navigate to the **Actions** tab in the GitHub repository and observe
the status of the Action run:

![GitHub Action](./gh_action.png)

## Create CI/CD Pipelines

This article outlines how to use an Azure DevOps pipelines and GitHub Actions to automate the deployment of the Azure Synapse workspace to another environment.

### Prerequisites

1. Prepare an Azure DevOps project for running the CI/CD pipelines.

1. Create a new Azure Synapse workspace, a blank workspace to deploy to.

1. Grant the necessary permissions. [More information here.](https://docs.microsoft.com/en-us/azure/synapse-analytics/cicd/continuous-integration-delivery#azure-synapse-analytics)

#### CI pipeline

Follow the steps bellow to create your CI pipeline:

1. In Azure [DevOps](https://dev.azure.com/), open the project you created for the release.

1. On the left menu, select **Pipelines > Pipelines**.

1. Create a new pipeline with Github as source and select your repository and the default build branch.
    ![pipeline_source](./pipeline_source.PNG)

1. Add tasks to the Stage View, one to download Pipeline Artifact and other to publish Pipeline Artifact.
    ![pipeline_tasks](./pipeline_tasks.PNG)

1. Configure the pipeline trigger. Enable continuos integration and set the Branch and Path filters.
    ![pipeline_tasks](./build_pipeline_triggers.PNG)

1. Run the pipeline. This will prepare the artifact for deployment.

#### CD pipeline

Follow the steps bellow to create your CD pipeline:

1. In Azure [DevOps](https://dev.azure.com/), open the project you created for the release.

1. On the left menu, select **Pipelines > Releases**.

1. Create a new pipeline and start with an Empty job.

1. Add the artifact and select your CI pipeline as source.

1. In the stage view, select View stage tasks. Add a Synapse deployment task.
    ![synapse_deployment](.\synapse_deployment.PNG)

1. Override the parameters used by the pipeline _and_ the SQL scripts.

    ![override_parameters](.\override_parameters.PNG)

1. Configure the Continuous deployment trigger.

    ![CD_pipeline_trigger](./CD_pipeline_trigger.PNG)

1. Configure the Pre-deployment conditions.

    ![pre_deployment_conditions](./pre_deployment_conditions.PNG)
