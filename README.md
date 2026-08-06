# Credit Loan Backend API

## Tech Stack
- **Runtime**: Node.js + TypeScript
- **Framework**: Express.js
- **Database**: PostgreSQL (via Supabase or local)
- **ORM**: Prisma
- **File Upload**: Multer + Supabase Storage
- **Validation**: Zod
- **Security**: Helmet, CORS

## Getting Started

1. Copy `.env.example` to `.env` and fill in your credentials:
   ```bash
   cp .env.example .env
   ```

2. Run database migrations:
   ```bash
   npx prisma migrate dev --name init
   ```

3. Generate Prisma client:
   ```bash
   npx prisma generate
   ```

4. Start development server:
   ```bash
   npm run dev
   ```

## API Endpoints

### Credit Requests
- `POST /api/credits` - Create new credit request
- `GET /api/credits` - Get all credit requests
- `GET /api/credits/:id` - Get credit request by ID

### Currency Exchange
- `GET /api/currency/rates?base=USD` - Get live exchange rates
- `GET /api/currency/currencies` - Get supported currencies list

### File Upload
- `POST /api/upload` - Upload image file

## Scripts
- `npm run dev` - Start development server with hot reload
- `npm run build` - Compile TypeScript to JavaScript
- `npm start` - Start production server
- `npx prisma studio` - Open Prisma database GUI