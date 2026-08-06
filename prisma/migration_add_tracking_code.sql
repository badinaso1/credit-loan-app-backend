-- Add tracking_code column to credit_requests table
-- Run this in your Supabase SQL Editor

ALTER TABLE credit_requests
ADD COLUMN IF NOT EXISTS tracking_code TEXT UNIQUE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_credit_requests_tracking_code
ON credit_requests(tracking_code);
