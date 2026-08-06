import { Request, Response } from 'express';
import { supabase } from '../lib/supabase';

// Map snake_case DB row to camelCase API response
function mapGalleryDbToApi(row: any) {
  if (!row) return null;
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    imageUrl: row.image_url,
    storagePath: row.storage_path,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export const getGalleryImages = async (_req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('gallery_images')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(500).json({ message: 'Failed to fetch gallery images', error: error.message });
    }

    const mapped = (data || []).map(mapGalleryDbToApi);
    res.json({ data: mapped });
  } catch (error) {
    console.error('Get gallery images error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};

export const createGalleryImage = async (req: Request, res: Response) => {
  try {
    const { title, description, imageUrl, storagePath } = req.body;

    if (!imageUrl) {
      return res.status(400).json({ message: 'imageUrl is required' });
    }

    const { data, error } = await supabase
      .from('gallery_images')
      .insert({
        title: title || '',
        description: description || '',
        image_url: imageUrl,
        storage_path: storagePath || '',
      })
      .select()
      .single();

    if (error) {
      console.error('Supabase insert error:', error);
      return res.status(500).json({ message: 'Failed to save gallery image', error: error.message });
    }

    res.status(201).json({
      message: 'Gallery image added successfully',
      data: mapGalleryDbToApi(data),
    });
  } catch (error) {
    console.error('Create gallery image error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};

export const deleteGalleryImage = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    // Fetch the image to get storage path before deleting
    const { data: imageData, error: fetchError } = await supabase
      .from('gallery_images')
      .select('*')
      .eq('id', id)
      .single();

    if (fetchError) {
      return res.status(500).json({ message: 'Failed to fetch gallery image', error: fetchError.message });
    }

    if (!imageData) {
      return res.status(404).json({ message: 'Gallery image not found' });
    }

    // Delete from Supabase Storage if storage path exists
    if (imageData.storage_path) {
      const { error: storageError } = await supabase.storage
        .from('uploads')
        .remove([imageData.storage_path]);

      if (storageError) {
        console.error('Supabase storage delete error:', storageError);
        // Continue with DB deletion even if storage deletion fails
      }
    }

    // Delete from database
    const { error: deleteError } = await supabase
      .from('gallery_images')
      .delete()
      .eq('id', id);

    if (deleteError) {
      return res.status(500).json({ message: 'Failed to delete gallery image', error: deleteError.message });
    }

    res.json({ message: 'Gallery image deleted successfully' });
  } catch (error) {
    console.error('Delete gallery image error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
};
