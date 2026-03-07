import { AxiosInstance } from 'axios';
import { ICarrier } from '../../../domain/ports/ICarrier';
import { RateRequest, RateQuote } from '../../../domain/types';
import { createHttpClient } from '../../http/HttpClient';
import { UPSMapper } from './UPSMapper';
import { upsRateResponseSchema } from './UPSSchemas';
import { ValidationError } from '../../errors/ApplicationError';

export class UPSAdapter implements ICarrier {
  public readonly code = 'ups';
  private readonly httpClient: AxiosInstance;

  constructor() {
    this.httpClient = createHttpClient();
  }

  public async fetchRates(request: RateRequest): Promise<RateQuote[]> {
    const upsRequestPayload = UPSMapper.toUpsRateRequest(request);

    try {
      const response = await this.httpClient.post(
        '/rating/v2205/Rate',
        upsRequestPayload
      );

      const validationResult = upsRateResponseSchema.safeParse(response.data);
      if (!validationResult.success) {
        console.error('UPS response validation failed:', validationResult.error);
        throw new ValidationError('Received malformed response from UPS API.', {
          cause: validationResult.error,
        });
      }

      const rateQuotes = UPSMapper.toDomainRateQuotes(validationResult.data);
      return rateQuotes;
    } catch (error) {
      throw error;
    }
  }
}
