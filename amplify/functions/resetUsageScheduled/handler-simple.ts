// Simple types for testing without external dependencies
interface ScheduledEvent {
  id: string;
  'detail-type': string;
  source: string;
  account: string;
  time: string;
  region: string;
  detail: Record<string, any>;
  version: string;
  resources: string[];
}

interface Context {
  callbackWaitsForEmptyEventLoop: boolean;
  functionName: string;
  functionVersion: string;
  invokedFunctionArn: string;
  memoryLimitInMB: string;
  awsRequestId: string;
  logGroupName: string;
  logStreamName: string;
  getRemainingTimeInMillis: () => number;
  done: () => void;
  fail: () => void;
  succeed: () => void;
}

interface UserProfile {
  id: string;
  username: string;
  email: string;
  usage: number;
  lastResetDate?: string;
  expiresAt?: string;
  createdAt: string;
  updatedAt: string;
}

interface ClientResponse<T> {
  data: T[];
  nextToken?: string;
}

interface MockClient {
  models: {
    UserProfile: {
      list: (params: { limit: number; nextToken?: string }) => Promise<ClientResponse<UserProfile>>;
      update: (params: { id: string; [key: string]: any }) => Promise<{ data: UserProfile }>;
    };
  };
}

// Mock client for testing/validation
const mockClient: MockClient = {
  models: {
    UserProfile: {
      list: async (params) => {
        // Mock implementation - in real scenario this would call DynamoDB
        console.log('Fetching user profiles with params:', params);
        return { data: [], nextToken: undefined };
      },
      update: async (params) => {
        // Mock implementation - in real scenario this would update DynamoDB
        console.log('Updating user profile:', params);
        return { data: { ...params } as UserProfile };
      },
    },
  },
};

// Configuration constants
const BATCH_SIZE = 100;
const FREE_TIER_RESET_INTERVAL_DAYS = 30;
const MAX_RETRIES = 3;

// Metrics tracking
interface ProcessingMetrics {
  totalUsersProcessed: number;
  successfulResets: number;
  failedResets: number;
  skippedUsers: number;
  subscriptionResets: number;
  freeTierResets: number;
}

export const handler = async (event: ScheduledEvent, context: Context): Promise<void> => {
  const startTime = Date.now();
  const metrics: ProcessingMetrics = {
    totalUsersProcessed: 0,
    successfulResets: 0,
    failedResets: 0,
    skippedUsers: 0,
    subscriptionResets: 0,
    freeTierResets: 0,
  };

  console.log('Starting scheduled usage reset process', {
    eventId: event.id,
    time: event.time,
    contextRequestId: context.awsRequestId,
  });

  try {
    await processUsageResets(metrics);
    
    const processingTime = Date.now() - startTime;
    
    console.log('Scheduled usage reset completed successfully', {
      metrics,
      processingTimeMs: processingTime,
      contextRequestId: context.awsRequestId,
    });
    
    // Send success metrics to CloudWatch
    await sendMetrics(metrics, processingTime);
    
  } catch (error) {
    console.error('Scheduled usage reset failed', {
      error: error instanceof Error ? error.message : 'Unknown error',
      stack: error instanceof Error ? error.stack : undefined,
      metrics,
      contextRequestId: context.awsRequestId,
    });
    
    // Send error metrics to CloudWatch
    await sendErrorMetrics(metrics, error);
    
    throw error;
  }
};

async function processUsageResets(metrics: ProcessingMetrics): Promise<void> {
  let nextToken: string | undefined;
  
  do {
    try {
      // Fetch batch of user profiles
      const response = await mockClient.models.UserProfile.list({
        limit: BATCH_SIZE,
        nextToken,
      });
      
      if (!response.data || response.data.length === 0) {
        console.log('No more users to process');
        break;
      }
      
      console.log(`Processing batch of ${response.data.length} users`);
      
      // Process each user in the batch
      for (const userProfile of response.data) {
        await processUserReset(userProfile, metrics);
      }
      
      nextToken = response.nextToken;
      
    } catch (error) {
      console.error('Error processing batch', {
        error: error instanceof Error ? error.message : 'Unknown error',
        nextToken,
      });
      
      // Continue processing next batch even if current batch fails
      nextToken = undefined;
    }
    
  } while (nextToken);
}

async function processUserReset(userProfile: UserProfile, metrics: ProcessingMetrics): Promise<void> {
  const userId = userProfile.id;
  const currentTime = new Date();
  
  metrics.totalUsersProcessed++;
  
  try {
    // Determine reset eligibility
    const resetInfo = determineResetEligibility(userProfile, currentTime);
    
    if (!resetInfo.shouldReset) {
      metrics.skippedUsers++;
      console.log(`Skipping user ${userId}: not eligible for reset`, {
        userId,
        reason: resetInfo.reason,
        nextResetDate: resetInfo.nextResetDate,
      });
      return;
    }
    
    // Perform the reset with retry logic
    await performUserResetWithRetry(userProfile, resetInfo, metrics);
    
  } catch (error) {
    metrics.failedResets++;
    console.error(`Failed to process user ${userId}`, {
      userId,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

interface ResetInfo {
  shouldReset: boolean;
  resetType: 'subscription' | 'freeTier' | 'none';
  reason?: string;
  nextResetDate?: Date;
}

function determineResetEligibility(userProfile: UserProfile, currentTime: Date): ResetInfo {
  const userId = userProfile.id;
  const lastResetDate = userProfile.lastResetDate ? new Date(userProfile.lastResetDate) : null;
  const createdAt = new Date(userProfile.createdAt);
  const expiresAt = userProfile.expiresAt ? new Date(userProfile.expiresAt) : null;
  
  // Check for subscription reset
  if (expiresAt && expiresAt <= currentTime) {
    // User has a subscription that has expired
    return {
      shouldReset: true,
      resetType: 'subscription',
      reason: 'Subscription expired',
    };
  }
  
  // Check for free tier reset
  if (!expiresAt || expiresAt < currentTime) {
    // User is on free tier, check monthly reset
    const nextResetDate = calculateNextFreeTierResetDate(createdAt, lastResetDate);
    
    if (nextResetDate <= currentTime) {
      return {
        shouldReset: true,
        resetType: 'freeTier',
        reason: 'Monthly free tier reset due',
        nextResetDate,
      };
    } else {
      return {
        shouldReset: false,
        resetType: 'none',
        reason: 'Free tier reset not due yet',
        nextResetDate,
      };
    }
  }
  
  // Subscription still active
  return {
    shouldReset: false,
    resetType: 'none',
    reason: 'Subscription still active',
  };
}

function calculateNextFreeTierResetDate(createdAt: Date, lastResetDate: Date | null): Date {
  const baseDate = lastResetDate || createdAt;
  const nextReset = new Date(baseDate.getTime());
  
  // Add 30 days to the base date
  nextReset.setDate(nextReset.getDate() + FREE_TIER_RESET_INTERVAL_DAYS);
  
  return nextReset;
}

async function performUserResetWithRetry(
  userProfile: UserProfile,
  resetInfo: ResetInfo,
  metrics: ProcessingMetrics,
  retryCount: number = 0
): Promise<void> {
  const userId = userProfile.id;
  
  try {
    // Reset usage fields
    const resetData = {
      usage: 0,
      lastResetDate: new Date().toISOString(),
      // Keep other fields unchanged
    };
    
    // Update user profile
    await mockClient.models.UserProfile.update({
      id: userId,
      ...resetData,
    });
    
    metrics.successfulResets++;
    
    if (resetInfo.resetType === 'subscription') {
      metrics.subscriptionResets++;
    } else if (resetInfo.resetType === 'freeTier') {
      metrics.freeTierResets++;
    }
    
    console.log(`Successfully reset usage for user ${userId}`, {
      userId,
      resetType: resetInfo.resetType,
      previousUsage: userProfile.usage,
      resetDate: resetData.lastResetDate,
    });
    
  } catch (error) {
    if (retryCount < MAX_RETRIES) {
      console.warn(`Retrying reset for user ${userId} (attempt ${retryCount + 1}/${MAX_RETRIES})`, {
        userId,
        error: error instanceof Error ? error.message : 'Unknown error',
      });
      
      // Exponential backoff
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount) * 1000));
      
      return performUserResetWithRetry(userProfile, resetInfo, metrics, retryCount + 1);
    }
    
    throw error;
  }
}

async function sendMetrics(metrics: ProcessingMetrics, processingTimeMs: number): Promise<void> {
  try {
    // In a real implementation, you would send these metrics to CloudWatch
    console.log('Sending metrics to CloudWatch', {
      metrics,
      processingTimeMs,
    });
    
  } catch (error) {
    console.error('Failed to send metrics', {
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

async function sendErrorMetrics(metrics: ProcessingMetrics, error: unknown): Promise<void> {
  try {
    // In a real implementation, you would send error metrics and potentially alerts
    console.log('Sending error metrics and alerts', {
      metrics,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
    
    // Calculate failure rate
    const failureRate = metrics.totalUsersProcessed > 0 
      ? (metrics.failedResets / metrics.totalUsersProcessed) * 100 
      : 0;
    
    // Send alert if failure rate is high
    if (failureRate > 10) {
      console.error('High failure rate detected', {
        failureRate: `${failureRate.toFixed(2)}%`,
        metrics,
      });
    }
    
  } catch (alertError) {
    console.error('Failed to send error metrics', {
      error: alertError instanceof Error ? alertError.message : 'Unknown error',
    });
  }
}