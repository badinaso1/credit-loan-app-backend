import { Router } from 'express';
import multer from 'multer';
import { uploadImage, uploadCreditDocument } from '../controllers/upload.controller';

const router = Router();

// Configure multer for memory storage (we'll upload to Supabase Storage)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only PNG, JPG, or JPEG image files are allowed'));
    }
  }
});

// Public/Admin endpoint for gallery images (stored in public 'uploads' bucket)
router.post('/', upload.single('image'), uploadImage);

// Public endpoint for credit application documents (stored in private 'credit-documents' bucket)
router.post('/credit-document', upload.single('image'), uploadCreditDocument);

export default router;
