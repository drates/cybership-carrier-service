import axios, { AxiosError, AxiosInstance, InternalAxiosRequestConfig } from 'axios';
import { UPSAuthenticator } from '../auth/UPSAuthenticator';
import { env } from '../config/env';
import { ApplicationError, ProviderError } from '../errors/ApplicationError';
import { Logger } from '../telemetry/Logger';

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
      // Traceability: Initialize metadata to measure request latency for observability
      (config as any).metadata = { startTime: Date.now() };
      Logger.info(`Outgoing HTTP request`, {
        url: config.url,
        method: config.method?.toUpperCase()
      });

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
    (response) => {
      // Performance Monitoring: Log latency for SLA tracking
      const duration = Date.now() - (response.config as any).metadata.startTime;
      Logger.info(`HTTP request successful`, {
        url: response.config.url,
        status: response.status,
        durationMs: duration
      });
      return response;
    },
    async (error: Error | AxiosError) => {
      // Use a type guard or optional chaining with a check to safely access config
      const axiosError = axios.isAxiosError(error) ? error : null;
      const duration = axiosError?.config
        ? Date.now() - (axiosError.config as any).metadata.startTime
        : 0;

      if (!axiosError) {
        Logger.error(`Unexpected HTTP client error`, error, { durationMs: duration });
        return Promise.reject(error);
      }

      const originalRequest = axiosError.config as InternalAxiosRequestConfig & { _retry?: boolean };

      if (axiosError.response?.status !== 401 || originalRequest._retry) {
        const providerError = new ProviderError(
          `UPS API Error: ${axiosError.response?.statusText || 'Unknown Error'}`,
          axiosError.response?.status || 500,
          { context: { data: axiosError.response?.data }, cause: axiosError }
        );
        // Error Observability: Log failure with full error context for post-mortem analysis
        Logger.error(`External provider request failed`, providerError, {
          url: axiosError.config?.url,
          durationMs: duration
        });
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

