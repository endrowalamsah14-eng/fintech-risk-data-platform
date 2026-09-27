import random
import uuid
from faker import Faker
from datetime import datetime, timezone

fake = Faker()

def generate_customer():
    return {
        "id": f"cus_{uuid.uuid4().hex[:16]}",
        "acct_id": "acct_epocket_main",
        "email": fake.email(),
        "created_at": datetime.now(timezone.utc).isoformat()
    }

def generate_chaotic_transaction(customer_id):
    """
    Menghasilkan 3 jenis anomali untuk menonjolkan fitur ML Risk Engine:
    1. Normal: Transaksi wajar.
    2. Card Testing: Nominal super kecil berulang kali (Micro-fraud).
    3. Account Takeover: Nominal masif tak wajar.
    """
    scenario = random.choices(["normal", "card_testing", "takeover"], weights=[0.8, 0.15, 0.05])[0]
    
    if scenario == "card_testing":
        amount = random.randint(100, 5000) # Rp 100 - Rp 5.000
        status = "failed_cvv"
        risk_score = random.randint(85, 100)
        risk_level = "critical"
    elif scenario == "takeover":
        amount = random.randint(50000000, 250000000) # Rp 50 Juta - Rp 250 Juta
        status = "requires_review"
        risk_score = random.randint(75, 95)
        risk_level = "high"
    else:
        amount = random.randint(15000, 1500000) # Rp 15 Ribu - Rp 1.5 Juta
        status = "succeeded"
        risk_score = random.randint(0, 20)
        risk_level = "low"

    payment_intent_id = f"pi_{uuid.uuid4().hex[:16]}"
    
    return {
        "pi_id": payment_intent_id,
        "customer_id": customer_id,
        "amount": amount,
        "status": status,
        "risk_score": risk_score,
        "risk_level": risk_level,
        "created_at": datetime.now(timezone.utc).isoformat()
    }