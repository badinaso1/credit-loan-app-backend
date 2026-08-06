import { Router } from 'express';
import { getGalleryImages, createGalleryImage, deleteGalleryImage } from '../controllers/gallery.controller';
import { requireAuth } from '../middleware/auth';

const router = Router();

// Public route - anyone can view gallery
router.get('/', getGalleryImages);

// Protected routes - admin only
router.post('/', requireAuth, createGalleryImage);
router.delete('/:id', requireAuth, deleteGalleryImage);

export default router;
