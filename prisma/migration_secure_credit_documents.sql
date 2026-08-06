-- ============================================================
-- MIGRATION: Secure credit applicant documents in private storage
-- Run this ENTIRE file in your Supabase SQL Editor
-- ============================================================

-- 1. Create a private bucket for credit application documents.
--    Gallery/public images can remain in the existing 'uploads' bucket.
INSERT INTO storage.buckets (id, name, public, avif_autodetection, file_size_limit, allowed_mime_types)
VALUES (
    'credit-documents',
    'credit-documents',
    FALSE,
    FALSE,
    10485760, -- 10 MB
    ARRAY['image/png', 'image/jpeg', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET
    public = FALSE,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/jpg'];

-- 2. Clean up any existing policies on the new bucket.
DROP POLICY IF EXISTS "Service role can select credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Service role can insert credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Service role can update credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Service role can delete credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public access credit-documents" ON storage.objects;

-- 3. Add restrictive policies. Only service_role can manage objects.
--    Service role bypasses RLS, but explicit policies document the intent.
CREATE POLICY "Service role can select credit-documents"
    ON storage.objects
    FOR SELECT
    TO service_role
    USING (bucket_id = 'credit-documents');

CREATE POLICY "Service role can insert credit-documents"
    ON storage.objects
    FOR INSERT
    TO service_role
    WITH CHECK (bucket_id = 'credit-documents');

CREATE POLICY "Service role can update credit-documents"
    ON storage.objects
    FOR UPDATE
    TO service_role
    USING (bucket_id = 'credit-documents');

CREATE POLICY "Service role can delete credit-documents"
    ON storage.objects
    FOR DELETE
    TO service_role
    USING (bucket_id = 'credit-documents');

-- 4. Convert existing full public URLs in credit_requests to storage paths.
--    Example URL: https://<project>.supabase.co/storage/v1/object/public/uploads/credit-applications/123.png
--    We extract everything after '/uploads/'.
UPDATE public.credit_requests
SET photo_url = substring(photo_url from '/uploads/([^?#]+)')
WHERE photo_url IS NOT NULL AND photo_url LIKE '%/uploads/%';

UPDATE public.credit_requests
SET document_url = substring(document_url from '/uploads/([^?#]+)')
WHERE document_url IS NOT NULL AND document_url LIKE '%/uploads/%';

UPDATE public.credit_requests
SET bank_statement_url = substring(bank_statement_url from '/uploads/([^?#]+)')
WHERE bank_statement_url IS NOT NULL AND bank_statement_url LIKE '%/uploads/%';

-- 5. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
