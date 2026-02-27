-- Updated ALTER TABLE SQL for receipts table based on actual Supabase schema
-- This matches the existing table structure that has a 'price' column

-- First, check if the table exists and what columns it has
-- Run this to see current structure: \d receipts

-- If you need to add missing columns, use these:
ALTER TABLE receipts
ADD COLUMN IF NOT EXISTS category TEXT,
ADD COLUMN IF NOT EXISTS marine_flow TEXT,
ADD COLUMN IF NOT EXISTS nature_of_collection TEXT,
ADD COLUMN IF NOT EXISTS html_content TEXT,
ADD COLUMN IF NOT EXISTS collection_items JSONB;

-- Note: The table already has 'price' column that's NOT NULL
-- So we use 'price' instead of 'collection_price'

-- Add constraints for required fields
ALTER TABLE receipts
ALTER COLUMN category SET NOT NULL,
ALTER COLUMN saved_at SET NOT NULL,
ALTER COLUMN file_name SET NOT NULL;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_receipts_category ON receipts(category);
CREATE INDEX IF NOT EXISTS idx_receipts_marine_flow ON receipts(marine_flow);
CREATE INDEX IF NOT EXISTS idx_receipts_saved_at ON receipts(saved_at DESC);

-- If you need to check what columns exist, run:
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'receipts';

-- If you need to rename 'collection_price' to 'price' (if it exists):
-- ALTER TABLE receipts RENAME COLUMN collection_price TO price;