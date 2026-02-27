-- Create table for nature/amount mapping by category
CREATE TABLE IF NOT EXISTS receipt_natures (
  id SERIAL PRIMARY KEY,
  category TEXT NOT NULL,
  nature_of_collection TEXT NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  marine_flow TEXT DEFAULT NULL, -- Only for Marine category (Incoming/Outgoing)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_receipt_natures_category ON receipt_natures(category);
CREATE INDEX IF NOT EXISTS idx_receipt_natures_marine_flow ON receipt_natures(marine_flow);
CREATE INDEX IF NOT EXISTS idx_receipt_natures_nature ON receipt_natures(nature_of_collection);

-- Insert sample data for each category
-- Marine category entries
INSERT INTO receipt_natures (category, nature_of_collection, amount, marine_flow) VALUES
('Marine', 'Permit Fee - Fishing Vessel', 500.00, 'Incoming'),
('Marine', 'Permit Fee - Commercial Boat', 750.00, 'Incoming'),
('Marine', 'Service Fee - Inspection', 200.00, 'Incoming'),
('Marine', 'Rental Fee - Dock Space', 100.00, 'Incoming'),
('Marine', 'Permit Fee - Export Clearance', 300.00, 'Outgoing'),
('Marine', 'Service Fee - Documentation', 150.00, 'Outgoing'),
('Marine', 'Rental Fee - Storage', 80.00, 'Outgoing');

-- Slaughter category entries
INSERT INTO receipt_natures (category, nature_of_collection, amount) VALUES
('Slaughter', 'Permit Fee - Slaughterhouse', 1000.00),
('Slaughter', 'Service Fee - Meat Inspection', 150.00),
('Slaughter', 'Permit Fee - Butcher License', 300.00),
('Slaughter', 'Service Fee - Facility Inspection', 200.00),
('Slaughter', 'Rental Fee - Cold Storage', 250.00);

-- Rent category entries
INSERT INTO receipt_natures (category, nature_of_collection, amount) VALUES
('Rent', 'Monthly Rent - Office Space', 5000.00),
('Rent', 'Monthly Rent - Warehouse', 8000.00),
('Rent', 'Quarterly Rent - Equipment', 1500.00),
('Rent', 'Annual Rent - Land Lease', 12000.00),
('Rent', 'Service Fee - Maintenance', 500.00);
