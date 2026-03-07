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
