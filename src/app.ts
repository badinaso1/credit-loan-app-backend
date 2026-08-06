import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import creditRoutes from './routes/credit.routes';
import currencyRoutes from './routes/currency.routes';
import uploadRoutes from './routes/upload.routes';
import authRoutes from './routes/auth.routes';
import galleryRoutes from './routes/gallery.routes';

const app = express();

// Trust proxy when behind a reverse proxy (Vercel, nginx, etc.)
const trustProxyEnv = process.env.TRUST_PROXY || process.env.TRUST_PROXY_HOPS;
const trustProxySetting = trustProxyEnv
  ? trustProxyEnv === 'true'
    ? true
    : trustProxyEnv === 'false'
      ? false
      : Number(trustProxyEnv)
  : process.env.NODE_ENV === 'production'
    ? 1
    : false;

app.set('trust proxy', trustProxySetting);

// Middleware
app.use(helmet({
  hsts: {
    maxAge: 31536000, // 1 year
    includeSubDomains: true,
    preload: true
  }
}));
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  credentials: true
}));

// Enforce HTTPS in production
if (process.env.NODE_ENV === 'production') {
  app.use((req, res, next) => {
    if (req.headers['x-forwarded-proto'] !== 'https') {
      return res.redirect(301, `https://${req.headers.host}${req.url}`);
    }
    next();
  });
}

app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Static files for uploads (local dev only; Vercel has ephemeral filesystem)
if (process.env.NODE_ENV !== 'production') {
  app.use('/uploads', express.static('uploads'));
}

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/credits', creditRoutes);
app.use('/api/currency', currencyRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/gallery', galleryRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

// Error handler
app.use((err: any, req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    message: err.message || 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

export default app;
