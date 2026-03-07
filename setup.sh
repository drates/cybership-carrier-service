#!/bin/bash

# 1. Create Directory Structure
echo "Creating directory structure..."
mkdir -p src/application
mkdir -p src/domain/ports
mkdir -p src/infrastructure/auth
mkdir -p src/infrastructure/carriers/ups
mkdir -p src/infrastructure/config
mkdir -p src/infrastructure/errors
mkdir -p src/infrastructure/http
mkdir -p tests/integration
mkdir -p tests/stubs

# 2. Create Configuration Files

echo "Creating package.json..."
cat << 'EOF' > package.json
{
  "name": "cybership-carrier-service",
  "version": "1.0.0",
  "description": "A carrier integration service for Cybership.",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "keywords": [
    "typescript",
    "hexagonal-architecture",
    "shipping"
  ],
  "author": "Your Name",
  "license": "ISC",
  "devDependencies": {
    "@types/node": "^20.11.24",
    "nock": "^13.5.4",
    "typescript": "^5.3.3",
    "vitest": "^1.3.1"
  },
  "dependencies": {
    "axios": "^1.6.7",
    "zod": "^3.22.4"
  }
}
EOF

echo "Creating tsconfig.json..."
cat << 'EOF' > tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "baseUrl": "./src",
    "outDir": "./dist",
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "sourceMap": true,
    "declaration": true
  },
  "include": ["src/**/*", "tests/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

echo "Creating .env.example..."
cat << 'EOF' > .env.example
# The environment your application is running in (e.g., 'development', 'production', 'test')
NODE_ENV=development

# UPS API Configuration
# Base URL for the UPS API endpoints
UPS_BASE_URL=https://wwwcie.ups.com/api

# UPS OAuth 2.0 Client Credentials
UPS_CLIENT_ID="your_ups_client_id"
UPS_CLIENT_SECRET="your_ups_client_secret"
EOF

# 3. Create Source Code Files

echo "Creating src/domain/types.ts..."
cat << 'EOF' > src/domain/types.ts
export type RateId = string & { readonly __brand: 'RateId' };
export type ShipmentId = string & { readonly __brand: 'ShipmentId' };

export interface Address {
  street1: string;
  street2?: string;
  city: string;
  state: string;
  postalCode: string;
  country: string; 
}

export interface Package {
  weight: number; 
  length: number; 
  width: number; 
  height: number; 
}

export interface Money {
  amount: number; 
  currency: string; 
}

export interface RateRequest {
  origin: Address;
  destination: Address;
  packages: Package[];
}

export interface RateQuote {
  id: RateId;
  carrier: string; 
  serviceLevel: {
    name: string; 
    token: string; 
  };
  totalCost: Money;
  estimatedDelivery: Date | null;
}
EOF

echo "Creating src/domain/ports/ICarrier.ts..."
cat << 'EOF' > src/domain/ports/ICarrier.ts
import { RateRequest, RateQuote } from '../types';

export interface ICarrier {
  readonly code: string;
  fetchRates(request: RateRequest): Promise<RateQuote[]>;
}
EOF

echo "Creating src/application/CarrierService.ts..."
cat << 'EOF' > src/application/CarrierService.ts
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
EOF

echo "Creating src/infrastructure/config/env.ts..."
cat << 'EOF' > src/infrastructure/config/env.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  UPS_BASE_URL: z.string().url(),
  UPS_CLIENT_ID: z.string().min(1),
  UPS_CLIENT_SECRET: z.string().min(1),
});

const parsedEnv = envSchema.safeParse(process.env);

if (!parsedEnv.success) {
  console.error(
    '❌ Invalid environment variables:',
    parsedEnv.error.flatten().fieldErrors
  );
  throw new Error('Invalid environment variables.');
}

export const env = Object.freeze(parsedEnv.data);
EOF

echo "Creating src/infrastructure/errors/ApplicationError.ts..."
cat << 'EOF' > src/infrastructure/errors/ApplicationError.ts
export class ApplicationError extends Error {
  public readonly context?: Record<string, unknown>;
  public readonly cause?: unknown;

