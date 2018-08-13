# Import
import pymongo
from datetime import datetime, date
from random import randint
import cx_Oracle
import re
from datetime import datetime

from typing import Callable, List, Dict



def create_collection_if_not_exists(mongo_database: pymongo.database.Database, collection_name: str):
    """
        Create a mongodb collection if it doesn't exist
    """
    if collection_name in mongo_database.collection_names():
        print('Collection "{collection}" already created'.format(collection=collection_name))
    else:
        mongo_database.create_collection(collection_name)
        print('Created collection "{c}"'.format(c=collection_name))


def export_data_from_oracle_to_mongodb(oracle_server: str, 
                                       oracle_port: int, 
                                       oracle_sid: str, 
                                       oracle_user: str, 
                                       oracle_password: str,
                                       mongodb_connection_string: str, 
                                       mongodb_database: str, 
                                       mongodb_collection: str,
                                       sql_query: str,
                                       create_mongodb_collection_if_not_exist: bool=False,
                                       num_rows_fetch: int=1000,
                                       transform: Callable[[List[Dict]], List[Dict]]=None):
    """
    Exports the data of a query from oracle to a mongodb collection    
    Parameters:
    -----------
        - mongodb_connection_string: the connection string, without the database name
            more info in: https://docs.mongodb.com/manual/reference/connection-string/
        - sql_query: the query MUST NOT have a semi-colon ";" at the end of the sentence!
        - num_rows_fetch: 1000 is a good number to start with. If it's too small, it will 
            take longer because mongodb will need to do a lot of commits
        - transform: to make the function more generic in an ETL process. Function applied after 
            every fetch (in Oracle) and before inserting (in MongoDB)
            If some row transformation is needed (like combining or casting columns) it can be done here    
    """
       
    error_exception = None
    
    ## create connections
    
    # create oracle connection
    try:        
        dsn_tns = cx_Oracle.makedsn(oracle_server, oracle_port, oracle_sid)
        oracle_conn = cx_Oracle.connect(oracle_user, oracle_password, dsn_tns)
    except:
        raise Exception("could not create a connection to Oracle database")

    # create mongodb connection
    try:        
        mongodb_client = pymongo.MongoClient(mongodb_connection_string)
        mongodb_db = mongodb_client.get_database(mongodb_database)
        if create_mongodb_collection_if_not_exist:
            create_collection_if_not_exists(mongodb_db, mongodb_collection)
        collection = mongodb_db[mongodb_collection]        
    except:
        # if an error ocurred while creating the connection to mongodb, oracle connection would be already created
        # we need to destroy it
        if oracle_conn is not None:
            oracle_conn.close()
        if mongodb_client is not None:
            mongodb_client.close()
        raise Exception("could not create a connection to MongoDB server / database")

    ## exporting data
    try:
        cursor = oracle_conn.cursor()
        print ('executing the query in Oracle server...')
        cursor.execute(sql_query)

        # column names in lowercase because it's case sensitive
        ora_column_names = [col[0].lower() for col in cursor.description]
        
        # export rows fetching 'num_rows_fetch' every time
        print ('start exporting data...')
        rows = cursor.fetchmany(num_rows_fetch)
        while len(rows) > 0:
            # convert rows to a list of dicts
            mongo_rows = [dict(zip(ora_column_names, row)) for row in rows]
            
            ## "Transform" the rows
            if transform:
                mongo_rows = transform(mongo_rows)
            
            # insert into mongodb
            collection.insert_many(mongo_rows)
            # fetch next rows
            rows = cursor.fetchmany(num_rows_fetch)
            
        print('successfully exported the data from Oracle to MongoDB')

    except cx_Oracle.Error as error:
        error_exception = error

    finally:
        cursor.close()
        oracle_conn.close()
        mongodb_client.close()

    if error_exception:
        raise Exception(error_exception)