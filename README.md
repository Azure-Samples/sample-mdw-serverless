---
page_type: sample
languages:
- bicep
- sql
products:
- azure-synapse-analytics
- azure-data-lake-gen2
- power-bi
---

# Serverless Modern Data Warehouse Sample using Azure Synapse Analytics and Power BI

End-to-end sample of a serverless modern data warehouse data processing pipeline for Power BI visualization. This sample demonstrates how to build a scalable and efficient data pipeline using Azure Synapse Analytics, and how to visualize the results in Power BI.

## Use Case

An organization with multiple factories and multiple data models is looking for a cost-effective solution that will provide their analytical team a cost-effective solution to analyse the data from all the factories. The factories periodically upload data into a storage account and the team is looking for an solution to analyse all this data from all the factories in a report.

An organization with multiple factories and data models is looking for a cost-effective solution that will allow their analytical team to combine and analyze data from all the factories in a single report. The factories periodically upload data to a storage account, and the solution should be able to process this data and provide insights to the analytical team.

The mechanism that authenticates the factories and allows them to upload data to the storage account, as well as the mechanism that controls which files have been processed, are out of scope for this sample. We recommend creating separate components for authentication and authorization, and for tracking the files to be processed.

## Architecture Diagram

![architecture](./images/art.png)

## Working with this sample

As part of this sample, we have included Bicep code that will deploy the minimum required Azure resources for the sample to run.

### Prerequisites

The following are the prerequisites for deploying this sample :

