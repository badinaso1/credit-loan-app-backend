import crypto from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const AUTH_TAG_LENGTH = 16;
const SALT_LENGTH = 64;
const KEY_LENGTH = 32;
const ITERATIONS = 100000;
const DIGEST = 'sha512';

function getKeyFromEnv(): Buffer {
  const secret = process.env.PII_ENCRYPTION_SECRET;
  if (!secret) {
    throw new Error(
      'Missing PII_ENCRYPTION_SECRET environment variable. Please set a strong random string (at least 32 characters).'
    );
  }
  return crypto.pbkdf2Sync(secret, 'badinas-pii-salt', ITERATIONS, KEY_LENGTH, DIGEST);
}

let encryptionKey: Buffer | null = null;

function getEncryptionKey(): Buffer {
  if (!encryptionKey) {
    encryptionKey = getKeyFromEnv();
  }
  return encryptionKey;
}

/**
 * Encrypt a plaintext string using AES-256-GCM.
 * Returns a base64 string containing: salt(64) + iv(16) + authTag(16) + ciphertext.
 */
export function encrypt(text: string | null | undefined): string | null {
  if (text === null || text === undefined || text === '') return text ?? null;

  try {
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv(ALGORITHM, getEncryptionKey(), iv);
    const encrypted = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag();

    const result = Buffer.concat([iv, authTag, encrypted]);
    return result.toString('base64');
  } catch (err) {
    console.error('Encryption error:', err);
    throw new Error('Failed to encrypt sensitive data');
  }
}

/**
 * Decrypt a base64 string produced by encrypt().
 */
export function decrypt(encryptedText: string | null | undefined): string | null {
  if (encryptedText === null || encryptedText === undefined || encryptedText === '') return encryptedText ?? null;

  try {
    const data = Buffer.from(encryptedText, 'base64');

    if (data.length < IV_LENGTH + AUTH_TAG_LENGTH) {
      // Not encrypted (legacy plaintext) — return as-is for migration safety
      return encryptedText;
    }

    const iv = data.subarray(0, IV_LENGTH);
    const authTag = data.subarray(IV_LENGTH, IV_LENGTH + AUTH_TAG_LENGTH);
    const encrypted = data.subarray(IV_LENGTH + AUTH_TAG_LENGTH);

    const decipher = crypto.createDecipheriv(ALGORITHM, getEncryptionKey(), iv);
    decipher.setAuthTag(authTag);

    const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
    return decrypted.toString('utf8');
  } catch (err) {
    console.error('Decryption error:', err);
    // If decryption fails, return null rather than leaking partial data
    return null;
  }
}

/**
 * Recursively decrypt sensitive fields on an object.
 * Safe to call on already-decrypted or mixed data.
 */
export function decryptSensitiveFields<T extends Record<string, any>>(
  row: T,
  fields: (keyof T)[]
): T {
  if (!row) return row;
  const result = { ...row };
  for (const field of fields) {
    const value = result[field];
    if (typeof value === 'string') {
      (result as any)[field] = decrypt(value);
    }
  }
  return result;
}

/**
 * Recursively encrypt sensitive fields on an object.
 */
export function encryptSensitiveFields<T extends Record<string, any>>(
  row: T,
  fields: (keyof T)[]
): T {
  if (!row) return row;
  const result = { ...row };
  for (const field of fields) {
    const value = result[field];
    if (typeof value === 'string') {
      (result as any)[field] = encrypt(value);
    }
  }
  return result;
}
