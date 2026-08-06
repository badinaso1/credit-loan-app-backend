-- ============================================================
-- MIGRATION: Add document_url column and update functions
-- Run this ENTIRE file in your Supabase SQL Editor
-- ============================================================

-- 1. Add document_url column to credit_requests
ALTER TABLE public.credit_requests
ADD COLUMN IF NOT EXISTS document_url TEXT;

-- 2. Drop ALL existing overloads of the affected functions safely
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

-- 3. Create updated insert function with document_url
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
    p_document_url TEXT
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
        cr.status,
        cr.tracking_code,
        cr.due_date,
        cr.age,
        cr.created_at
    FROM public.credit_requests cr
    WHERE cr.id = v_id;
END;
$$;

-- 4. Drop and recreate lookup function with document_url
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
        cr.status,
        cr.tracking_code,
        cr.due_date,
        cr.age,
        cr.created_at
    FROM public.credit_requests cr
    WHERE cr.tracking_code = p_code;
END;
$$;

-- 5. Grant permissions
GRANT EXECUTE ON FUNCTION public.create_credit_request TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_credit_request_by_tracking_code TO anon, authenticated, service_role;

-- 6. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
