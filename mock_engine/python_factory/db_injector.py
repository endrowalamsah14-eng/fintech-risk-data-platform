import time
import psycopg2
from psycopg2.extras import execute_values
from chaos_generator import generate_chaotic_order, STORE_IDS

# ==========================================
# 1. KONEKSI KE YUGABYTEDB DENGAN RETRY
# ==========================================
def get_db_connection():
    while True:
        try:
            # Gunakan nama service master dari docker-compose
            conn = psycopg2.connect(
                dbname="yugabyte",
                user="yugabyte",
                host="yugabyte-master", 
                port="5433"
            )
            return conn
        except Exception as e:
            print("⏳ Menunggu YugabyteDB dan Schema siap... (Retry dalam 10 detik)")
            time.sleep(10)

pg_conn = get_db_connection()
pg_cursor = pg_conn.cursor()

def inject_doomsday_data(total_orders=5000000, batch_size=5000):
    print(f"🚀 MEMULAI KIAMAT {total_orders:,} TRANSAKSI KE YUGABYTEDB...")
    start_time = time.time()
    
    orders_inserted = 0
    
    while orders_inserted < total_orders:
        orders_batch = []
        lines_batch = []
        
        for _ in range(batch_size):
            order, lines = generate_chaotic_order()
            orders_batch.append((order['store_id'], order['order_id'], order['customer_id'], order['status'], order['total_amount'], order['payment_method']))
            for line in lines:
                lines_batch.append((line['store_id'], line['order_id'], line['line_id'], line['product_id'], line['quantity'], line['unit_price'], line['subtotal']))
            
            orders_inserted += 1
            if orders_inserted >= total_orders:
                break
        
        execute_values(
            pg_cursor,
            "INSERT INTO orders (store_id, order_id, customer_id, status, total_amount, payment_method) VALUES %s ON CONFLICT DO NOTHING",
            orders_batch
        )
        execute_values(
            pg_cursor,
            "INSERT INTO order_lines (store_id, order_id, line_id, product_id, quantity, unit_price, subtotal) VALUES %s ON CONFLICT DO NOTHING",
            lines_batch
        )
        pg_conn.commit()
        
        elapsed = time.time() - start_time
        tps = int(orders_inserted / elapsed)
        print(f"✅ {orders_inserted:,} / {total_orders:,} Orders terkirim. Kecepatan: {tps:,} TPS.")

if __name__ == "__main__":
    try:
        inject_doomsday_data(total_orders=5000000, batch_size=5000)
        print("🎉 KIAMAT SELESAI, INFRASTRUKTUR SELAMAT!")
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        pg_cursor.close()
        pg_conn.close()