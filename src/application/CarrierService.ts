import { RateRequest, RateQuote } from '../domain/types';
import { CarrierFactory } from '../infrastructure/carriers/CarrierFactory';
import { ApplicationError, NotFoundError } from '../infrastructure/errors/ApplicationError';

export class CarrierService {
  constructor(private readonly carrierFactory: CarrierFactory) {}

  public async getRatesForCarrier(
    carrierCode: string,
    request: RateRequest
  ): Promise<RateQuote[]> {
    try {
      const carrier = this.carrierFactory.getCarrier(carrierCode);
      if (!carrier) {
        throw new NotFoundError(`Carrier with code '${carrierCode}' not found.`);
      }

      const rates = await carrier.fetchRates(request);
      return rates;
    } catch (error) {
      if (error instanceof ApplicationError) {
        throw error;
      }
      throw new ApplicationError('An unexpected error occurred while fetching rates.', {
        cause: error,
      });
    }
  }
}
