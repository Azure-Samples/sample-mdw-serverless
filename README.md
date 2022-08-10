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

# sample-mdw-serverless

End to end sample of data processing to be viewed in pbi.

## Use Case

Contoso is an organization with multiple factories and multiple data models. Each factory upload data periodically to a storage account. Contoso is looking for cost-effective solution, which will be able to provide their analytical team a better view of the data.

Contoso already developed a component named ControlBox, its capabilities (out of scope for this sample) are:

- Authenticate and authorize factories.

- Provide factories with SAS token, used by the factory to upload periodic data.

- Register new file uploaded in the storage account in a control table.

- Update the control table each time a file is processed.

## Architecture

The following diagram illustrates the solution implemented by Contoso. It leverages serverless computing for data movement, cleansing, restructure and reporting.

![architecture](./images/art.png)

## Working with this sample

As part of the sample we included bicep code, which will create the minimum required resources for it to run.

### Prerequisites

The following are the prerequisites for deploying this sample :

- [Azure CLI](https://docs.microsoft.com/en-us/dotnet/azure/install-azure-cli/)
- [Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install/)
- [Power BI Desktop](https://powerbi.microsoft.com/en-gb/desktop/)
 
> Note: Using PowerBI is an optional way to visulize data.

### Setup and deployment

1. Create a resource group in which the resources would be created.

2. Clone or fork this repository.

3. Edit ```deploy/bicep/param.json``` file and provide your values, they should be self explained.

    > Note: The ```suffix``` will be used to create the synapse and the storage instances with a unique namespace in Azure. If the suffix is already in use, please choose another one.

    > Another Note: The default setup is for publicly open solution. This is the reason start and stop IPs allow for any IP address access to Synapse.

4. Open a command line, go to  'sample-mdw-serverless/deploy/bicep' and run ```az deployment group create --resource-group <your rg name> --template-file main.bicep --parameters @param.json``` on the 'bicep' folder. This operation may take a few minutes to complete.

5. Open the newly created Synapse workspace.

6. Point the Synapse workspace to the cloned/forked repository as shown in this [document](https://docs.microsoft.com/en-us/azure/synapse-analytics/cicd/source-control).

7. In the workspace, go to Manage > Linked Services > medallion_storage > Parameters > suffix and the same value you gave in the bicep ```param.json```. Once you update it would be reflected in all affected integration datasets.

    ![linked service](./images/linked_service_update.png)

8. Run the 'Copy Data Samples' pipeline. This will copy the [control file](#control/table) and the [data samples](#sample-files) to your local repository. [See details.](#sample-files)

9. Run the 'Process Factories Data'. This will run the Bronze to Silver transformations per factory and per data model. [See details.](#bronze-to-silver)

10. Go to and Develop > SQL Scrips > Factories and open the ```InitDB``` script.

11. Run the first commands against the ```master``` database.

12. Run the remaining commands by order against the newly created DB. This pipeline will run the silver to gold data transformations. [See details.](#silver-to-gold)

13. Open the ```Create-External-Tables``` script, replace the ```suffix``` with the one used throughout the sample and the SAS token to access your storage account. Run the commands by order.

14. Open Power BI Desktop and follow the steps in this [document](https://docs.microsoft.com/en-us/power-apps/maker/data-platform/export-to-data-lake-data-powerbi#prerequisites) to connect your Gold Data Lake storage to Power BI Desktop.

15. Optionally, you can set up an automated DevOps pipeline using [these instructions](./deploy/README.md).

## Details

### Sample files

The sample files consist of daily dropped data in zip format. Each zip file contains a data file with a JSON per line.

```JSON
{"dataModelName":"data_model_1","operation":"I","data":{"factory":1354010702,"lineId":15025,"date":"2022-06-24T00:00:00","feature1":0,"dim":0,"yield":5223}}
{"dataModelName":"data_model_1","operation":"I","data":{"factory":1354010702,"lineId":15027,"date":"2022-06-24T00:00:00","feature1":0,"dim":0,"yield":865}}
{"dataModelName":"data_model_2","operation":"U","data":{"factory":1354010702,"lineId":15043,"date":"2022-06-25T00:00:00","feature1":0,"dim":0,"yield":235}}
{"dataModelName":"data_model_2","operation":"U","data":{"factory":1354010702,"lineId":15045,"date":"2022-06-25T00:00:00","feature1":0,"dim":0,"yield":325}}
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

The data from the different factories lands in the same storage account. The storage account has a container per layer of a Medallion Architecture, bronze, silver and gold. Inside each container there is a folder per factory, per data model and per day. See the following example:

```<your_storage>/bronze/factory=1782/dataModelName=data_model_1/y=2022/m=07/d=24```

In the Synapse workspace, a Lookup activity will read the control table information.
There is a ForEach() per data model that will iterate over all factories with unprocessed files. For each factory and data model the relevant business logic would be applied. To keep this sample more generic, the files are just copied from bronze to silver and converted to a parquet format.

![pipeline](./images/factories_pipeline.PNG)

Inside each ForEach() activity, there is a IfCondition() activity, which filters the unprocessed data for specific data model.

#### Mapping

Each type of file will have to be mapped at least once. While this process might be tedious, you will need to spend time on it, to ensure that all the necessary fields are assigned to right type and saved during the sink. Additional fields (e.g calculated/derived) can also be added in this tab.

![mapping](./images/mapping.png)

> As for time, in order to extract the nested JSON values you will have to map these values to a type in the Mapping tab of the Copy() activity.

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
