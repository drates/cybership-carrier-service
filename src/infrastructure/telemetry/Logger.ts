export class Logger {
  static info(message: string, meta?: Record<string, any>) {
    console.log(JSON.stringify({
      level: 'INFO',
      timestamp: new Date().toISOString(),
      message,
      ...meta,
    }));
  }

  static error(message: string, error: any, meta?: Record<string, any>) {
    console.error(JSON.stringify({
      level: 'ERROR',
      timestamp: new Date().toISOString(),
      message,
      errorName: error?.name || 'UnknownError',
      errorMessage: error?.message || String(error),
      statusCode: error?.statusCode || error?.response?.status,
      context: error?.context || error?.response?.data,
      ...meta,
    }));
  }
}