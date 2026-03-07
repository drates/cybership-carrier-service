import { describe, it, expect, beforeAll, afterEach, afterAll } from 'vitest';
import nock from 'nock';
import { CarrierService } from '../../src/application/CarrierService';
import { CarrierFactory } from '../../src/infrastructure/carriers/CarrierFactory';
import { RateRequest } from '../../src/domain/types';
import { env } from '../../src/infrastructure/config/env';
import { upsAuthSuccessPayload, upsRateSuccessPayload, upsApiErrorPayload, upsRefreshedAuthSuccessPayload } from '../stubs/ups.payloads';
import { TokenStore } from '../../src/infrastructure/auth/UPSAuthenticator';
import { AuthenticationError, ProviderError } from '../../src/infrastructure/errors/ApplicationError';

const carrierFactory = new CarrierFactory();
const carrierService = new CarrierService(carrierFactory);

const mockRateRequest: RateRequest = {
  origin: { street1: '123 Main St', city: 'Beverly Hills', state: 'CA', postalCode: '90210', country: 'US' },
  destination: { street1: '456 Park Ave', city: 'New York', state: 'NY', postalCode: '10022', country: 'US' },
  packages: [{ weight: 2, length: 10, width: 10, height: 10 }],
};

describe('CarrierService Integration Tests', () => {
  const apiScope = nock(env.UPS_BASE_URL);

  beforeAll(() => {
    nock.disableNetConnect(); 
  });

  afterEach(() => {
    // Clear the singleton token store to ensure test isolation.
    TokenStore.getInstance().clear();
    nock.cleanAll(); 
  });

  afterAll(() => {
    nock.enableNetConnect();
  });

  it('should fetch, parse, and normalize rates for a successful request', async () => {
    apiScope.post('/security/v1/oauth/token').reply(200, upsAuthSuccessPayload);
    apiScope.post('/rating/v2205/Rate').reply(200, upsRateSuccessPayload);

    const rates = await carrierService.getRatesForCarrier('ups', mockRateRequest);

    expect(rates).toHaveLength(2);
    expect(rates[0].carrier).toBe('ups');
    expect(rates[0].serviceLevel.name).toBe('UPS Ground');
    expect(rates[0].totalCost.amount).toBe(2550); 
    expect(rates[0].totalCost.currency).toBe('USD');
    expect(rates[1].serviceLevel.name).toBe('UPS Next Day Air');
    expect(rates[1].totalCost.amount).toBe(7815); 
  });

  it('should handle the full auth token lifecycle: acquire, reuse, and transparently refresh', async () => {
    const authNock = apiScope.post('/security/v1/oauth/token').reply(200, upsAuthSuccessPayload);
    const rateNock1 = apiScope.post('/rating/v2205/Rate').reply(200, upsRateSuccessPayload);

    await carrierService.getRatesForCarrier('ups', mockRateRequest);
    expect(authNock.isDone()).toBe(true); 
    expect(rateNock1.isDone()).toBe(true);

    const rateNock2 = apiScope.post('/rating/v2205/Rate').reply(200, upsRateSuccessPayload);
    
    await carrierService.getRatesForCarrier('ups', mockRateRequest);
    expect(authNock.isDone()).toBe(true); 
    expect(rateNock2.isDone()).toBe(true);

    const rateNock3_fail = apiScope.post('/rating/v2205/Rate').reply(401, { error: 'invalid_token' });
    const refreshAuthNock = apiScope.post('/security/v1/oauth/token').reply(200, upsRefreshedAuthSuccessPayload);
    const rateNock4_retry = apiScope.post('/rating/v2205/Rate').reply(200, upsRateSuccessPayload);

    const rates = await carrierService.getRatesForCarrier('ups', mockRateRequest);
    
    expect(rateNock3_fail.isDone()).toBe(true);
    expect(refreshAuthNock.isDone()).toBe(true);
    expect(rateNock4_retry.isDone()).toBe(true);
    expect(rates).toHaveLength(2);
  });

  it('should throw a structured ProviderError for a 4xx/5xx API failure', async () => {
    apiScope.post('/security/v1/oauth/token').reply(200, upsAuthSuccessPayload);
    apiScope.post('/rating/v2205/Rate').reply(400, upsApiErrorPayload);

    // ACT & ASSERT
    await expect(carrierService.getRatesForCarrier('ups', mockRateRequest)).rejects.toSatisfy((e) => {
      const err = e as ProviderError;
      expect(err).toBeInstanceOf(ProviderError);
      expect(err.statusCode).toBe(400);
      expect(err.message).toContain('UPS API Error');
      expect(err.context?.data).toEqual(upsApiErrorPayload);
      return true;
    });
  });

  it('should throw an AuthenticationError if the token refresh fails', async () => {
    apiScope.post('/security/v1/oauth/token').reply(401, { error: 'invalid_client' });

    await expect(carrierService.getRatesForCarrier('ups', mockRateRequest))
      .rejects.toThrow(AuthenticationError);
  });
});
