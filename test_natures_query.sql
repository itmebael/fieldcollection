-- Test query to check if receipt_natures table has data
SELECT 
    category,
    nature_of_collection,
    amount,
    marine_flow,
    COUNT(*) as total_count
FROM receipt_natures 
GROUP BY category, nature_of_collection, amount, marine_flow
ORDER BY category, nature_of_collection;

-- Check if table exists and has any data
SELECT 
    'receipt_natures' as table_name,
    COUNT(*) as row_count
FROM receipt_natures
UNION ALL
SELECT 
    'receipts' as table_name,
    COUNT(*) as row_count
FROM receipts;