import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { createCreditRequest, getCreditRequests, getCreditRequestById, updateCreditStatus, deleteCreditRequest, getCreditRequestByTrackingCode, getInterestRate, updateInterestRate } from '../controllers/credit.controller';
import { requireAuth } from '../middleware/auth';

const router = Router();

// Rate limit public submissions to prevent spam / abuse.
const submitRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 100, // 100 submissions per IP per hour
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message: 'Too many credit requests submitted from this IP, please try again later.'
  },
  // Trust proxy is configured safely in server.ts; don't crash if it is ever set to true.
  validate: { trustProxy: false },
});

// Public: anyone can submit a credit request, track by code, or view current interest rate
router.post('/', submitRateLimiter, createCreditRequest);
router.get('/track/:code', getCreditRequestByTrackingCode);
router.get('/settings/interest-rate', getInterestRate);

// Protected: only authenticated admins can view requests and manage settings
router.get('/', requireAuth, getCreditRequests);
router.get('/:id', requireAuth, getCreditRequestById);
router.patch('/:id/status', requireAuth, updateCreditStatus);
router.delete('/:id', requireAuth, deleteCreditRequest);
router.patch('/settings/interest-rate', requireAuth, updateInterestRate);

export default router;
