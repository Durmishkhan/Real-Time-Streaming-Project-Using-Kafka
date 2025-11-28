import os
import boto3
import time
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

redshift_data = boto3.client('redshift-data', region_name='us-east-1')

WORKGROUP = os.environ['REDSHIFT_WORKGROUP']
DATABASE  = os.environ['REDSHIFT_DATABASE']
BUCKET    = os.environ['S3_BUCKET']
ROLE_ARN  = os.environ['REDSHIFT_ROLE_ARN']

def execute_and_wait(sql, description):
    """Execute SQL and wait for completion"""
    print(f"Starting: {description}")
    
    response = redshift_data.execute_statement(
        WorkgroupName=WORKGROUP,
        Database=DATABASE,
        Sql=sql
    )
    query_id = response['Id']
    print(f"Query ID: {query_id}")
    
    # Wait for completion
    while True:
        status_response = redshift_data.describe_statement(Id=query_id)
        status = status_response['Status']
        
        if status == 'FINISHED':
            print(f"Success: {description}")
            return query_id
        elif status == 'FAILED':
            error = status_response.get('Error', 'Unknown error')
            print(f"Failed: {description} - {error}")
            raise Exception(f"{description} failed: {error}")
        elif status == 'ABORTED':
            print(f"Aborted: {description}")
            raise Exception(f"{description} was aborted")
        
        time.sleep(2)

def lambda_handler(event, context):
    # Load previous hour's data
    prev_hour = datetime.utcnow() - timedelta(hours=1)
    prefix = f"medical-vitals/year={prev_hour.year}/month={prev_hour:%m}/day={prev_hour:%d}/hour={prev_hour:%H}/"
    s3_path = f"s3://{BUCKET}/{prefix}"
    
    print(f"Loading data from: {s3_path}")
    print(f"Date: {prev_hour.strftime('%Y-%m-%d %H:00')}")
    
    try:
        # Staging table matches Parquet schema exactly
        combined_sql = f"""
        -- Step 1: Create staging table matching Parquet/Producer schema
        DROP TABLE IF EXISTS staging_vitals;
        
        CREATE TEMP TABLE staging_vitals (
            patient_id VARCHAR(50),
            patient_name VARCHAR(255),
            age INTEGER,
            gender VARCHAR(50),
            hospital_id VARCHAR(50),
            hospital_name VARCHAR(255),
            room_number INTEGER,
            device_id VARCHAR(50),
            device_type VARCHAR(100),
            department VARCHAR(100),
            heart_rate INTEGER,
            spo2 INTEGER,
            bp_sys INTEGER,
            bp_dia INTEGER,
            temp DOUBLE PRECISION,
            resp_rate INTEGER,
            blood_sugar DOUBLE PRECISION,
            oxygen_flow_rate DOUBLE PRECISION,
            ecg_lead_ii DOUBLE PRECISION,
            timestamp VARCHAR(50),
            event_type VARCHAR(50),
            alert_flag INTEGER,
            ingestion_time VARCHAR(50)
        );
        
        COPY staging_vitals FROM '{s3_path}'
        IAM_ROLE '{ROLE_ARN}'
        FORMAT AS PARQUET;
        
        -- Step 2: Update patient dimension
        INSERT INTO patient_dimension (patient_id, patient_name, age, gender)
        SELECT DISTINCT 
            CAST(REPLACE(patient_id, 'P', '') AS INTEGER), 
            patient_name, 
            age, 
            gender
        FROM staging_vitals
        WHERE CAST(REPLACE(patient_id, 'P', '') AS INTEGER) NOT IN (SELECT patient_id FROM patient_dimension);
        
        -- Step 3: Update hospital dimension
        INSERT INTO hospital_dimension (hospital_id, hospital_name, room_number, department)
        SELECT DISTINCT 
            CAST(REPLACE(hospital_id, 'H', '') AS INTEGER), 
            hospital_name, 
            CAST(room_number AS VARCHAR(50)),
            department
        FROM staging_vitals
        WHERE CAST(REPLACE(hospital_id, 'H', '') AS INTEGER) NOT IN (SELECT hospital_id FROM hospital_dimension);
        
        -- Step 4: Update device dimension
        INSERT INTO device_dimension (device_id, device_type)
        SELECT DISTINCT 
            CAST(REPLACE(device_id, 'D', '') AS INTEGER), 
            device_type
        FROM staging_vitals
        WHERE CAST(REPLACE(device_id, 'D', '') AS INTEGER) NOT IN (SELECT device_id FROM device_dimension);
        
        -- Step 5: Load vitals fact
        INSERT INTO vitals_fact (
            patient_id, hospital_id, device_id,
            timestamp, heart_rate, resp_rate, spo2,
            bp_sys, bp_dia, blood_sugar, temp,
            oxygen_flow_rate, ecg_lead_ii, ingestion_time,
            event_type, alert_flag
        )
        SELECT 
            CAST(REPLACE(s.patient_id, 'P', '') AS INTEGER),
            CAST(REPLACE(s.hospital_id, 'H', '') AS INTEGER),
            CAST(REPLACE(s.device_id, 'D', '') AS INTEGER),
            CAST(EXTRACT(EPOCH FROM CAST(s.timestamp AS TIMESTAMP)) * 1000 AS BIGINT),
            s.heart_rate,
            s.resp_rate,
            s.spo2,
            s.bp_sys,
            s.bp_dia,
            CAST(s.blood_sugar AS INTEGER),
            CAST(s.temp AS NUMERIC(4,1)),
            CAST(s.oxygen_flow_rate AS NUMERIC(4,1)),
            CAST(s.ecg_lead_ii AS NUMERIC(4,2)),
            CAST(EXTRACT(EPOCH FROM CAST(s.ingestion_time AS TIMESTAMP)) * 1000 AS BIGINT),
            s.event_type,
            CASE WHEN s.alert_flag = 1 THEN 'Yes' ELSE 'No' END
        FROM staging_vitals s
        LEFT JOIN vitals_fact vf 
            ON vf.patient_id = CAST(REPLACE(s.patient_id, 'P', '') AS INTEGER)
            AND vf.timestamp = CAST(EXTRACT(EPOCH FROM CAST(s.timestamp AS TIMESTAMP)) * 1000 AS BIGINT)
        WHERE vf.patient_id IS NULL;
        """
        
        execute_and_wait(combined_sql, "Complete ETL process")
        
        print(f"All data loaded successfully!")
        return {"status": "SUCCESS", "prefix": prefix}
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise e