import time
import psycopg2
from psycopg2.extras import execute_values
from pymongo import MongoClient
from chaos_generator import generate_customer, generate_chaotic_transaction

# ==========================================
# 1. KONFIGURASI KONEKSI
# ==========================================
pg_conn = psycopg2.connect(
    dbname="epocket_ledger",
    user="epocket_admin",
    password="epocket_password",
    host="localhost",
    port="5431"
)
pg_cursor = pg_conn.cursor()

mongo_client = MongoClient("mongodb://localhost:27017/?directConnection=true")
mongo_db = mongo_client["epocket_state"]
payment_intents_collection = mongo_db["payment_intents"]

# ==========================================
# 2. MESIN BULK INSERT (JUTAAN BARIS)
# ==========================================
def inject_massive_data(total_transactions=3000000, batch_size=10000):
    print(f"🚀 MEMULAI INJEKSI {total_transactions:,} TRANSAKSI KE ZONA 1...")
    start_time = time.time()
    
    transactions_inserted = 0
    
    while transactions_inserted < total_transactions:
        pg_customers_batch = []
        pg_intents_batch = []
        mongo_intents_batch = []
        
        # Bikin data per batch (misal 10.000 baris)
        for _ in range(batch_size):
            cust = generate_customer()
            trx = generate_chaotic_transaction(cust['id'])
            
            # Siapkan Tuple untuk Postgres (Format data relasional)
            pg_customers_batch.append((cust['id'], cust['acct_id'], cust['email'], cust['created_at']))
            pg_intents_batch.append((trx['pi_id'], cust['acct_id'], trx['amount'], trx['status'], trx['created_at']))
            
            # Siapkan Dictionary untuk MongoDB (Format NoSQL)
            mongo_intents_batch.append(trx)
            
            transactions_inserted += 1
            if transactions_inserted >= total_transactions:
                break
        
        # ---------------------------------------------------------
        # EKSEKUSI TEMBAKAN (BULK INSERT)
        # ---------------------------------------------------------
        # Tembak ke Postgres (Ledger) pakai execute_values
        execute_values(
            pg_cursor,
            "INSERT INTO customers (id, acct_id, email, created_at) VALUES %s ON CONFLICT DO NOTHING",
            pg_customers_batch
        )
        execute_values(
            pg_cursor,
            "INSERT INTO payment_intents (id, acct_id, amount, status, created_at) VALUES %s ON CONFLICT DO NOTHING",
            pg_intents_batch
        )
        pg_conn.commit()
        
        # Tembak ke MongoDB (NoSQL State) pakai insert_many
        payment_intents_collection.insert_many(mongo_intents_batch)
        
        # Kalkulasi ETA dan Kecepatan
        elapsed = time.time() - start_time
        tps = int(transactions_inserted / elapsed)
        print(f"✅ {transactions_inserted:,} / {total_transactions:,} baris terkirim. Kecepatan: {tps:,} TPS.")

if __name__ == "__main__":
    try:
        # 🔥 LU BISA ATUR VOLUMENYA DI SINI (Sekarang diset 3 juta)
        inject_massive_data(total_transactions=3000000, batch_size=10000)
        print("🎉 INJEKSI CHAOS SELESAI!")
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        pg_cursor.close()
        pg_conn.close()
        mongo_client.close()