  constructor(message: string, options?: { context?: Record<string, unknown>, cause?: unknown }) {
    super(message);
    this.name = this.constructor.name;
    this.context = options?.context;
    this.cause = options?.cause;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ProviderError extends ApplicationError {
  constructor(message: string, public readonly statusCode: number, options?: { context?: Record<string, unknown>, cause?: unknown }) {
    super(message, options);
  }
}

export class AuthenticationError extends ApplicationError {}
export class ValidationError extends ApplicationError {}
export class NotFoundError extends ApplicationError {}
EOF

echo "Creating src/infrastructure/auth/UPSAuthenticator.ts..."
cat << 'EOF' > src/infrastructure/auth/UPSAuthenticator.ts
import axios from 'axios';
import { env } from '../config/env';
import { AuthenticationError } from '../errors/ApplicationError';

interface Token {
  accessToken: string;
  expiresAt: number; 
}

class TokenStore {
  private static instance: TokenStore;
  private token: Token | null = null;

  private constructor() {}

  public static getInstance(): TokenStore {
    if (!TokenStore.instance) {
      TokenStore.instance = new TokenStore();
    }
    return TokenStore.instance;
  }

  public get(): Token | null {
    if (this.token && this.token.expiresAt > Date.now()) {
      return this.token;
    }
    return null; 
  }

  public set(accessToken: string, expiresIn: number): void {
    const bufferSeconds = 60;
    const expiresAt = Date.now() + (expiresIn - bufferSeconds) * 1000;
    this.token = { accessToken, expiresAt };
  }

  public clear(): void {
    this.token = null;
  }
}

export class UPSAuthenticator {
  private tokenStore = TokenStore.getInstance();
  private isRefreshing = false;
  private refreshSubscribers: ((token: string) => void)[] = [];

  public async getToken(): Promise<string> {
    const cachedToken = this.tokenStore.get();
    if (cachedToken) {
      return cachedToken.accessToken;
    }

    if (this.isRefreshing) {
      return new Promise((resolve) => {
        this.refreshSubscribers.push(resolve);
      });
    }

    return this.refreshToken();
  }

  public async refreshToken(): Promise<string> {
    this.isRefreshing = true;
    this.tokenStore.clear();

    try {
      console.log('Authenticating with UPS...');
      const response = await axios.post(
        `${env.UPS_BASE_URL}/security/v1/oauth/token`,
        'grant_type=client_credentials',
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': `Basic ${Buffer.from(`${env.UPS_CLIENT_ID}:${env.UPS_CLIENT_SECRET}`).toString('base64')}`,
          },
        }
      );

      const { access_token, expires_in } = response.data;
      if (!access_token || !expires_in) {
        throw new Error('Invalid token response from UPS');
      }

      this.tokenStore.set(access_token, expires_in);
      console.log('Successfully authenticated with UPS.');

      this.refreshSubscribers.forEach(callback => callback(access_token));
      
      return access_token;
    } catch (error) {
      const message = 'Failed to authenticate with UPS API.';
      console.error(message, error);
      throw new AuthenticationError(message, { cause: error });
    } finally {
      this.isRefreshing = false;
      this.refreshSubscribers = [];
    }
  }
}
EOF

echo "Creating src/infrastructure/http/HttpClient.ts..."
cat << 'EOF' > src/infrastructure/http/HttpClient.ts
import axios, { AxiosError, AxiosInstance, InternalAxiosRequestConfig } from 'axios';
import { UPSAuthenticator } from '../auth/UPSAuthenticator';
import { env } from '../config/env';
import { ProviderError } from '../errors/ApplicationError';

const authenticator = new UPSAuthenticator();

export function createHttpClient(): AxiosInstance {
  const client = axios.create({
    baseURL: env.UPS_BASE_URL,
    timeout: 10000, 
    headers: {
      'Content-Type': 'application/json',
      'transId': crypto.randomUUID(), 
      'transactionSrc': 'cybership-testing'
    }
  });

  client.interceptors.request.use(
    async (config: InternalAxiosRequestConfig) => {
      if (config.url?.includes('oauth/token')) {
        return config;
      }
      const token = await authenticator.getToken();
      config.headers.Authorization = `Bearer ${token}`;
      return config;
    },
    (error) => Promise.reject(error)
  );

  client.interceptors.response.use(
    (response) => response,
    async (error: AxiosError) => {
      const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

      if (error.response?.status !== 401 || originalRequest._retry) {
        const providerError = new ProviderError(
          `UPS API Error: ${error.response?.statusText || 'Unknown Error'}`,
          error.response?.status || 500,
          { context: { data: error.response?.data }, cause: error }
        );
        return Promise.reject(providerError);
      }

      originalRequest._retry = true; 

      try {
        console.log('Token expired or invalid. Refreshing...');
        const newToken = await authenticator.refreshToken();
        if (originalRequest.headers) {
          originalRequest.headers.Authorization = `Bearer ${newToken}`;
        }
        return client(originalRequest);
      } catch (refreshError) {
        return Promise.reject(refreshError);
      }
    }
  );

  return client;
}
EOF

