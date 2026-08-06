-- ============================================================
-- COMPLETE SUPABASE MIGRATION
-- Run this entire file in the new project's SQL Editor
-- This recreates the schema from the previous project screenshot
-- ============================================================

-- ============================================================
-- 1. TABLES
-- ============================================================

-- credit_requests
CREATE TABLE IF NOT EXISTS public.credit_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT,
    contact_number TEXT NOT NULL,
    id_number TEXT NOT NULL DEFAULT '',
    date_of_birth DATE,
    age INTEGER,
    sex TEXT,
    address TEXT NOT NULL DEFAULT '',
    profession TEXT NOT NULL DEFAULT '',
    loan_amount NUMERIC(12, 2) NOT NULL,
    interest_rate NUMERIC(5, 2) NOT NULL DEFAULT 0,
    currency TEXT,
    purpose TEXT,
    loan_term TEXT NOT NULL DEFAULT '',
    guarantee_type TEXT[] NOT NULL DEFAULT '{}',
    guarantee_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    receiver_name TEXT NOT NULL DEFAULT '',
    bank_platform TEXT NOT NULL DEFAULT '',
    photo_url TEXT,
    document_url TEXT,
    bank_statement_url TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    tracking_code TEXT UNIQUE,
    due_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- gallery_images
CREATE TABLE IF NOT EXISTS public.gallery_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    image_url TEXT NOT NULL,
    storage_path TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- loan_settings
