# Credit Loan API Documentation

**Base URL:** `https://credit-loan-app-backend.vercel.app`

---

## Table of Contents

1. [Authentication](#authentication)
2. [Endpoints](#endpoints)
   - [Health Check](#health-check)
   - [Auth](#auth)
   - [Credits](#credits)
   - [Currency](#currency)
   - [Upload](#upload)
   - [Gallery](#gallery)
3. [Response Codes](#response-codes)

---

## Authentication

This API uses **Supabase Auth** with **Bearer tokens**.

### How to authenticate:
1. Call `POST /api/auth/login` with email and password to receive an `access_token`.
2. For every protected endpoint, add this header:
   ```
   Authorization: Bearer <access_token>
   ```

---

## Endpoints

### Health Check

#### `GET /health`

**Description:** Check if the server is running.

**Auth Required:** No

**Response (200 OK):**
```json
{
  "status": "OK",
  "timestamp": "2026-08-11T12:06:03.187Z"
}
```

---

### Auth

#### `POST /api/auth/login`

**Description:** Log in a user and receive an access token.

**Auth Required:** No  
**Rate Limit:** 10 requests per 15 minutes per IP

**Headers:**
```
Content-Type: application/json
```

**Request Body:**
```json
{
  "email": "admin@example.com",
  "password": "yourpassword"
}
```

**Response (200 OK):**
```json
{
  "message": "Login successful",
  "user": {
    "id": "...",
    "email": "admin@example.com"
  },
  "session": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "...",
    "expires_at": 1234567890
  }
}
```

**Response (401 Unauthorized):**
```json
{
  "message": "Invalid credentials",
  "error": "Invalid login credentials"
}
```

**Response (429 Too Many Requests):**
```json
{
  "message": "Too many login attempts from this IP, please try again after 15 minutes."
}
```

---

#### `GET /api/auth/me`

**Description:** Get the currently logged-in user's information.

**Auth Required:** Yes (`Bearer <token>`)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "user": {
    "id": "...",
    "email": "admin@example.com"
  }
}
```

**Response (401 Unauthorized):**
```json
{
  "message": "Unauthorized: No token provided"
}
```

---

#### `POST /api/auth/logout`

**Description:** Log out the current user.

**Auth Required:** Yes (`Bearer <token>`)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "message": "Logout successful"
}
```

---

### Credits

#### `POST /api/credits/`

**Description:** Submit a new credit/loan request. This is a **public** endpoint (anyone can submit).

**Auth Required:** No  
**Rate Limit:** 100 submissions per IP per hour

**Headers:**
```
Content-Type: application/json
```

**Request Body:**
```json
{
  "type": "domestic",
  "fullName": "John Doe",
  "voterId": "V12345678",
  "dateOfBirth": "1990-05-15",
  "age": 34,
  "sex": "Male",
  "contactNumber": "+1234567890",
  "address": "123 Main Street",
  "profession": "Software Engineer",
  "loanAmount": 5000.00,
  "interestRate": 10.0,
  "loanTerm": "12_months",
  "guaranteeType": ["collateral"],
  "guaranteeConfirmed": true,
  "receiverName": "Jane Doe",
  "bankPlatform": "Chase",
  "purpose": "Business expansion",
  "photoUrl": "path/to/photo.jpg",
  "documentUrl": "path/to/document.pdf",
  "bankStatementUrl": "path/to/statement.pdf",
  "status": "pending"
}
```

**Field Details:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `type` | string enum | Yes | — | `domestic` or `international` |
| `fullName` | string | Yes | — | Applicant full name |
| `voterId` | string | No | `""` | Voter / ID number |
| `dateOfBirth` | string (ISO date) | No | `null` | e.g. `"1990-05-15"` |
| `age` | integer | No | `null` | Age in years |
| `sex` | string | No | `null` | e.g. `"Male"`, `"Female"` |
| `contactNumber` | string | Yes | — | Phone number |
| `address` | string | No | `""` | Home address |
| `profession` | string | No | `""` | Job / profession |
| `loanAmount` | number | Yes | — | Loan amount (positive) |
| `interestRate` | number | No | `0` | Interest rate % |
| `loanTerm` | string | Yes | — | e.g. `"12_months"` |
| `guaranteeType` | string[] | No | `[]` | Array of guarantee types |
| `guaranteeConfirmed` | boolean | No | `false` | Guarantee confirmation |
| `receiverName` | string | No | `""` | Receiver name |
| `bankPlatform` | string | No | `""` | Bank / platform name |
| `purpose` | string | No | `null` | Loan purpose |
| `photoUrl` | string | No | `null` | Storage path from upload |
| `documentUrl` | string | No | `null` | Storage path from upload |
| `bankStatementUrl` | string | No | `null` | Storage path from upload |
| `status` | string enum | No | `"pending"` | `pending`, `approved`, `rejected` |

**Response (201 Created):**
```json
{
  "message": "Credit request submitted successfully",
  "data": {
    "id": "uuid",
    "type": "domestic",
    "fullName": "John Doe",
    "voterId": "V12345678",
    "dateOfBirth": "1990-05-15T00:00:00.000Z",
    "age": 34,
    "sex": "Male",
    "contactNumber": "+1234567890",
    "address": "123 Main Street",
    "profession": "Software Engineer",
    "loanAmount": 5000,
    "interestRate": 10,
    "loanTerm": "12_months",
    "guaranteeType": ["collateral"],
    "guaranteeConfirmed": true,
    "receiverName": "Jane Doe",
    "bankPlatform": "Chase",
    "purpose": "Business expansion",
    "photoUrl": "https://...signed-url...",
    "documentUrl": "https://...signed-url...",
    "bankStatementUrl": "https://...signed-url...",
    "status": "pending",
    "trackingCode": "TRK-ABC123",
    "dueDate": "2027-08-11T00:00:00.000Z",
    "createdAt": "2026-08-11T12:00:00.000Z",
    "updatedAt": "2026-08-11T12:00:00.000Z"
  },
  "trackingCode": "TRK-ABC123"
}
```

**Response (400 Bad Request):**
```json
{
  "message": "Validation error",
  "errors": [
    { "path": ["fullName"], "message": "Required" }
  ]
}
```

**Response (429 Too Many Requests):**
```json
{
  "message": "Too many credit requests submitted from this IP, please try again later."
}
```

---

#### `GET /api/credits/`

**Description:** List all credit requests (admin only).

**Auth Required:** Yes (`Bearer <token>`)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "uuid",
      "fullName": "John Doe",
      ...,
      "trackingCode": "TRK-ABC123"
    }
  ]
}
```

---

#### `GET /api/credits/:id`

**Description:** Get a single credit request by ID (admin only).

**Auth Required:** Yes (`Bearer <token>`)

**Response (200 OK):**
```json
{
  "data": { ...full credit request object... }
}
```

**Response (404 Not Found):**
```json
{
  "message": "Credit request not found"
}
```

---

#### `GET /api/credits/track/:code`

**Description:** Track a credit request by its tracking code. **Public** endpoint (no auth).

**Auth Required:** No

**URL Example:** `GET /api/credits/track/TRK-ABC123`

**Response (200 OK):**
```json
{
  "data": {
    "id": "uuid",
    "type": "domestic",
    "status": "pending",
    "loanAmount": 5000,
    "interestRate": 10,
    "loanTerm": "12_months",
    "trackingCode": "TRK-ABC123",
    "dueDate": "2027-08-11T00:00:00.000Z",
    "createdAt": "2026-08-11T12:00:00.000Z",
    "updatedAt": "2026-08-11T12:00:00.000Z"
  }
}
```

**Response (404 Not Found):**
```json
{
  "message": "Request not found"
}
```

---

#### `PATCH /api/credits/:id/status`

**Description:** Update the status of a credit request (admin only).

**Auth Required:** Yes (`Bearer <token>`)

**Request Body:**
```json
{
  "status": "approved"
}
```

*Allowed values:* `pending`, `approved`, `rejected`

**Response (200 OK):**
```json
{
  "message": "Status updated successfully",
  "data": { ...updated credit request... }
}
```

**Response (400 Bad Request):**
```json
{
  "message": "Invalid status"
}
```

---

#### `DELETE /api/credits/:id`

**Description:** Delete a credit request and its associated files (admin only).

**Auth Required:** Yes (`Bearer <token>`)

**Response (200 OK):**
```json
{
  "message": "Credit request deleted successfully"
}
```

---

#### `GET /api/credits/settings/interest-rate`

**Description:** Get the current global interest rate setting. **Public** endpoint.

**Auth Required:** No

**Response (200 OK):**
```json
{
  "data": {
    "interestRate": 10,
    "updatedAt": "2026-08-11T10:00:00.000Z"
  }
}
```

---

#### `PATCH /api/credits/settings/interest-rate`

**Description:** Update the global interest rate (admin only).

**Auth Required:** Yes (`Bearer <token>`)

**Request Body:**
```json
{
  "interestRate": 12.5
}
```

*Must be a number between 0 and 100.*

**Response (200 OK):**
```json
{
  "message": "Interest rate updated successfully",
  "data": {
    "interestRate": 12.5,
    "updatedAt": "2026-08-11T12:30:00.000Z"
  }
}
```

---

### Currency

#### `GET /api/currency/rates`

**Description:** Get current exchange rates. **Public** endpoint.

**Auth Required:** No

**Query Parameters:**
- `base` (optional) — Base currency code, default is `USD`

**URL Example:** `GET /api/currency/rates?base=USD`

**Response (200 OK):**
```json
{
  "base": "USD",
  "date": "2026-08-11",
  "rates": {
    "EUR": 0.92,
    "GBP": 0.79,
    "JPY": 145.30,
    ...
  }
}
```

---

#### `GET /api/currency/currencies`

**Description:** Get a list of supported currency codes. **Public** endpoint.

**Auth Required:** No

**Response (200 OK):**
```json
{
  "currencies": ["EUR", "GBP", "JPY", "AUD", "CAD", ...],
  "count": 30
}
```

---

### Upload

#### `POST /api/upload/`

**Description:** Upload a public image to the gallery bucket. **Public** endpoint.

**Auth Required:** No  
**Content-Type:** `multipart/form-data`

**Request Body (form-data):**
- `image` (file) — Required. Only PNG, JPG, or JPEG allowed. Max 10MB.

**Response (200 OK):**
```json
{
  "message": "Image uploaded successfully",
  "url": "https://cxmkjkviqnjslvdzpwjw.supabase.co/storage/v1/object/public/uploads/credit-applications/1234567890-abc123.png",
  "path": "credit-applications/1234567890-abc123.png"
}
```

**Response (400 Bad Request):**
```json
{
  "message": "No image file provided"
}
```

**Response (500 Internal Server Error):**
```json
{
  "message": "Failed to upload image",
  "error": "..."
}
```

---

#### `POST /api/upload/credit-document`

**Description:** Upload a document to the private `credit-documents` bucket. **Public** endpoint.

**Auth Required:** No  
**Content-Type:** `multipart/form-data`

**Request Body (form-data):**
- `image` (file) — Required. Only PNG, JPG, or JPEG allowed. Max 10MB.

**Response (200 OK):**
```json
{
  "message": "Document uploaded successfully",
  "path": "credit-applications/1234567890-abc123.png"
}
```

**Response (400 Bad Request):**
```json
{
  "message": "No document file provided"
}
```

---

### Gallery

#### `GET /api/gallery/`

**Description:** Get all gallery images. **Public** endpoint.

**Auth Required:** No

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "Sample Image",
      "description": "A nice photo",
      "imageUrl": "https://...supabase.../uploads/...",
      "storagePath": "credit-applications/1234567890-abc123.png",
      "createdAt": "2026-08-11T12:00:00.000Z",
      "updatedAt": "2026-08-11T12:00:00.000Z"
    }
  ]
}
```

---

#### `POST /api/gallery/`

**Description:** Add a new gallery image record (admin only). This saves metadata to the database. You must upload the image first via `POST /api/upload/` to get the `imageUrl` and `storagePath`.

**Auth Required:** Yes (`Bearer <token>`)

**Headers:**
```
Content-Type: application/json
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "title": "Sample Image",
  "description": "A nice photo",
  "imageUrl": "https://cxmkjkviqnjslvdzpwjw.supabase.co/storage/v1/object/public/uploads/credit-applications/1234567890-abc123.png",
  "storagePath": "credit-applications/1234567890-abc123.png"
}
```

**Field Details:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | No | Image title |
| `description` | string | No | Image description |
| `imageUrl` | string | **Yes** | Public URL of the image |
| `storagePath` | string | No | Storage path in Supabase bucket |

**Response (201 Created):**
```json
{
  "message": "Gallery image added successfully",
  "data": {
    "id": "uuid",
    "title": "Sample Image",
    "description": "A nice photo",
    "imageUrl": "https://...",
    "storagePath": "credit-applications/1234567890-abc123.png",
    "createdAt": "2026-08-11T12:00:00.000Z",
    "updatedAt": "2026-08-11T12:00:00.000Z"
  }
}
```

**Response (400 Bad Request):**
```json
{
  "message": "imageUrl is required"
}
```

---

#### `DELETE /api/gallery/:id`

**Description:** Delete a gallery image and its file from storage (admin only).

**Auth Required:** Yes (`Bearer <token>`)

**Response (200 OK):**
```json
{
  "message": "Gallery image deleted successfully"
}
```

**Response (404 Not Found):**
```json
{
  "message": "Gallery image not found"
}
```

---

## Response Codes

| Status Code | Meaning |
|-------------|---------|
| `200` | Success |
| `201` | Created |
| `400` | Bad Request — validation error or missing required fields |
| `401` | Unauthorized — missing or invalid Bearer token |
| `404` | Not Found — resource does not exist |
| `429` | Too Many Requests — rate limit exceeded |
| `500` | Internal Server Error |

---

## Quick Testing Order (Postman)

1. **Health Check** — `GET /health` (should return `status: OK`)
2. **Login** — `POST /api/auth/login` (save the `access_token` from response)
3. **Get Me** — `GET /api/auth/me` (use Bearer token)
4. **Submit Credit** — `POST /api/credits/` (public, no auth needed)
5. **Track Credit** — `GET /api/credits/track/:code` (use the trackingCode from step 4)
6. **List Credits** — `GET /api/credits/` (admin only, requires Bearer token)
7. **Upload Image** — `POST /api/upload/` (multipart/form-data)
8. **Create Gallery** — `POST /api/gallery/` (admin only, use image URL from step 7)
9. **List Gallery** — `GET /api/gallery/` (public)
10. **Exchange Rates** — `GET /api/currency/rates` (public)
