# ============================================================
# Airflow DAG — Automates Railway Pipeline
# Team 11 | Real-Time Railway Pipeline
# ============================================================

from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'team11',
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'railway_pipeline',
    default_args=default_args,
    description='Real-Time Indian Railway ETL Pipeline',
    schedule=None,  # Manual trigger
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=['railway', 'etl', 'kafka', 'pyspark']
) as dag:

    # Task 1 — Start Zookeeper and Kafka
    start_kafka = BashOperator(
        task_id='start_zookeeper_kafka',
        bash_command='''
        $KAFKA_HOME/bin/zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties &
        sleep 10
        $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties &
        sleep 10
        echo "Kafka started!"
        ''',
    )

    # Task 2 — Run Producer
    run_producer = BashOperator(
        task_id='run_producer',
        bash_command='''
        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
        export AWS_DEFAULT_REGION=us-east-1
        python3 /home/ubuntu/producer/producer.py
        ''',
    )

    # Task 3 — Run Consumer + PySpark
    run_consumer = BashOperator(
        task_id='run_consumer_pyspark',
        bash_command='''
        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
        export AWS_DEFAULT_REGION=us-east-1
        python3 /home/ubuntu/consumer/consumer.py
        ''',
    )

    # Pipeline order: Kafka → Producer → Consumer
    start_kafka >> run_producer >> run_consumer
