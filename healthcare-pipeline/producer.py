from kafka import KafkaProducer
import json, random, time
import datetime

# ====================================================================
# Kafka Producer Configuration
# ====================================================================.
producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda x: json.dumps(x).encode('utf-8')
)

# ====================================================================
# Data Generation Function
# ====================================================================
def generate_data():
    """ Generates random medical vital signs data for simulation. """
    return {
        # ----------------- Dimension Fields -----------------
        "patient_id": f"P{random.randint(1000,2000)}",      
        "patient_name": f"Patient_{random.randint(1,1000)}",
        "age": random.randint(1, 90),
        "gender": random.choice(["Male", "Female", "Other"]),
        "hospital_id": f"H{random.randint(1,50)}",           
        "hospital_name": f"Hospital_{random.randint(1,50)}",
        "room_number": random.randint(100, 500),
        "device_id": f"D{random.randint(1000,2000)}",        
        "device_type": random.choice(["ECG", "PulseOx", "BPMonitor"]),
        "department": random.choice(["ICU", "ER", "Ward", "General"]),

        # ----------------- Fact Fields (Metrics) -----------------
        "heart_rate": random.randint(60, 160),             
        "spo2": random.randint(85, 100),                     
        "bp_sys": random.randint(100, 160),                 
        "bp_dia": random.randint(60, 100),                 
        "temp": round(random.uniform(97.0, 102.5), 1),      
        "resp_rate": random.randint(12, 30),                
        "blood_sugar": round(random.uniform(70, 180), 1),
        "oxygen_flow_rate": round(random.uniform(0, 10), 1),
        "ecg_lead_ii": round(random.uniform(-1.0, 1.0), 3),

        # ----------------- Timestamp / Metadata -----------------
        "timestamp": datetime.datetime.now(datetime.UTC).isoformat(),
        "event_type": "vital_signs_reading",
        "alert_flag": random.choice([0, 1]),                # 0 = normal, 1 = critical
        "ingestion_time": datetime.datetime.now(datetime.UTC).isoformat()
    }

# ====================================================================
# Continuous Data Sending Loop
# ====================================================================
print("Starting Kafka Producer...")
print("The script runs indefinitely. Press Ctrl+C to stop the process.")

try:
    # The while True loop simulates a continuous stream of data,
    # typical of real-time monitoring devices.
    while True:
        data = generate_data()
        
        # Send data to the "medical_vitals" topic
        producer.send("medical_vitals", value=data)
        
        print(f"Sent: {data['patient_id']} - HR: {data['heart_rate']} - SpO2: {data['spo2']}")
        
        time.sleep(1) 

except KeyboardInterrupt:
    # Handles user interruption (Ctrl+C)
    print("\nProducer stopped by user.")
    producer.close()
except Exception as e:
    # Handles general exceptions and ensures the producer connection is closed
    print(f"\nAn error occurred: {e}")
    producer.close()