import { Request, Response } from 'express';
import { supabase } from '../lib/supabase';

const CREDIT_DOCUMENTS_BUCKET = 'credit-documents';
const GALLERY_BUCKET = 'uploads';

function generateFilePath(prefix: string): string {
  const fileExt = prefix.split('.').pop() || 'png';
  const fileName = `${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExt}`;
  return `credit-applications/${fileName}`;
}

export const uploadImage = async (req: Request, res: Response) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No image file provided' });
    }

    const file = req.file;
    const filePath = generateFilePath(file.originalname);

    // Upload to public Supabase Storage bucket used by the gallery
    const { error } = await supabase.storage
      .from(GALLERY_BUCKET)
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: false
      });

    if (error) {
      console.error('Supabase storage error:', error);
      return res.status(500).json({ message: 'Failed to upload image', error: error.message });
    }

    // Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from(GALLERY_BUCKET)
      .getPublicUrl(filePath);

    res.json({
      message: 'Image uploaded successfully',
      url: publicUrl,
      path: filePath
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};

export const uploadCreditDocument = async (req: Request, res: Response) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No document file provided' });
    }

    const file = req.file;
    const filePath = generateFilePath(file.originalname);

    // Upload to private Supabase Storage bucket for credit documents
    const { error } = await supabase.storage
      .from(CREDIT_DOCUMENTS_BUCKET)
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: false
      });

    if (error) {
      console.error('Supabase storage error:', error);
      return res.status(500).json({ message: 'Failed to upload document', error: error.message });
    }

    res.json({
      message: 'Document uploaded successfully',
      path: filePath
    });
  } catch (error) {
    console.error('Credit document upload error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};
