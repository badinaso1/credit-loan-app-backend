import { Request, Response } from 'express';
import { z } from 'zod';
import { supabase } from '../lib/supabase';
import { encrypt, decrypt } from '../lib/encryption';

const CREDIT_DOCUMENTS_BUCKET = 'credit-documents';
const SIGNED_URL_EXPIRY_SECONDS = 60 * 60; // 1 hour
const SENSITIVE_FIELDS = ['voterId', 'contactNumber', 'address'] as const;

const creditRequestSchema = z.object({
  type: z.enum(['domestic', 'international']),
  fullName: z.string().min(1),
  voterId: z.string().default(''),
  dateOfBirth: z.string().optional(),
  age: z.number().int().nonnegative().optional(),
  sex: z.string().optional(),
  contactNumber: z.string().min(1),
  address: z.string().default(''),
  profession: z.string().default(''),
  loanAmount: z.number().positive(),
  interestRate: z.number().min(0).default(0),
  loanTerm: z.string().min(1),
  guaranteeType: z.array(z.string()).default([]),
  guaranteeConfirmed: z.boolean().default(false),
  receiverName: z.string().default(''),
  bankPlatform: z.string().default(''),
  purpose: z.string().optional(),
  photoUrl: z.string().optional(),
  documentUrl: z.string().optional(),
  bankStatementUrl: z.string().optional(),
  status: z.enum(['pending', 'approved', 'rejected']).default('pending')
});

async function createSignedUrl(path: string | null): Promise<string | null> {
  if (!path) return null;
  try {
    const { data, error } = await supabase.storage
      .from(CREDIT_DOCUMENTS_BUCKET)
      .createSignedUrl(path, SIGNED_URL_EXPIRY_SECONDS);
    if (error) {
      console.error('Failed to create signed URL:', error);
      return null;
    }
    return data?.signedUrl || null;
  } catch (err) {
    console.error('Error creating signed URL:', err);
    return null;
  }
}

function calculateDueDate(loanTerm: string): Date {
  // const minuteMatch = loanTerm.match(/^(\d+)_minutes?$/);
  // if (minuteMatch) {
  //   const minutes = parseInt(minuteMatch[1], 10);
  //   const dueDate = new Date();
  //   dueDate.setMinutes(dueDate.getMinutes() + minutes);
  //   return dueDate;
  // }
  const match = loanTerm.match(/^(\d+)_month/);
  const months = match ? parseInt(match[1], 10) : 1;
  const dueDate = new Date();
  dueDate.setMonth(dueDate.getMonth() + months);
  return dueDate;
}

