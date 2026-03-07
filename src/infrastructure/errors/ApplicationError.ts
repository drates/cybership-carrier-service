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
