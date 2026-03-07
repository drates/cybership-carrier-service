import { RateRequest, RateQuote } from '../types';

export interface ICarrier {
  readonly code: string;
  fetchRates(request: RateRequest): Promise<RateQuote[]>;
}
