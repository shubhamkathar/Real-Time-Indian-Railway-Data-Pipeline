
# Consumer — Reads from Kafka, joins 3 datasets, cleans with PySpark


import json
import pandas as pd
from kafka import KafkaConsumer
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when

# Configuration
BOOTSTRAP_SERVERS = ['localhost:XXXX']
BUCKET = 'MAYUR S3'
REGION = 'REGION'

def consume_topic(topic, timeout=30000):
    """
    Read all messages from a Kafka topic
    Returns list of records
    """
    consumer = KafkaConsumer(
        topic,
        bootstrap_servers=BOOTSTRAP_SERVERS,
        value_deserializer=lambda x: json.loads(x.decode('utf-8')),
        auto_offset_reset='earliest',
        enable_auto_commit=True,
        consumer_timeout_ms=timeout
    )
    records = []
    for message in consumer:
        records.extend(message.value)
        print(f"{topic}: {len(records)} records", end='\r')
    consumer.close()
    print(f"\n{topic} done: {len(records)} records ✓")
    return records

def transform_and_save():
    # Step 1 — Read all 3 Kafka topics
    print("Reading trains topic...")
    trains = consume_topic('trains_topic')

    print("Reading stations topic...")
    stations = consume_topic('stations_topic')

    print("Reading schedules topic...")
    schedules = consume_topic('schedules_topic', timeout=60000)

    # Step 2 — Convert to Pandas DataFrames
    trains_df = pd.DataFrame(trains)
    stations_df = pd.DataFrame(stations)
    schedules_df = pd.DataFrame(schedules)

    print(f"\nTrains: {len(trains_df)} rows")
    print(f"Stations: {len(stations_df)} rows")
    print(f"Schedules: {len(schedules_df)} rows")

    # Step 3 — Fix data issues in Pandas
    # Rename trains number column for join
    trains_df.rename(columns={'number': 'train_number'}, inplace=True)

    # Fix None strings to real NULL in arrival/departure
    schedules_df['arrival'] = schedules_df['arrival'].replace('None', None)
    schedules_df['departure'] = schedules_df['departure'].replace('None', None)

    # Fill missing day with 1 (first day of journey)
    schedules_df['day'] = schedules_df['day'].fillna(1)

    # Remove dummy stations (XX, YY prefix = placeholder stations)
    stations_df = stations_df[stations_df['state'].notna()]
    stations_df = stations_df[~stations_df['code'].str.startswith('XX')]
    stations_df = stations_df[~stations_df['code'].str.startswith('YY')]

    # Step 4 — JOIN 1: schedules + trains on train_number (LEFT JOIN)
    print("\nJoining schedules + trains...")
    merged = schedules_df.merge(
        trains_df[['train_number', 'type', 'zone', 'distance',
                   'duration_h', 'from_station_code', 'to_station_code',
                   'first_ac', 'second_ac', 'third_ac', 'sleeper', 'chair_car']],
        on='train_number', how='left'
    )

    # Step 5 — JOIN 2: merged + stations on station_code (LEFT JOIN)
    print("Joining with stations...")
    merged = merged.merge(
        stations_df[['code', 'state', 'zone', 'latitude', 'longitude']]
        .rename(columns={'code': 'station_code', 'zone': 'station_zone'}),
        on='station_code', how='left'
    )

    print(f"After join: {len(merged)} rows, {len(merged.columns)} columns")

    # Step 6 — Save merged data for PySpark
    merged.to_csv('/tmp/railway_merged.csv', index=False)

    # Step 7 — PySpark transformations
    spark = SparkSession.builder \
        .appName("RailwayNewETL") \
        .master("local[*]") \
        .config("spark.driver.memory", "4g") \
        .config("spark.python.worker.reuse", "false") \
        .getOrCreate()
    spark.sparkContext.setLogLevel("ERROR")

    # Read merged CSV into PySpark DataFrame
    sdf = spark.read.csv('/tmp/railway_merged.csv', header=True, inferSchema=False)

    # Remove rows where train_name is null
    sdf = sdf.filter(col("train_name").isNotNull())
    sdf = sdf.filter(col("train_name") != "None")

    # Fill null train type with UNKNOWN
    sdf = sdf.withColumn("type",
        when(col("type").isNull(), "UNKNOWN")
        .otherwise(col("type")))

    # Remove duplicate stops (same train at same station on same day)
    sdf = sdf.dropDuplicates(["train_number", "station_code", "day"])

    print(f"Final clean records: {sdf.count()}")

    # Step 8 — Save to Mayur's S3 as Parquet
    s3_path = f"s3a://{BUCKET}/clean-data/railway_final"
    sdf.write.mode("overwrite").parquet(s3_path)
    print("Saved to S3 clean-data ✓")

    spark.stop()

if __name__ == "__main__":
    transform_and_save()
    print("\nPipeline complete! ✅")
