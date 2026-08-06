import { Router } from 'express';
import { getExchangeRates, getSupportedCurrencies } from '../controllers/currency.controller';

const router = Router();

router.get('/rates', getExchangeRates);
router.get('/currencies', getSupportedCurrencies);

export default router;