echo "Creating src/infrastructure/carriers/ups/UPSSchemas.ts..."
cat << 'EOF' > src/infrastructure/carriers/ups/UPSSchemas.ts
import { z } from 'zod';

export const upsRateResponseSchema = z.object({
  RateResponse: z.object({
    RatedShipment: z.array(
      z.object({
        Service: z.object({
          Code: z.string(),
          Description: z.string(),
        }),
        RatedShipmentWarning: z.string().optional(),
        TotalCharges: z.object({
          CurrencyCode: z.string(),
          MonetaryValue: z.string(),
        }),
        GuaranteedDelivery: z
          .object({
            BusinessDaysInTransit: z.string(),
            DeliveryByTime: z.string().optional(),
          })
          .optional(),
        RatedPackage: z.object({
          TotalCharges: z.object({
            CurrencyCode: z.string(),
            MonetaryValue: z.string(),
          }),
        }),
      })
    ),
  }),
});

export type UPSRateResponse = z.infer<typeof upsRateResponseSchema>;
EOF

echo "Creating src/infrastructure/carriers/ups/UPSMapper.ts..."
cat << 'EOF' > src/infrastructure/carriers/ups/UPSMapper.ts
import { RateRequest, RateQuote, RateId, Money } from '../../../domain/types';
import { UPSRateResponse } from './UPSSchemas';

export class UPSMapper {
  public static toUpsRateRequest(request: RateRequest): object {
    return {
      RateRequest: {
        Request: {
          TransactionReference: {
            CustomerContext: 'Cybership Rate Request',
          },
        },
        Shipment: {
          Shipper: {
            Name: 'Cybership',
            Address: {
              AddressLine: [request.origin.street1],
              City: request.origin.city,
              StateProvinceCode: request.origin.state,
              PostalCode: request.origin.postalCode,
              CountryCode: request.origin.country,
            },
          },
          ShipTo: {
            Name: 'Recipient',
            Address: {
              AddressLine: [request.destination.street1],
              City: request.destination.city,
              StateProvinceCode: request.destination.state,
              PostalCode: request.destination.postalCode,
              CountryCode: request.destination.country,
            },
          },
          ShipFrom: {
            Name: 'Shipper',
            Address: {
              AddressLine: [request.origin.street1],
              City: request.origin.city,
              StateProvinceCode: request.origin.state,
              PostalCode: request.origin.postalCode,
              CountryCode: request.origin.country,
            },
          },
          Service: {
          },
          Package: request.packages.map((pkg) => ({
            PackagingType: {
              Code: '02', 
              Description: 'Package',
            },
            Dimensions: {
              UnitOfMeasurement: { Code: 'CM' }, 
              Length: String(pkg.length),
              Width: String(pkg.width),
              Height: String(pkg.height),
            },
            PackageWeight: {
              UnitOfMeasurement: { Code: 'KGS' }, 
              Weight: String(pkg.weight),
            },
          })),
        },
      },
    };
  }

  public static toDomainRateQuotes(response: UPSRateResponse): RateQuote[] {
    const ratedShipments = response.RateResponse.RatedShipment;

    return ratedShipments.map((shipment): RateQuote => {
      const totalCost: Money = {
        amount: Math.round(parseFloat(shipment.TotalCharges.MonetaryValue) * 100),
        currency: shipment.TotalCharges.CurrencyCode,
      };

      const estimatedDelivery = shipment.GuaranteedDelivery?.BusinessDaysInTransit
        ? new Date(Date.now() + parseInt(shipment.GuaranteedDelivery.BusinessDaysInTransit) * 24 * 60 * 60 * 1000)
        : null;

      return {
        id: `ups-${shipment.Service.Code}-${crypto.randomUUID()}` as RateId,
        carrier: 'ups',
        serviceLevel: {
          name: shipment.Service.Description,
          token: shipment.Service.Code,
        },
        totalCost,
        estimatedDelivery,
      };
    });
  }
}
EOF

echo "Creating src/infrastructure/carriers/ups/UPSAdapter.ts..."
cat << 'EOF' > src/infrastructure/carriers/ups/UPSAdapter.ts
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
EOF