- [Azure CLI](https://docs.microsoft.com/en-us/dotnet/azure/install-azure-cli/)
- [Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install/)
- [Power BI Desktop](https://powerbi.microsoft.com/en-gb/desktop/)

> Note: Using PowerBI is an optional way to visulize data.

### Deployment of the Azure resources

1. Create a resource group in Azure where the sample resources will be deployed.

1. Clone or fork this repository and navigate to the ```sample-mdw-serverless/deploy/bicep``` folder.

1. Open the ```param.json``` file and provide your own values for the parameters. The ```suffix``` parameter will be used to create unique names for the Synapse and storage instances in Azure, so make sure to choose a value that is not already in use. The default setup is for a publicly accessible solution, so the startIP and endIP parameters allow access to Synapse from any IP address.

1. Open a command line and run the following command to deploy the sample resources to Azure:
```az deployment group create --resource-group <your-resource-group-name> --template-file main.bicep --parameters @param.json```

This operation may take a few minutes to complete. Once it is finished, you can verify that the resources were created successfully by checking the resource group in the Azure portal.

### Setup Synapse worksape

1. Open the newly created Synapse workspace.

1. Point the Synapse workspace to the cloned/forked repository using the repository link as shown in this [document](https://docs.microsoft.com/en-us/azure/synapse-analytics/cicd/source-control). 

1. In the Azure Synapse workspace, go to the Manage > Linked Services > medallion_storage > Parameters > suffix, and enter the same value that you used for the suffix parameter in the ```param.json``` file in the Bicep code. This will update the linked services and integration datasets that use the suffix value.

    ![linked service](./images/linked_service_update.png)

1. Run the 'Copy Data Samples' pipeline. This will copy the [control file](#control/table) and the [data samples](#sample-files) to your local repository. [See details.](#sample-files)
     > Note: You can use the ```Debug``` to get started quickly, or setup a trigger as described [here](https://docs.microsoft.com/en-us/azure/data-factory/concepts-pipeline-execution-triggers).


1. Run the 'bronze2silver - Copy' pipeline. This will run the Bronze to Silver transformations per factory and per data model. [See details.](#bronze-to-silver)

1. Go to Develop > SQL Scrips > Factories and open the ```InitDB``` script.

1. Run the first commands against the ```master``` database.

1. Run the remaining commands by order against the newly created DB. This pipeline will run the silver to gold data transformations. [See details.](#silver-to-gold)

1. Open the ```Create-External-Tables``` script, replace the ```suffix``` with the value you used throughout the sample and the ```SAS token``` to access your storage account. Run the commands by order.

1. Open Power BI Desktop and follow the steps in this [document](https://docs.microsoft.com/en-us/power-apps/maker/data-platform/export-to-data-lake-data-powerbi#prerequisites) to connect your Gold Data Lake storage to Power BI Desktop.

1. Optionally, you can also set up an automated DevOps pipeline using [these instructions](./deploy/DevOps/README.md).

## Details

### Storage account


### Sample files

The sample files consist of daily dropped data in zip format. Each zip file contains a data file with a JSON per line.

```JSON
{"dataModelName":"data_model_1","operation":"U","factory":1354010702,"lineId":14871,"date":"2022-06-22T00:00:00","feature1":1,"dim":73,"yield":37307}
{"dataModelName":"data_model_1","operation":"U","factory":1354010702,"lineId":14872,"date":"2022-06-22T00:00:00","feature1":1,"dim":73,"yield":37306}
{"dataModelName":"data_model_1","operation":"U","factory":1354010702,"lineId":14873,"date":"2022-06-23T00:00:00","feature1":1,"dim":73,"yield":37305}
{"dataModelName":"data_model_1","operation":"U","factory":1354010702,"lineId":14874,"date":"2022-06-23T00:00:00","feature1":1,"dim":73,"yield":37304}
{"dataModelName":"data_model_1","operation":"U","factory":1354010702,"lineId":14875,"date":"2022-06-23T00:00:00","feature1":1,"dim":73,"yield":37303}
{"dataModelName":"data_model_1","operation":"U","factory":1354010702,"lineId":14876,"date":"2022-06-24T00:00:00","feature1":1,"dim":73,"yield":37302}
{"dataModelName":"data_model_1","operation":"U","factory":1354010702,"lineId":14877,"date":"2022-06-24T00:00:00","feature1":1,"dim":73,"yield":37307}
{"dataModelName":"data_model_1","operation":"U","factory":1354010702,"lineId":14878,"date":"2022-06-24T00:00:00","feature1":1,"dim":73,"yield":37300}

```

### Control Table

A control table is used to store information about the data uploaded into browse layer. This table stores the location of all the uploaded files per factory, the data model, uploaded date and if the file was already processed or not.

FactoryID | DataModelName | FileLocation | UpdateDate | Processed
---|---|--- |--- |---
1354010702 | data_model_1 | factory=1354010702/dataModelName=data_model_1/y=2022/m=06/d=25| 2022-06-25 | false
1354010702 | data_model_2 | factory=1354010702/dataModelName=data_model_2/y=2022/m=06/d=25| 2022-06-25 | true
1353534654 | data_model_1 | factory=1353534654/dataModelName=data_model_1/y=2022/m=06/d=26| 2022-06-26 | true
... | ... | ... | ... | ...

Every time a new file lands in the bronze layer, or it is processed, this table must be automatically updated by another process (out of scope for this sample).

> Note: To keep this sample simple, the control information was hardcoded in a JSON file named dropped_files.json (manual edit to the control JSON file can be done directly from the portal). However, for production this is an anti-pattern and we strongly advise using a metadata table and a process to automatically update it.

### Bronze to Silver

In the bronze2silver pipelines, a Lookup activity will read the control table entries.
Then a ForEach avtivity, per data model, will iterate over all entries of the control table. Inside the ForEach, a IfCondition activity will filter all unprocessed files. For each unprocessed file, a Copy, a Notebook or an Azure Function activity will be executed. All these three option are explained in more detail in the next sections. We encourage you to use the pipeline that best suits your requirements. Please evaluate the available options and choose the one that meets your needs and goals in the most effective way.

All the different pipelineas are storing the files in parquet format in the silver container. 

#### Copy Activity - Pipeline 'bron2silver - Copy'

This pipeline leverages a Copy activity to copy the files from bronze to silver container. 
![pipeline](./images/factories_pipeline.PNG)

Inside each ForEach() activity, there is a IfCondition() activity, which filters the unprocessed data for specific data model.

##### Copy activity Mapping
In order to extract the nested JSON values you will have to map these values to a type in the Mapping tab of the Copy() activity.

Each type of file will have to be mapped at least once. While this process might be tedious, you will need to spend time on it, to ensure that all the necessary fields are assigned to right type and saved during the sink. Additional fields (e.g calculated/derived) can also be added in this tab.

![mapping](./images/mapping.png)

#### Azure Function - Pipeline 'bron2silver - Azure Function'

In some cases daily files may contain previous dates of data. In such scenarios it is recomended to fix alter the directory structure, and reflect the right location/partition.

Read more on this function [here](./functions/getting_started.md).

When calling the azure function ('bronze2silver - Azure Function' Pipeline), you would need to have the following post payload defined in the activity, using the dynamic content.

```
@concat('{',
        '"file_name"',':','"',item().FileLocation,'/daily.zip"', ',',
        '"source_container"',':','"',pipeline().parameters.source_container,'"', ',',
        '"target_cs"',':','"',pipeline().parameters.target_container,'"', ',',
        '"source_cs"',':','"',activity('Get CS from AKV').output.value,'"', ',',
        '"target_cs"',':','"',activity('Get CS from AKV').output.value,'"',
        '}'
        )
```

#### Notebook (Spark Pool) - Pipeline 'bron2silver - Notebook'

Alternatively to the Azure Fuction, there is also the option to leverage a Notebook ('bronze2silver - Notebook' Pipeline). The code also addresses the scenario where it is recomended to fix alter the directory structure, and reflect the right location/partition. This option is recommended when the amount of data to be processed is big (eg. initial load). 

#### Write to silver

The linked service to the storage account is used to write the files to the silver container and save the data in a parquet format. The original directory structure is kept.

The parquet files can be queried using Synapse Serverless SQL Pool. See the following example:

```sql
select * 
FROM
    OPENROWSET(
        BULK 'https://<storage-account-name>.dfs.core.windows.net/<container>/<folder>/**',
        FORMAT = 'PARQUET'
    ) AS [result]
```

### Silver to Gold

As described in this [document](https://docs.microsoft.com/en-us/azure/synapse-analytics/sql/develop-tables-cetas) there are few initialization activities. In the following sections, a Serverless SQL pool is used.

#### Create a Database, master key & scoped credentials

```sql
-- Create a DB
CREATE DATABASE <db_name>
-- Create Master Key (if not already created)
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<password>';
-- Create credentials
CREATE DATABASE SCOPED CREDENTIAL [factories_cred]
WITH IDENTITY='SHARED ACCESS SIGNATURE',  
SECRET = ''

```

In order to create SAS token, you can follow this [document](https://docs.microsoft.com/en-us/azure/cognitive-services/translator/document-translation/create-sas-tokens?tabs=Containers). Alternate solution in case you want one scoped credentials that can be used for the entire storage account. This can be created using the portal:

- Click on 'Shared Access Signature' in the Security + Networking blads:

![blade](./images/blade.png)

- Select required operation, IP restrictions, dates etc:

![sas](./images/sas.png)

#### Create External File format

The following statement needs to be executed once per workspace:

```sql
IF NOT EXISTS (SELECT * FROM sys.external_file_formats WHERE name = 'SynapseParquetFormat') 
    CREATE EXTERNAL FILE FORMAT [SynapseParquetFormat] 
    WITH ( FORMAT_TYPE = PARQUET)
GO
```

#### Create External Source

The following is creating an external data source, which will host the gold tables.

```sql
IF NOT EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'gold') 
    CREATE EXTERNAL DATA SOURCE [gold] 
        WITH (
            LOCATION = 'abfss://<gold container>@<storage account>.dfs.core.windows.net' 
        )
GO
```

#### Create external table

Finally lets make use of the resources and data created, by creating the external table, this sample is essentially coping the entire content of all parquet files into a single table, this is the place where additional aggregations, filtering can be applied.

```sql
CREATE EXTERNAL TABLE table_name
    WITH (
        LOCATION = '<specific location within the gold container>/',  
        DATA_SOURCE = [gold],
        FILE_FORMAT = [SynapseParquetFormat]  
)
    AS 
    select * 
    FROM
    OPENROWSET(
        BULK 'https://<storage account>.dfs.core.windows.net/<silver container>/<folder>/**',
        FORMAT = 'PARQUET'
    ) AS [result]

```

After this activity is completed, you can access the table using the serverless SQL pool, or from [Power BI](https://docs.microsoft.com/en-us/power-apps/maker/data-platform/export-to-data-lake-data-powerbi#prerequisites).
