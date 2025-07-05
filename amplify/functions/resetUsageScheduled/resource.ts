import { defineFunction } from '@aws-amplify/backend';

export const resetUsageScheduled = defineFunction({
  name: 'resetUsageScheduled',
  entry: './handler.ts',
  schedule: 'rate(1 day)', // Run daily
  environment: {
    // Add necessary environment variables for DynamoDB access
    NODE_ENV: 'production',
    AWS_REGION: 'us-east-1',
  },
  runtime: 20,
  timeoutSeconds: 300, // 5 minutes timeout for batch processing
  memoryMB: 512,
});