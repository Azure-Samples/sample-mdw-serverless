
import azure.functions as func
from azure.storage.blob import BlobServiceClient
import pandas as pd
import io
import uuid
import logging

def validate_input(file_uri, source_container, target_container, source_cs, target_cs ):
    '''
    Minimal input validation
    '''
    if (file_uri and source_container and target_container and target_cs and source_cs):
        return True
    else:
        logging.critical('fatal: split function invalid input payload') 
        return False


def read_source_file(blob_client_instance):
    '''
    Reads the content of a blob client and return a dataframe
    '''
    # get a handle to stream
    download_stream = blob_client_instance.download_blob()         
    # first read all the blob content into the stream
    zip_content = io.BytesIO(download_stream.readall())
    df = pd.read_json(zip_content,lines=True,compression='zip')
    logging.info('split function read file content.')
    return df

def write_to_parquet(dfv,parquet_container,file_partition,blob_service_client):
    '''
    This function, will write the dataframe to the target location, it will write it as parquest.
    The name of the file would be uuid
    '''
    file_name = f'{str(uuid.uuid4().hex)}.parquet'
    # change this to the partition scheme required
    parquet_file_path = f'{file_partition}/{file_name}'
    # create the blob clietn and write to it
    parquet_blob_client = blob_service_client.get_blob_client(container = parquet_container, blob = parquet_file_path)
    parquet_file = io.BytesIO()    
    dfv.to_parquet(parquet_file, engine = 'pyarrow')
    # after the load of the df, need to move it back to zero
    parquet_file.seek(0)
    logging.info(f'split function saved parquet file:{parquet_file_path}')
    parquet_blob_client.upload_blob(data = parquet_file)


def get_target_path(file_name,last_partition):
    '''
    The inputs are: 
    - The original file path: e.g. factory=1354010702/dataModelName=data_model_1/y=2022/m=06/d=24/sample.zip
    - The last directory (partition) it needs to be in (e.g. 23)
    The output would be the corresponding path at the target container, 
    thus the main assumptionm here that the only modification is the last directory.
    '''
    splt = file_name.split("/")
    lenght = len(splt)
    # initi with the first element
    path = f'{splt[0]}/'
    # take the partial path to the last partition
    apth = splt[1:lenght-2]
    for itm in apth:
        path = f'{path}/{itm}'
    return f'{path}/d={last_partition}'

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('split function processed a request.')
    '''
    The function reads the provided file, since each file may contain rows from diffrent days, it will split the file per the day
    Note, that one can alter the logic to perform diffrent level of split
    The json payload will include:
    file_name - specific location of the file (zipped)
    zipped_file_name - the name of the file within the zip archive
    file_container - the container of the file
    target_container - usualy will be 'silver'
    target_path - the directory containing the splited files (../silver/xyz/qwe/y=2022/m=08/)
    source_cs - the connection string to the source container/folder
    target_cs - the connection string to the target folder
    the function will place the data per day in a file under the folder d=xx with guid.parquet name

    '''   
    try:
        req_body = req.get_json()
        logging.info('split function got payload.')
    except ValueError:
        logging.critical('fatal: split function called without payload.')
        pass
    else:
        file_name = req_body.get('file_name')
        source_container = req_body.get('source_container')
        target_container = req_body.get('target_container')        
        source_cs = req_body.get('source_cs')
        target_cs = req_body.get('target_cs')
    if validate_input(file_name,source_container,target_container,target_cs,source_cs):
        # create the blob clients
        blob_service_source = BlobServiceClient.from_connection_string(source_cs)
        blob_service_target = BlobServiceClient.from_connection_string(target_cs)
        # read the source file to a data frame
        blob_client = blob_service_source.get_blob_client(container = source_container, blob = file_name)
        df = read_source_file(blob_client)
        # Split to an array of data frames, first take all the dates, 
        # Then iterate over the items and query the original df, creating an array of df
        date_array = df["date"].unique()
        print(date_array[0])
        for date in date_array:
            vdf = df.query("date == @date")
            # write the df as parquet files
            write_to_parquet(vdf, target_container, get_target_path(file_name,pd.to_datetime(date).day),blob_service_target)
        logging.info('split function completed.')
        return func.HttpResponse(
            "split function executed succesfuly",
            status_code=200)
    else:
        return func.HttpResponse(
             "Input failed validation",
             status_code=400
        )