echo "Creating src/infrastructure/carriers/CarrierFactory.ts..."
cat << 'EOF' > src/infrastructure/carriers/CarrierFactory.ts
import { ICarrier } from '../../domain/ports/ICarrier';
import { UPSAdapter } from './ups/UPSAdapter';

export class CarrierFactory {
  private readonly carriers: Map<string, ICarrier>;

  constructor() {
    this.carriers = new Map();
    const upsAdapter = new UPSAdapter();
    this.carriers.set(upsAdapter.code, upsAdapter);
  }

  public getCarrier(code: string): ICarrier | undefined {
    return this.carriers.get(code);
  }
}
EOF

echo "Creating tests/stubs/ups.payloads.ts..."
cat << 'EOF' > tests/stubs/ups.payloads.ts
export const upsAuthSuccessPayload = {
  token_type: 'Bearer',
  issued_at: '1678886400000',
  client_id: 'your_ups_client_id',
  access_token: 'stubbed_access_token_string',
  scope: 'oob',
  expires_in: '3599', 
  refresh_count: '0',
  status: 'approved',
};

export const upsRefreshedAuthSuccessPayload = {
    ...upsAuthSuccessPayload,
    access_token: 'refreshed_access_token_string',
};

export const upsRateSuccessPayload = {
  RateResponse: {
    RatedShipment: [
      {
        Service: { Code: '03', Description: 'UPS Ground' },
        TotalCharges: { CurrencyCode: 'USD', MonetaryValue: '25.50' },
        GuaranteedDelivery: { BusinessDaysInTransit: '3' },
        RatedPackage: { TotalCharges: { CurrencyCode: 'USD', MonetaryValue: '25.50' } },
      },
      {
        Service: { Code: '01', Description: 'UPS Next Day Air' },
        TotalCharges: { CurrencyCode: 'USD', MonetaryValue: '78.15' },
        GuaranteedDelivery: { BusinessDaysInTransit: '1', DeliveryByTime: '10:30 AM' },
        RatedPackage: { TotalCharges: { CurrencyCode: 'USD', MonetaryValue: '78.15' } },
      },
    ],
  },
};

export const upsApiErrorPayload = {
  response: {
    errors: [
      {
        code: '250003',
        message: 'Invalid or missing shipper number.',
      },
    ],
  },
};
EOF

echo "Creating tests/integration/carrier.test.ts..."
cat << 'EOF' > tests/integration/carrier.test.ts
import { describe, it, expect, beforeAll, afterEach, afterAll } from 'vitest';
import nock from 'nock';
import { CarrierService } from '../../src/application/CarrierService';
import { CarrierFactory } from '../../src/infrastructure/carriers/CarrierFactory';
import { RateRequest } from '../../src/domain/types';
import { env } from '../../src/infrastructure/config/env';
import { upsAuthSuccessPayload, upsRateSuccessPayload, upsApiErrorPayload, upsRefreshedAuthSuccessPayload } from '../stubs/ups.payloads';
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

    await expect(carrierService.getRatesForCarrier('ups', mockRateRequest))
      .rejects.toThrow(ProviderError);
    
    try {
      await carrierService.getRatesForCarrier('ups', mockRateRequest);
    } catch (e) {
      const err = e as ProviderError;
      expect(err.statusCode).toBe(400);
      expect(err.message).toContain('UPS API Error');
      expect(err.context?.data).toEqual(upsApiErrorPayload);
    }
  });

  it('should throw an AuthenticationError if the token refresh fails', async () => {
    apiScope.post('/security/v1/oauth/token').reply(401, { error: 'invalid_client' });

    await expect(carrierService.getRatesForCarrier('ups', mockRateRequest))
      .rejects.toThrow(AuthenticationError);
  });
});
EOF

echo "Creating README.md..."
cat << 'EOF' > README.md
# Cybership - Carrier Integration Service

This project is a backend service built in TypeScript that provides a unified interface for fetching shipping rates from various carriers. It is designed with a highly extensible and maintainable Hexagonal Architecture.

## Setup

1.  Install dependencies:
    \`\`\`bash
    npm install
    \`\`\`

2.  Set up environment variables:
    \`\`\`bash
    cp .env.example .env
    \`\`\`

3.  Run tests:
    \`\`\`bash
    npm test
    \`\`\`
EOF

echo "Setup complete! Run 'npm install' to get started."
