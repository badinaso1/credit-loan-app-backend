import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { login, getMe, logout } from '../controllers/auth.controller';
import { requireAuth } from '../middleware/auth';

const router = Router();

// Strict rate limit for login attempts to mitigate brute-force attacks.
// Uses the built-in IP extractor, which correctly handles X-Forwarded-For,
// proxies, and IPv6 addresses.
const loginRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // limit each IP to 10 login requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message: 'Too many login attempts from this IP, please try again after 15 minutes.'
  },
  // Trust proxy is configured safely in server.ts; don't crash if it is ever set to true.
  validate: { trustProxy: false },
});

router.post('/login', loginRateLimiter, login);
router.get('/me', requireAuth, getMe);
router.post('/logout', requireAuth, logout);

export default router;
