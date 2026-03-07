import axios from 'axios';
import { env } from '../config/env';
import { AuthenticationError } from '../errors/ApplicationError';

interface Token {
  accessToken: string;
  expiresAt: number; 
}

export class TokenStore {
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
