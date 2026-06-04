# ============================================================
# Producer — Reads 3 JSON files from S3, sends to Kafka topics
# Team 11 | Real-Time Railway Pipeline
# ============================================================

import json
import boto3
from kafka import KafkaProducer

# Configuration
BOOTSTRAP_SERVERS = ['localhost:XXXX']
BUCKET = 'MAYUR S3'
REGION = 'REGION'
BATCH_SIZE = 100

# Connect to S3
s3 = boto3.client('s3', region_name=REGION)

def json_serializer(data):
    """Convert data to bytes for Kafka"""
    return json.dumps(data).encode('utf-8')

# Create Kafka Producer
producer = KafkaProducer(
    bootstrap_servers=BOOTSTRAP_SERVERS,
    value_serializer=json_serializer,
    max_request_size=10485760  # 10MB max message size
)

def send_file(file_key, topic):
    """
    Read JSON file from S3 and send to Kafka topic in batches
    Handles both GeoJSON format (trains, stations) and flat JSON (schedules)
    """
    print(f"\nReading {file_key} from S3...")
    obj = s3.get_object(Bucket=BUCKET, Key=f"raw-data/{file_key}")
    data = json.loads(obj['Body'].read().decode('utf-8'))

    # Handle GeoJSON format (trains.json and stations.json)
    if isinstance(data, dict) and 'features' in data:
        records = []
        for feature in data['features']:
            record = feature.get('properties', {})
            # Extract GPS coordinates from geometry
            if feature.get('geometry') and feature['geometry'].get('coordinates'):
                coords = feature['geometry']['coordinates']
                if feature['geometry']['type'] == 'Point':
                    record['longitude'] = coords[0]
                    record['latitude'] = coords[1]
            records.append(record)
    else:
        # Flat JSON format (schedules.json)
        records = data

    print(f"Total records: {len(records)}")

    # Send in batches of 100
    for i in range(0, len(records), BATCH_SIZE):
        batch = records[i:i+BATCH_SIZE]
        producer.send(topic, value=batch)
        print(f"Sent batch {i//BATCH_SIZE + 1} to {topic}", end='\r')

    producer.flush()
    print(f"\nDone sending {file_key} to {topic} ✓")

# Send all 3 files to their Kafka topics
send_file('trains.json', 'trains_topic')
send_file('stations.json', 'stations_topic')
send_file('schedules.json', 'schedules_topic')

producer.close()
print("\nAll producers done! ✅")
