-- Create receipt_natures table for storing available nature of collection options
CREATE TABLE IF NOT EXISTS public.receipt_natures ( 
   id SERIAL NOT NULL, 
   category TEXT NOT NULL, 
   nature_of_collection TEXT NOT NULL, 
   amount NUMERIC(10, 2) NOT NULL, 
   marine_flow TEXT NULL, 
   created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT NOW(), 
   CONSTRAINT receipt_natures_pkey PRIMARY KEY (id) 
) TABLESPACE pg_default; 

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_receipt_natures_category ON public.receipt_natures USING BTREE (category) TABLESPACE pg_default; 

CREATE INDEX IF NOT EXISTS idx_receipt_natures_marine_flow ON public.receipt_natures USING BTREE (marine_flow) TABLESPACE pg_default;

-- Add some sample data for testing
INSERT INTO public.receipt_natures (category, nature_of_collection, amount, marine_flow) VALUES 
('Marine', 'Dock Fee', 50.00, 'Incoming'),
('Marine', 'Storage Fee', 25.00, 'Incoming'),
('Marine', 'Service Fee', 75.00, 'Incoming'),
('Marine', 'Dock Fee', 60.00, 'Outgoing'),
('Marine', 'Storage Fee', 30.00, 'Outgoing'),
('Marine', 'Service Fee', 85.00, 'Outgoing'),
('Slaughter', 'Processing Fee', 45.00, NULL),
('Slaughter', 'Inspection Fee', 35.00, NULL),
('Slaughter', 'Handling Fee', 20.00, NULL),
('Rent', 'Monthly Rent', 500.00, NULL),
('Rent', 'Equipment Rental', 150.00, NULL),
('Rent', 'Space Rental', 200.00, NULL);
