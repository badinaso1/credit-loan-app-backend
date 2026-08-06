-- Run these statements in the Supabase SQL Editor.
-- They enable Row Level Security (RLS) on sensitive tables and block
-- direct public access while allowing the authenticated backend (service role)
-- to continue operating normally.

-- ============================================
-- credit_requests
-- ============================================
ALTER TABLE credit_requests ENABLE ROW LEVEL SECURITY;

-- Drop any existing anonymous policies to ensure no accidental public access.
DROP POLICY IF EXISTS "Allow public read" ON credit_requests;
DROP POLICY IF EXISTS "Allow public insert" ON credit_requests;
DROP POLICY IF EXISTS "Allow public update" ON credit_requests;
DROP POLICY IF EXISTS "Allow public delete" ON credit_requests;

-- Authenticated admins can read all requests (used if backend switches to user JWT).
CREATE POLICY "Authenticated users can read credit_requests"
  ON credit_requests
  FOR SELECT
  TO authenticated
  USING (true);

-- Authenticated admins can update/delete all requests.
CREATE POLICY "Authenticated users can update credit_requests"
  ON credit_requests
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete credit_requests"
  ON credit_requests
  FOR DELETE
  TO authenticated
  USING (true);

-- ============================================
-- loan_settings
-- ============================================
ALTER TABLE loan_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read" ON loan_settings;
DROP POLICY IF EXISTS "Allow public update" ON loan_settings;

CREATE POLICY "Authenticated users can read loan_settings"
  ON loan_settings
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can update loan_settings"
  ON loan_settings
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================
-- gallery_images
-- ============================================
ALTER TABLE gallery_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read" ON gallery_images;
DROP POLICY IF EXISTS "Allow public insert" ON gallery_images;
DROP POLICY IF EXISTS "Allow public update" ON gallery_images;
DROP POLICY IF EXISTS "Allow public delete" ON gallery_images;

-- Gallery images can be viewed publicly (the public website displays them).
CREATE POLICY "Public can read gallery_images"
  ON gallery_images
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Only authenticated admins can modify gallery images.
CREATE POLICY "Authenticated users can modify gallery_images"
  ON gallery_images
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Note: The backend currently uses the Supabase service role key,
-- which bypasses RLS. These policies primarily protect against direct
-- client-side access using the anon/public key.
