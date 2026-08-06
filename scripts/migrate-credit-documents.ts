/**
 * Migration script: Move existing credit application files from the public
 * 'uploads' bucket to the private 'credit-documents' bucket.
 *
 * Prerequisites:
 *   1. Run backend/prisma/migration_secure_credit_documents.sql in Supabase.
 *   2. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in backend/.env
 *
 * Run with: npx tsx scripts/migrate-credit-documents.ts
 */

import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const SOURCE_BUCKET = 'uploads';
const TARGET_BUCKET = 'credit-documents';

const supabase = createClient(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_SERVICE_ROLE_KEY || ''
);

interface CreditRequestRow {
  id: string;
  photo_url: string | null;
  document_url: string | null;
  bank_statement_url: string | null;
}

async function moveFile(path: string): Promise<boolean> {
  try {
    // 1. Download from source bucket
    const { data: downloadData, error: downloadError } = await supabase.storage
      .from(SOURCE_BUCKET)
      .download(path);

    if (downloadError || !downloadData) {
      console.error(`Failed to download ${path}:`, downloadError?.message);
      return false;
    }

    const buffer = await downloadData.arrayBuffer();

    // 2. Upload to target bucket
    const { error: uploadError } = await supabase.storage
      .from(TARGET_BUCKET)
      .upload(path, Buffer.from(buffer), {
        contentType: downloadData.type,
        upsert: false,
      });

    if (uploadError) {
      console.error(`Failed to upload ${path} to ${TARGET_BUCKET}:`, uploadError.message);
      return false;
    }

    // 3. Delete from source bucket (optional — comment out if you want to keep a copy)
    const { error: removeError } = await supabase.storage
      .from(SOURCE_BUCKET)
      .remove([path]);

    if (removeError) {
      console.warn(`Uploaded ${path} to ${TARGET_BUCKET} but failed to remove from ${SOURCE_BUCKET}:`, removeError.message);
    } else {
      console.log(`Moved ${path}`);
    }

    return true;
  } catch (err) {
    console.error(`Unexpected error moving ${path}:`, err);
    return false;
  }
}

async function main() {
  const { data, error } = await supabase
    .from('credit_requests')
    .select('id, photo_url, document_url, bank_statement_url');

  if (error) {
    console.error('Failed to fetch credit requests:', error.message);
    process.exit(1);
  }

  const rows = (data || []) as CreditRequestRow[];
  const pathsToMove = new Set<string>();

  for (const row of rows) {
    if (row.photo_url) pathsToMove.add(row.photo_url);
    if (row.document_url) pathsToMove.add(row.document_url);
    if (row.bank_statement_url) pathsToMove.add(row.bank_statement_url);
  }

  console.log(`Found ${pathsToMove.size} unique file(s) to move.`);

  let moved = 0;
  let failed = 0;

  for (const path of pathsToMove) {
    const success = await moveFile(path);
    if (success) moved++;
    else failed++;
  }

  console.log('\nMigration complete.');
  console.log(`Moved: ${moved}`);
  console.log(`Failed: ${failed}`);

  if (failed > 0) {
    process.exit(1);
  }
}

main();
