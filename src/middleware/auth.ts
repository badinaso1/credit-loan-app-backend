import { Request, Response, NextFunction } from 'express';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

let supabaseAuthInstance: SupabaseClient | null = null;

export function getSupabaseAuth(): SupabaseClient {
  if (!supabaseAuthInstance) {
    const supabaseUrl = process.env.SUPABASE_URL || '';
    const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || '';
    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error(
        'Missing Supabase credentials. Please set SUPABASE_URL and SUPABASE_ANON_KEY in your .env file.'
      );
    }
    supabaseAuthInstance = createClient(supabaseUrl, supabaseAnonKey);
  }
  return supabaseAuthInstance;
}

export const requireAuth = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'Unauthorized: No token provided' });
    }

    const token = authHeader.split(' ')[1];
    
    const { data: { user }, error } = await getSupabaseAuth().auth.getUser(token);
    
    if (error || !user) {
      return res.status(401).json({ message: 'Unauthorized: Invalid token' });
    }

    // Attach user to request
    (req as any).user = user;
    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    return res.status(401).json({ message: 'Unauthorized' });
  }
};
