"""
Lambda Function: S3 → Redshift Incremental COPY
Trigger: EventBridge (Hourly)
"""

import json
import boto3
import os
from datetime import datetime, timedelta

# Environment Variables
REDSHIFT_WORKGROUP = os.environ['REDSHIFT_WORKGROUP']
REDSHIFT_DATABASE = os.environ['REDSHIFT_DATABASE']
S3_BUCKET = os.environ['S3_BUCKET']
IAM_ROLE_ARN = os.environ['IAM_ROLE_ARN']

redshift_data = boto3.client('redshift-data')

def lambda_handler(event, context):
    """
    Main handler - copies last hour's data from S3 to Redshift
    """
    
    # Calculate previous hour path
    now = datetime.utcnow()
    prev_hour = now - timedelta(hours=1)
    
    s3_prefix = f"medical-vitals/year={prev_hour.year}/month={prev_hour.month:02d}/day={prev_hour.day:02d}/hour={prev_hour.hour:02d}/"
    
    print(f"Processing S3 path: s3://{S3_BUCKET}/{s3_prefix}")
    
    # COPY SQL Command
    copy_sql = f"""
    COPY fact_vitals (
        patient_id, patient_name, age, gender,
        hospital_id, hospital_name, room_number,
        device_id, device_type, department,
        heart_rate, spo2, bp_sys, bp_dia, temp,
        resp_rate, blood_sugar, oxygen_flow_rate, ecg_lead_ii,
        timestamp, event_type, alert_flag, ingestion_time
    )
    FROM 's3://{S3_BUCKET}/{s3_prefix}'
    IAM_ROLE '{IAM_ROLE_ARN}'
    FORMAT AS PARQUET;
    """
    
    try:
        # Execute Redshift query
        response = redshift_data.execute_statement(
            WorkgroupName=REDSHIFT_WORKGROUP,
            Database=REDSHIFT_DATABASE,
            Sql=copy_sql
        )
        
        query_id = response['Id']
        print(f"Query submitted: {query_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'COPY command submitted',
                'query_id': query_id,
                's3_path': s3_prefix
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }