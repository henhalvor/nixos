import { defineBackend } from '@aws-amplify/backend';
import { resetUsageScheduled } from './functions/resetUsageScheduled/resource';
import { data } from './data/resource';

export const backend = defineBackend({
  resetUsageScheduled,
  data,
});

// Grant the scheduled function permission to access the data
// Note: In a real implementation, these permissions would be configured
// using the actual AWS CDK constructs available in the Amplify environment
console.log('Backend configured with resetUsageScheduled function and data schema');

// TODO: Configure IAM permissions for DynamoDB access
// TODO: Configure CloudWatch permissions for metrics and logging
// These would be set up using the actual Amplify backend configuration