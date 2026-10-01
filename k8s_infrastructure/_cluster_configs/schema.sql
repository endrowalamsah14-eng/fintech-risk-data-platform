-- =============================================================================
-- YUGABYTEDB SCHEMA: E-MARKET BIG DATA (MULTI-TENANT & CDC OPTIMIZED)
-- =============================================================================

CREATE TABLE stores (
    store_id UUID,
    store_name VARCHAR,
    tier VARCHAR,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- HASH membagi data toko secara merata ke seluruh cluster
    PRIMARY KEY (store_id HASH) 
);

CREATE TABLE products (
    store_id UUID,
    product_id UUID,
    sku VARCHAR,
    title VARCHAR,
    price DECIMAL(10,2),
    is_flash_sale BOOLEAN,
    -- ASC mengurutkan product berdasarkan toko yang sama dalam satu tablet
    PRIMARY KEY (store_id HASH, product_id ASC) 
);

CREATE TABLE inventory (
    store_id UUID,
    inventory_id UUID,
    product_id UUID,
    available_qty INT,
    reserved_qty INT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (store_id HASH, inventory_id ASC)
);

CREATE TABLE customers (
    store_id UUID,
    customer_id UUID,
    email VARCHAR,
    segment VARCHAR,
    PRIMARY KEY (store_id HASH, customer_id ASC)
);

CREATE TABLE orders (
    store_id UUID,
    order_id UUID,
    customer_id UUID,
    status VARCHAR,
    total_amount DECIMAL(10,2),
    payment_method VARCHAR,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (store_id HASH, order_id ASC)
);

-- Write Amplification Core
CREATE TABLE order_lines (
    store_id UUID,
    order_id UUID,
    line_id UUID,
    product_id UUID,
    quantity INT,
    unit_price DECIMAL(10,2),
    subtotal DECIMAL(10,2),
    PRIMARY KEY (store_id HASH, order_id ASC, line_id ASC)
);