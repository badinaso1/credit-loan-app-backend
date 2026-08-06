import { Request, Response } from 'express';
import axios from 'axios';

const EXCHANGE_RATE_API = 'https://api.frankfurter.dev/v1';

export const getExchangeRates = async (req: Request, res: Response) => {
  try {
    const baseCurrency = (req.query.base as string) || 'USD';

    const response = await axios.get(`${EXCHANGE_RATE_API}/latest?from=${baseCurrency.toUpperCase()}`, {
      timeout: 10000
    });

    res.json({
      base: response.data.base,
      date: response.data.date,
      rates: response.data.rates
    });
  } catch (error) {
    console.error('Exchange rate fetch error:', error);
    res.status(500).json({ message: 'Failed to fetch exchange rates' });
  }
};

export const getSupportedCurrencies = async (req: Request, res: Response) => {
  try {
    const response = await axios.get(`${EXCHANGE_RATE_API}/latest?from=USD`, {
      timeout: 10000
    });

    const currencies = Object.keys(response.data.rates);

    res.json({
      currencies,
      count: currencies.length
    });
  } catch (error) {
    console.error('Currency list fetch error:', error);
    res.status(500).json({ message: 'Failed to fetch supported currencies' });
  }
};