// Map snake_case DB row to camelCase API response for admin use.
// File columns store paths; we convert them to short-lived signed URLs here.
// Sensitive PII fields are decrypted before returning.
async function mapDbToApi(row: any) {
  if (!row) return null;
  const [photoUrl, documentUrl, bankStatementUrl] = await Promise.all([
    createSignedUrl(row.photo_url),
    createSignedUrl(row.document_url),
    createSignedUrl(row.bank_statement_url),
  ]);
  return {
    id: row.id,
    type: row.type,
    fullName: row.full_name,
    voterId: decrypt(row.id_number),
    dateOfBirth: row.date_of_birth,
    age: row.age,
    sex: row.sex,
    contactNumber: decrypt(row.contact_number),
    address: decrypt(row.address),
    profession: row.profession,
    loanAmount: row.loan_amount,
    interestRate: row.interest_rate,
    loanTerm: row.loan_term,
    guaranteeType: row.guarantee_type,
    guaranteeConfirmed: row.guarantee_confirmed,
    receiverName: row.receiver_name,
    bankPlatform: row.bank_platform,
    purpose: row.purpose,
    photoUrl,
    documentUrl,
    bankStatementUrl,
    status: row.status,
    trackingCode: row.tracking_code,
    dueDate: row.due_date,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// Public tracker response: no sensitive PII, no signed document URLs.
function mapDbToPublicApi(row: any) {
  if (!row) return null;
  return {
    id: row.id,
    type: row.type,
    status: row.status,
    loanAmount: row.loan_amount,
    interestRate: row.interest_rate,
    loanTerm: row.loan_term,
    trackingCode: row.tracking_code,
    dueDate: row.due_date,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export const createCreditRequest = async (req: Request, res: Response) => {
  try {
    const validatedData = creditRequestSchema.parse(req.body);
    const dueDate = calculateDueDate(validatedData.loanTerm);

    // Fetch current global interest rate if not supplied
    let interestRate = validatedData.interestRate;
    if (!interestRate || interestRate <= 0) {
      const { data: settingData } = await supabase
        .from('loan_settings')
        .select('interest_rate')
        .eq('id', 'default')
        .single();
      interestRate = settingData?.interest_rate ? Number(settingData.interest_rate) : 0;
    }

    const { data, error } = await supabase.rpc('create_credit_request', {
      p_type: validatedData.type,
      p_full_name: validatedData.fullName,
      p_voter_id: encrypt(validatedData.voterId) ?? '',
      p_date_of_birth: validatedData.dateOfBirth || null,
      p_sex: validatedData.sex || null,
      p_contact_number: encrypt(validatedData.contactNumber) ?? '',
      p_address: encrypt(validatedData.address) ?? '',
      p_profession: validatedData.profession,
      p_loan_amount: validatedData.loanAmount,
      p_interest_rate: interestRate,
      p_loan_term: validatedData.loanTerm,
      p_guarantee_type: validatedData.guaranteeType,
      p_guarantee_confirmed: validatedData.guaranteeConfirmed,
      p_receiver_name: validatedData.receiverName,
      p_bank_platform: validatedData.bankPlatform,
      p_purpose: validatedData.purpose || null,
      p_photo_url: validatedData.photoUrl || null,
      p_status: validatedData.status,
      p_due_date: dueDate.toISOString(),
      p_age: validatedData.age ?? null,
      p_document_url: validatedData.documentUrl || null,
      p_bank_statement_url: validatedData.bankStatementUrl || null
    });

    if (error) {
      console.error('Supabase RPC error:', error);
      return res.status(500).json({ message: 'Failed to create credit request', error: error.message });
    }

    const row = Array.isArray(data) && data.length > 0 ? data[0] : data;
    const mapped = await mapDbToApi(row);

    res.status(201).json({
      message: 'Credit request submitted successfully',
      data: mapped,
      trackingCode: mapped?.trackingCode
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ message: 'Validation error', errors: error.errors });
    }
    console.error('Create credit request error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};

export const getCreditRequests = async (req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('credit_requests')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(500).json({ message: 'Failed to fetch credit requests', error: error.message });
    }

    const mapped = await Promise.all((data || []).map(mapDbToApi));
    res.json({ data: mapped });
  } catch (error) {
    console.error('Get credit requests error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};

export const getCreditRequestById = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabase
      .from('credit_requests')
      .select('*')
      .eq('id', id)
      .single();

    if (error) {
      return res.status(500).json({ message: 'Failed to fetch credit request', error: error.message });
    }

    if (!data) {
      return res.status(404).json({ message: 'Credit request not found' });
    }

    res.json({ data: await mapDbToApi(data) });
  } catch (error) {
    console.error('Get credit request error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};

export const updateCreditStatus = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!['pending', 'approved', 'rejected'].includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }

    const { data, error } = await supabase
      .from('credit_requests')
      .update({ status })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(500).json({ message: 'Failed to update credit request', error: error.message });
    }

    res.json({ message: 'Status updated successfully', data: await mapDbToApi(data) });
  } catch (error) {
    console.error('Update credit status error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};

export const deleteCreditRequest = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    // Fetch the request to get the photo URL before deleting
    const { data: requestData, error: fetchError } = await supabase
      .from('credit_requests')
      .select('*')
      .eq('id', id)
      .single();

    if (fetchError) {
      return res.status(500).json({ message: 'Failed to fetch credit request', error: fetchError.message });
    }

    if (!requestData) {
      return res.status(404).json({ message: 'Credit request not found' });
    }

    const photoUrl = requestData.photo_url;
    const documentUrl = requestData.document_url;
    const bankStatementUrl = requestData.bank_statement_url;

    // Delete associated files from the private credit-documents bucket.
    // The DB columns now store storage paths, so they can be removed directly.
    const storagePaths: string[] = [];
    for (const path of [photoUrl, documentUrl, bankStatementUrl]) {
      if (path) storagePaths.push(path);
    }

    if (storagePaths.length > 0) {
      const { error: storageError } = await supabase.storage
        .from(CREDIT_DOCUMENTS_BUCKET)
        .remove(storagePaths);

      if (storageError) {
        console.error('Supabase storage delete error:', storageError);
        // Continue with DB deletion even if storage deletion fails
      }
    }

    // Delete the credit request from the database
    const { error: deleteError } = await supabase
      .from('credit_requests')
      .delete()
      .eq('id', id);

    if (deleteError) {
      return res.status(500).json({ message: 'Failed to delete credit request', error: deleteError.message });
    }

    res.json({ message: 'Credit request deleted successfully' });
  } catch (error) {
    console.error('Delete credit request error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};

export const getCreditRequestByTrackingCode = async (req: Request, res: Response) => {
  try {
    const { code } = req.params;

    const { data, error } = await supabase.rpc('get_credit_request_by_tracking_code', {
      p_code: code
    });

    if (error) {
      console.error('Supabase RPC error:', error);
      return res.status(500).json({ message: 'Failed to fetch credit request', error: error.message });
    }

    const rows = Array.isArray(data) ? data : [];
    if (rows.length === 0) {
      return res.status(404).json({ message: 'Request not found' });
    }

    res.json({ data: mapDbToPublicApi(rows[0]) });
  } catch (error) {
    console.error('Get credit request by tracking code error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};

export const getInterestRate = async (req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('loan_settings')
      .select('interest_rate, updated_at')
      .eq('id', 'default')
      .single();

    if (error) {
      console.error('Get interest rate error:', error);
      return res.status(500).json({ message: 'Failed to fetch interest rate', error: error.message });
    }

    res.json({
      data: {
        interestRate: data?.interest_rate ? Number(data.interest_rate) : 0,
        updatedAt: data?.updated_at
      }
    });
  } catch (error) {
    console.error('Get interest rate error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};

export const updateInterestRate = async (req: Request, res: Response) => {
  try {
    const { interestRate } = req.body;

    if (typeof interestRate !== 'number' || interestRate < 0 || interestRate > 100) {
      return res.status(400).json({ message: 'Invalid interest rate. Must be a number between 0 and 100.' });
    }

    const { data, error } = await supabase
      .from('loan_settings')
      .update({ interest_rate: interestRate })
      .eq('id', 'default')
      .select('interest_rate, updated_at')
      .single();

    if (error) {
      console.error('Update interest rate error:', error);
      return res.status(500).json({ message: 'Failed to update interest rate', error: error.message });
    }

    res.json({
      message: 'Interest rate updated successfully',
      data: {
        interestRate: data?.interest_rate ? Number(data.interest_rate) : interestRate,
        updatedAt: data?.updated_at
      }
    });
  } catch (error) {
    console.error('Update interest rate error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};
