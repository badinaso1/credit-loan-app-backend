export interface CreditRequestInput {
  type: 'domestic' | 'international';
  fullName: string;
  voterId?: string;
  dateOfBirth?: string;
  age?: number;
  sex?: string;
  contactNumber: string;
  address?: string;
  profession?: string;
  loanAmount: number;
  interestRate?: number;
  loanTerm: string;
  guaranteeType?: string[];
  guaranteeConfirmed?: boolean;
  receiverName?: string;
  bankPlatform?: string;
  purpose?: string;
  photoUrl?: string;
  documentUrl?: string;
  bankStatementUrl?: string;
  status?: 'pending' | 'approved' | 'rejected';
}

export interface LoanSettingInput {
  interestRate: number;
}

export interface ApiResponse<T = any> {
  message: string;
  data?: T;
  error?: string;
}

export interface ExchangeRateResponse {
  base: string;
  date: string;
  rates: Record<string, number>;
}
