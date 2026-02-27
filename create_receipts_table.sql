-- Create receipts table for storing receipt data
CREATE TABLE IF NOT EXISTS public.receipts ( 
   id SERIAL NOT NULL, 
   category TEXT NOT NULL, 
   nature_of_collection TEXT NOT NULL, 
   price NUMERIC(10, 2) NOT NULL, 
   created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT NOW(), 
   marine_flow TEXT NULL, 
   collection_price NUMERIC(10, 2) NULL, 
   saved_at TIMESTAMP WITH TIME ZONE NOT NULL, 
   file_name TEXT NOT NULL, 
   html_content TEXT NULL, 
   collection_items JSONB NULL, 
   CONSTRAINT receipts_pkey PRIMARY KEY (id) 
) TABLESPACE pg_default; 

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_receipts_category ON public.receipts USING BTREE (category) TABLESPACE pg_default; 

CREATE INDEX IF NOT EXISTS idx_receipts_marine_flow ON public.receipts USING BTREE (marine_flow) TABLESPACE pg_default; 

CREATE INDEX IF NOT EXISTS idx_receipts_saved_at ON public.receipts USING BTREE (saved_at DESC) TABLESPACE pg_default;

-- Add some sample data for testing
INSERT INTO public.receipts (category, nature_of_collection, price, marine_flow, collection_price, saved_at, file_name, collection_items) VALUES 
('Marine', 'Dock Fee', 50.00, 'Incoming', 50.00, NOW(), 'receipt_001.pdf', '[{"item": "Dock usage", "quantity": 1, "rate": 50.00}]'),
('Marine', 'Storage Fee', 25.00, 'Incoming', 25.00, NOW(), 'receipt_002.pdf', '[{"item": "Storage service", "quantity": 1, "rate": 25.00}]'),
('Slaughter', 'Processing Fee', 45.00, NULL, 45.00, NOW(), 'receipt_003.pdf', '[{"item": "Animal processing", "quantity": 1, "rate": 45.00}]'),
('Rent', 'Monthly Rent', 500.00, NULL, 500.00, NOW(), 'receipt_004.pdf', '[{"item": "Monthly rental", "quantity": 1, "rate": 500.00}]'),
('Marine', 'Service Fee', 85.00, 'Outgoing', 85.00, NOW(), 'receipt_005.pdf', '[{"item": "Marine service", "quantity": 1, "rate": 85.00}]');
