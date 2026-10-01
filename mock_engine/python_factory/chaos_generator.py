import random
import uuid
from faker import Faker
from datetime import datetime, timezone

fake = Faker()

# ==========================================
# MASTER DATA: 100 Toko (Simulasi Multi-Tenant)
# ==========================================
STORE_IDS = [str(uuid.uuid4()) for _ in range(100)]
SULTAN_STORE = STORE_IDS[0] # Toko Sultan (Target 80% Traffic Flash Sale)
PRODUCT_IDS = {store: [str(uuid.uuid4()) for _ in range(50)] for store in STORE_IDS}
CUSTOMER_IDS = [str(uuid.uuid4()) for _ in range(1000)] # 1000 Pembeli Loyal

def generate_chaotic_order():
    """
    Menghasilkan anomali Multi-Tenant Skew:
    80% transaksi masuk ke Toko Sultan (Flash Sale Bot).
    20% transaksi masuk ke 99 Toko lainnya secara acak.
    """
    # 1. Tentukan Toko (Skew 80/20)
    store_id = SULTAN_STORE if random.random() < 0.8 else random.choice(STORE_IDS[1:])
    
    order_id = str(uuid.uuid4())
    customer_id = random.choice(CUSTOMER_IDS)
    status = random.choices(["PAID", "PENDING", "FAILED_STOCK_OUT"], weights=[0.85, 0.1, 0.05])[0]
    
    # 2. Write Amplification: 1 Order beli 3-5 jenis barang (Order Lines)
    num_items = random.randint(3, 5)
    order_lines = []
    total_amount = 0
    
    for _ in range(num_items):
        line_id = str(uuid.uuid4())
        product_id = random.choice(PRODUCT_IDS[store_id])
        qty = random.randint(1, 10)
        unit_price = random.randint(15000, 250000)
        subtotal = qty * unit_price
        total_amount += subtotal
        
        order_lines.append({
            "line_id": line_id,
            "order_id": order_id,
            "store_id": store_id,
            "product_id": product_id,
            "quantity": qty,
            "unit_price": unit_price,
            "subtotal": subtotal
        })

    order = {
        "order_id": order_id,
        "store_id": store_id,
        "customer_id": customer_id,
        "status": status,
        "total_amount": total_amount,
        "payment_method": random.choice(["E-WALLET", "VIRTUAL_ACCOUNT", "CREDIT_CARD"])
    }
    
    return order, order_lines