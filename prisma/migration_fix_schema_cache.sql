-- ============================================================
-- URGENT FIX: Make email/currency/purpose nullable + update functions
-- Run this ENTIRE file in your Supabase SQL Editor
-- ============================================================

-- 1. Make existing columns nullable so the app doesn't break
ALTER TABLE public.credit_requests
ALTER COLUMN email DROP NOT NULL,
ALTER COLUMN currency DROP NOT NULL,
ALTER COLUMN purpose DROP NOT NULL;

-- 2. Add missing columns if they don't exist
ALTER TABLE public.credit_requests
ADD COLUMN IF NOT EXISTS date_of_birth DATE,
ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS profession TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS loan_term TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS guarantee_type TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS guarantee_confirmed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS receiver_name TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS bank_platform TEXT DEFAULT '';

-- 3. Ensure tracking_code exists
ALTER TABLE public.credit_requests
ADD COLUMN IF NOT EXISTS tracking_code TEXT UNIQUE;

-- 4. Create index
CREATE INDEX IF NOT EXISTS idx_credit_requests_tracking_code
ON public.credit_requests(tracking_code);

-- 5. Drop old functions to avoid signature conflicts
DROP FUNCTION IF EXISTS public.create_credit_request(TEXT,TEXT,TEXT,DATE,TEXT,TEXT,TEXT,NUMERIC,TEXT,TEXT[],BOOLEAN,TEXT,TEXT,TEXT,TEXT);
DROP FUNCTION IF EXISTS public.get_credit_request_by_tracking_code(TEXT);

-- 6. Create insert function that handles ALL real columns
CREATE OR REPLACE FUNCTION public.create_credit_request(
    p_type TEXT,
    p_full_name TEXT,
    p_voter_id TEXT,
    p_date_of_birth DATE,
    p_contact_number TEXT,
    p_address TEXT,
    p_profession TEXT,
    p_loan_amount NUMERIC,
    p_loan_term TEXT,
    p_guarantee_type TEXT[],
    p_guarantee_confirmed BOOLEAN,
    p_receiver_name TEXT,
    p_bank_platform TEXT,
    p_photo_url TEXT,
    p_status TEXT
)
RETURNS TABLE (
    id UUID,
    type TEXT,
    full_name TEXT,
    email TEXT,
    contact_number TEXT,
    id_number TEXT,
    date_of_birth DATE,
    address TEXT,
    profession TEXT,
    loan_amount NUMERIC,
    currency TEXT,
    purpose TEXT,
    loan_term TEXT,
    guarantee_type TEXT[],
    guarantee_confirmed BOOLEAN,
    receiver_name TEXT,
    bank_platform TEXT,
    photo_url TEXT,
    status TEXT,
    tracking_code TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tracking_code TEXT;
    v_id UUID;
BEGIN
    -- Generate unique tracking code
    LOOP
        v_tracking_code := 'REQ-' || upper(substring(md5(random()::text) from 1 for 6));
        IF NOT EXISTS (SELECT 1 FROM public.credit_requests WHERE credit_requests.tracking_code = v_tracking_code) THEN
            EXIT;
        END IF;
    END LOOP;

    INSERT INTO public.credit_requests (
        type,
        full_name,
        email,
        contact_number,
        id_number,
        date_of_birth,
        address,
        profession,
        loan_amount,
        currency,
        purpose,
        loan_term,
        guarantee_type,
        guarantee_confirmed,
        receiver_name,
        bank_platform,
        photo_url,
        status,
        tracking_code
    ) VALUES (
        p_type,
        p_full_name,
        NULL,
        p_contact_number,
        COALESCE(p_voter_id, ''),
        p_date_of_birth,
        COALESCE(p_address, ''),
        COALESCE(p_profession, ''),
        p_loan_amount,
        NULL,
        NULL,
        COALESCE(p_loan_term, ''),
        COALESCE(p_guarantee_type, '{}'),
        COALESCE(p_guarantee_confirmed, FALSE),
        COALESCE(p_receiver_name, ''),
        COALESCE(p_bank_platform, ''),
        p_photo_url,
        COALESCE(p_status, 'pending'),
        v_tracking_code
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
        cr.address,
        cr.profession,
        cr.loan_amount,
        cr.currency,
        cr.purpose,
        cr.loan_term,
        cr.guarantee_type,
        cr.guarantee_confirmed,
        cr.receiver_name,
        cr.bank_platform,
        cr.photo_url,
        cr.status,
        cr.tracking_code,
        cr.created_at
    FROM public.credit_requests cr
    WHERE cr.id = v_id;
END;
$$;

-- 7. Create lookup function that returns all real columns
CREATE OR REPLACE FUNCTION public.get_credit_request_by_tracking_code(p_code TEXT)
RETURNS TABLE (
    id UUID,
    type TEXT,
    full_name TEXT,
    email TEXT,
    contact_number TEXT,
    id_number TEXT,
    date_of_birth DATE,
    address TEXT,
    profession TEXT,
    loan_amount NUMERIC,
    currency TEXT,
    purpose TEXT,
    loan_term TEXT,
    guarantee_type TEXT[],
    guarantee_confirmed BOOLEAN,
    receiver_name TEXT,
    bank_platform TEXT,
    photo_url TEXT,
    status TEXT,
    tracking_code TEXT,
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
        cr.address,
        cr.profession,
        cr.loan_amount,
        cr.currency,
        cr.purpose,
        cr.loan_term,
        cr.guarantee_type,
        cr.guarantee_confirmed,
        cr.receiver_name,
        cr.bank_platform,
        cr.photo_url,
        cr.status,
        cr.tracking_code,
        cr.created_at
    FROM public.credit_requests cr
    WHERE cr.tracking_code = p_code;
END;
$$;

-- 8. Grant permissions
GRANT EXECUTE ON FUNCTION public.create_credit_request TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_credit_request_by_tracking_code TO anon, authenticated, service_role;

-- 9. Reload schema
NOTIFY pgrst, 'reload schema';
