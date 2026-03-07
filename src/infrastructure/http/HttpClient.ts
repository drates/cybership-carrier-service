import axios, { AxiosError, AxiosInstance, InternalAxiosRequestConfig } from 'axios';
import { UPSAuthenticator } from '../auth/UPSAuthenticator';
import { env } from '../config/env';
import { ApplicationError, ProviderError } from '../errors/ApplicationError';

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
    async (error: Error | AxiosError) => {
      // If an error was thrown from the request interceptor (like our AuthenticationError),
      // it won't be a standard AxiosError. In that case, we just re-throw it.
      if (!axios.isAxiosError(error)) {
        return Promise.reject(error);
      }

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