CREATE TABLE IF NOT EXISTS public.loan_settings (
    id TEXT PRIMARY KEY DEFAULT 'default',
    interest_rate NUMERIC(5, 2) NOT NULL DEFAULT 10,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_credit_requests_tracking_code
ON public.credit_requests(tracking_code);

-- ============================================================
-- 3. updated_at TRIGGERS
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_credit_requests_updated_at ON public.credit_requests;
CREATE TRIGGER update_credit_requests_updated_at
    BEFORE UPDATE ON public.credit_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_gallery_images_updated_at ON public.gallery_images;
CREATE TRIGGER update_gallery_images_updated_at
    BEFORE UPDATE ON public.gallery_images
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_loan_settings_updated_at ON public.loan_settings;
CREATE TRIGGER update_loan_settings_updated_at
    BEFORE UPDATE ON public.loan_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 4. RPC FUNCTIONS
-- ============================================================

-- Drop old overloads safely
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT proname, pg_get_function_identity_arguments(oid) AS args
        FROM pg_proc
        WHERE pronamespace = 'public'::regnamespace
          AND proname IN ('create_credit_request', 'get_credit_request_by_tracking_code')
    LOOP
        EXECUTE format('DROP FUNCTION IF EXISTS public.%I(%s)', r.proname, r.args);
    END LOOP;
END $$;

-- create_credit_request
CREATE OR REPLACE FUNCTION public.create_credit_request(
    p_type TEXT,
    p_full_name TEXT,
    p_voter_id TEXT,
    p_date_of_birth DATE,
    p_sex TEXT,
    p_contact_number TEXT,
    p_address TEXT,
    p_profession TEXT,
    p_loan_amount NUMERIC,
    p_interest_rate NUMERIC,
    p_loan_term TEXT,
    p_guarantee_type TEXT[],
    p_guarantee_confirmed BOOLEAN,
    p_receiver_name TEXT,
    p_bank_platform TEXT,
    p_purpose TEXT,
    p_photo_url TEXT,
    p_status TEXT,
    p_due_date TIMESTAMPTZ,
    p_age INTEGER,
    p_document_url TEXT,
    p_bank_statement_url TEXT
)
RETURNS TABLE (
    id UUID,
    type TEXT,
    full_name TEXT,
    email TEXT,
    contact_number TEXT,
    id_number TEXT,
    date_of_birth DATE,
    sex TEXT,
    address TEXT,
    profession TEXT,
    loan_amount NUMERIC,
    interest_rate NUMERIC,
    currency TEXT,
    purpose TEXT,
    loan_term TEXT,
    guarantee_type TEXT[],
    guarantee_confirmed BOOLEAN,
    receiver_name TEXT,
    bank_platform TEXT,
    photo_url TEXT,
    document_url TEXT,
    bank_statement_url TEXT,
    status TEXT,
    tracking_code TEXT,
    due_date TIMESTAMPTZ,
    age INTEGER,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tracking_code TEXT;
    v_id UUID;
    v_interest_rate NUMERIC;
BEGIN
    -- Generate unique tracking code
    LOOP
        v_tracking_code := 'REQ-' || upper(substring(md5(random()::text) from 1 for 6));
        IF NOT EXISTS (SELECT 1 FROM public.credit_requests WHERE credit_requests.tracking_code = v_tracking_code) THEN
            EXIT;
        END IF;
    END LOOP;

    -- Use provided interest rate or fallback to global default
    IF p_interest_rate IS NOT NULL AND p_interest_rate > 0 THEN
        v_interest_rate := p_interest_rate;
    ELSE
        SELECT loan_settings.interest_rate INTO v_interest_rate
        FROM public.loan_settings
        WHERE loan_settings.id = 'default';
        v_interest_rate := COALESCE(v_interest_rate, 0);
    END IF;

    INSERT INTO public.credit_requests (
        type,
        full_name,
        email,
        contact_number,
        id_number,
        date_of_birth,
        sex,
        address,
        profession,
        loan_amount,
        interest_rate,
        currency,
        purpose,
        loan_term,
        guarantee_type,
        guarantee_confirmed,
        receiver_name,
        bank_platform,
        photo_url,
        document_url,
        bank_statement_url,
        status,
        tracking_code,
        due_date,
        age
    ) VALUES (
        p_type,
        p_full_name,
        NULL,
        p_contact_number,
        COALESCE(p_voter_id, ''),
        p_date_of_birth,
        p_sex,
        COALESCE(p_address, ''),
        COALESCE(p_profession, ''),
        p_loan_amount,
        v_interest_rate,
        NULL,
        p_purpose,
        COALESCE(p_loan_term, ''),
        COALESCE(p_guarantee_type, '{}'),
        COALESCE(p_guarantee_confirmed, FALSE),
        COALESCE(p_receiver_name, ''),
        COALESCE(p_bank_platform, ''),
        p_photo_url,
        p_document_url,
        p_bank_statement_url,
        COALESCE(p_status, 'pending'),
        v_tracking_code,
        p_due_date,
        p_age
    )
    RETURNING credit_requests.id INTO v_id;

    RETURN QUERY
    SELECT
        cr.id,
        cr.type,
        cr.full_name,
        cr.email,
        cr.contact_number,
        cr.id_number,
        cr.date_of_birth,
        cr.sex,
        cr.address,
        cr.profession,
        cr.loan_amount,
        cr.interest_rate,
        cr.currency,
        cr.purpose,
        cr.loan_term,
        cr.guarantee_type,
        cr.guarantee_confirmed,
        cr.receiver_name,
        cr.bank_platform,
        cr.photo_url,
        cr.document_url,
        cr.bank_statement_url,
        cr.status,
        cr.tracking_code,
        cr.due_date,
        cr.age,
        cr.created_at
    FROM public.credit_requests cr
    WHERE cr.id = v_id;
END;
$$;

-- get_credit_request_by_tracking_code
CREATE OR REPLACE FUNCTION public.get_credit_request_by_tracking_code(p_code TEXT)
RETURNS TABLE (
    id UUID,
    type TEXT,
    full_name TEXT,
    email TEXT,
    contact_number TEXT,
    id_number TEXT,
    date_of_birth DATE,
    sex TEXT,
    address TEXT,
    profession TEXT,
    loan_amount NUMERIC,
    interest_rate NUMERIC,
    currency TEXT,
    purpose TEXT,
    loan_term TEXT,
    guarantee_type TEXT[],
    guarantee_confirmed BOOLEAN,
    receiver_name TEXT,
    bank_platform TEXT,
    photo_url TEXT,
    document_url TEXT,
    bank_statement_url TEXT,
    status TEXT,
    tracking_code TEXT,
    due_date TIMESTAMPTZ,
    age INTEGER,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        cr.id,
        cr.type,
        cr.full_name,
        cr.email,
        cr.contact_number,
        cr.id_number,
        cr.date_of_birth,
        cr.sex,
        cr.address,
        cr.profession,
        cr.loan_amount,
        cr.interest_rate,
        cr.currency,
        cr.purpose,
        cr.loan_term,
        cr.guarantee_type,
        cr.guarantee_confirmed,
        cr.receiver_name,
        cr.bank_platform,
        cr.photo_url,
        cr.document_url,
        cr.bank_statement_url,
        cr.status,
        cr.tracking_code,
        cr.due_date,
        cr.age,
        cr.created_at
    FROM public.credit_requests cr
    WHERE cr.tracking_code = p_code;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.create_credit_request TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_credit_request_by_tracking_code TO anon, authenticated, service_role;

-- ============================================================
-- 5. ROW LEVEL SECURITY POLICIES
-- ============================================================

-- credit_requests
ALTER TABLE public.credit_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read" ON public.credit_requests;
DROP POLICY IF EXISTS "Allow public insert" ON public.credit_requests;
DROP POLICY IF EXISTS "Allow public update" ON public.credit_requests;
DROP POLICY IF EXISTS "Allow public delete" ON public.credit_requests;

CREATE POLICY "Authenticated users can read credit_requests"
  ON public.credit_requests
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can update credit_requests"
  ON public.credit_requests
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete credit_requests"
  ON public.credit_requests
  FOR DELETE
  TO authenticated
  USING (true);

-- loan_settings
ALTER TABLE public.loan_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read" ON public.loan_settings;
DROP POLICY IF EXISTS "Allow public update" ON public.loan_settings;

CREATE POLICY "Authenticated users can read loan_settings"
  ON public.loan_settings
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can update loan_settings"
  ON public.loan_settings
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- gallery_images
ALTER TABLE public.gallery_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read" ON public.gallery_images;
DROP POLICY IF EXISTS "Allow public insert" ON public.gallery_images;
DROP POLICY IF EXISTS "Allow public update" ON public.gallery_images;
DROP POLICY IF EXISTS "Allow public delete" ON public.gallery_images;

CREATE POLICY "Public can read gallery_images"
  ON public.gallery_images
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Authenticated users can modify gallery_images"
  ON public.gallery_images
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- 6. STORAGE BUCKETS AND POLICIES
-- ============================================================

-- uploads bucket (public gallery)
INSERT INTO storage.buckets (id, name, public, avif_autodetection, file_size_limit, allowed_mime_types)
VALUES (
    'uploads',
    'uploads',
    TRUE,
    FALSE,
    NULL,
    NULL
)
ON CONFLICT (id) DO UPDATE SET
    public = TRUE,
    file_size_limit = NULL,
    allowed_mime_types = NULL;

-- credit-documents bucket (private applicant documents)
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

-- Clean up old storage policies
DROP POLICY IF EXISTS "Service role can select credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Service role can insert credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Service role can update credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Service role can delete credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public access credit-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public access uploads" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload uploads" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete uploads" ON storage.objects;

-- credit-documents policies (service_role only)
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

-- uploads policies (public read, authenticated write/delete)
CREATE POLICY "Public can read uploads"
    ON storage.objects
    FOR SELECT
    TO anon, authenticated
    USING (bucket_id = 'uploads');

CREATE POLICY "Authenticated users can insert uploads"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'uploads');

CREATE POLICY "Authenticated users can delete uploads"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (bucket_id = 'uploads');

-- ============================================================
-- 7. SEED DEFAULT DATA
-- ============================================================

INSERT INTO public.loan_settings (id, interest_rate)
VALUES ('default', 10)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 8. RELOAD POSTGREST SCHEMA CACHE
-- ============================================================

NOTIFY pgrst, 'reload schema';
