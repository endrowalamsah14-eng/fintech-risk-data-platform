-- =======================================================================
-- 1. CORE CUSTOMERS (Static Entities & Identities)
-- =======================================================================
CREATE TABLE customers (
    id VARCHAR(50) PRIMARY KEY,
    acct_id VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payment_methods (
    id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES customers(id),
    type VARCHAR(50) NOT NULL,
    last4 VARCHAR(4) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bank_accounts (
    id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES customers(id),
    bank_name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE identities (
    id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES customers(id),
    document_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE customer_balances (
    id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES customers(id) UNIQUE,
    available_balance BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =======================================================================
-- 2. CORE PAYMENTS (The Heart of Financial Operations)
-- =======================================================================
CREATE TABLE payment_intents (
    id VARCHAR(50) PRIMARY KEY,
    acct_id VARCHAR(50) NOT NULL,
    amount BIGINT NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE setup_intents (
    id VARCHAR(50) PRIMARY KEY,
    acct_id VARCHAR(50) NOT NULL,
    customer_id VARCHAR(50) REFERENCES customers(id),
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE charges (
    id VARCHAR(50) PRIMARY KEY,
    pi_id VARCHAR(50) REFERENCES payment_intents(id),
    acct_id VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- NORMALIZED: Refunds separated into its own table
CREATE TABLE refunds (
    id VARCHAR(50) PRIMARY KEY,
    charge_id VARCHAR(50) REFERENCES charges(id),
    amount BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE balance_transactions (
    id VARCHAR(50) PRIMARY KEY,
    acct_id VARCHAR(50) NOT NULL,
    source VARCHAR(50) REFERENCES charges(id), 
    fee BIGINT NOT NULL,
    net BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payouts (
    id VARCHAR(50) PRIMARY KEY,
    acct_id VARCHAR(50) NOT NULL,
    amount BIGINT NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =======================================================================
-- 3. BILLING INFRASTRUCTURE (SaaS Subscription System)
-- =======================================================================
CREATE TABLE products (
    id VARCHAR(50) PRIMARY KEY,
    acct_id VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE prices (
    id VARCHAR(50) PRIMARY KEY,
    product_id VARCHAR(50) REFERENCES products(id),
    unit_amount BIGINT NOT NULL,
    recurring VARCHAR(50) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subscriptions (
    id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES customers(id),
    price_id VARCHAR(50) REFERENCES prices(id),
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE invoices (
    id VARCHAR(50) PRIMARY KEY,
    sub_id VARCHAR(50) REFERENCES subscriptions(id),
    acct_id VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE credit_notes (
    id VARCHAR(50) PRIMARY KEY,
    invoice_id VARCHAR(50) REFERENCES invoices(id),
    amount BIGINT NOT NULL, 
    reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =======================================================================
-- 4. RADAR FRAUD (ML/AI Fraud Prevention System)
-- =======================================================================
CREATE TABLE disputes (
    id VARCHAR(50) PRIMARY KEY,
    charge_id VARCHAR(50) REFERENCES charges(id),
    acct_id VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE early_fraud_warnings (
    id VARCHAR(50) PRIMARY KEY,
    charge_id VARCHAR(50) REFERENCES charges(id),
    fraud_type VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE reviews (
    id VARCHAR(50) PRIMARY KEY,
    pi_id VARCHAR(50) REFERENCES payment_intents(id),
    reason VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE radar_scores (
    id VARCHAR(50) PRIMARY KEY,
    pi_id VARCHAR(50) REFERENCES payment_intents(id),
    risk_score INT NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_level VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE block_rules (
    id VARCHAR(50) PRIMARY KEY,
    pi_id VARCHAR(50) REFERENCES payment_intents(id),
    rule_triggered VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);