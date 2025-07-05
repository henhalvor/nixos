import { handler } from '../handler';
import { ScheduledEvent, Context } from 'aws-lambda';

// Mock AWS Amplify client
const mockClient = {
  models: {
    UserProfile: {
      list: jest.fn(),
      update: jest.fn(),
    },
  },
};

jest.mock('aws-amplify/data', () => ({
  generateClient: () => mockClient,
}));

describe('resetUsageScheduled handler', () => {
  const mockContext: Context = {
    callbackWaitsForEmptyEventLoop: false,
    functionName: 'resetUsageScheduled',
    functionVersion: '$LATEST',
    invokedFunctionArn: 'arn:aws:lambda:us-east-1:123456789012:function:resetUsageScheduled',
    memoryLimitInMB: '512',
    awsRequestId: 'test-request-id',
    logGroupName: '/aws/lambda/resetUsageScheduled',
    logStreamName: 'test-stream',
    getRemainingTimeInMillis: () => 30000,
    done: jest.fn(),
    fail: jest.fn(),
    succeed: jest.fn(),
  };

  const mockEvent: ScheduledEvent = {
    id: 'test-event-id',
    'detail-type': 'Scheduled Event',
    source: 'aws.events',
    account: '123456789012',
    time: '2024-01-01T00:00:00Z',
    region: 'us-east-1',
    detail: {},
    version: '0',
    resources: ['arn:aws:events:us-east-1:123456789012:rule/test-rule'],
  };

  beforeEach(() => {
    jest.clearAllMocks();
    console.log = jest.fn();
    console.error = jest.fn();
  });

  describe('subscription users', () => {
    it('should reset usage for users with expired subscriptions', async () => {
      const expiredUser = {
        id: 'user-1',
        username: 'testuser',
        email: 'test@example.com',
        usage: 50,
        lastResetDate: '2024-01-01T00:00:00Z',
        expiresAt: '2023-12-31T23:59:59Z', // Expired
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      };

      mockClient.models.UserProfile.list.mockResolvedValueOnce({
        data: [expiredUser],
        nextToken: null,
      });

      mockClient.models.UserProfile.update.mockResolvedValueOnce({
        data: { ...expiredUser, usage: 0 },
      });

      await handler(mockEvent, mockContext);

      expect(mockClient.models.UserProfile.update).toHaveBeenCalledWith({
        id: 'user-1',
        usage: 0,
        lastResetDate: expect.any(String),
      });
    });

    it('should not reset usage for users with active subscriptions', async () => {
      const activeUser = {
        id: 'user-2',
        username: 'activeuser',
        email: 'active@example.com',
        usage: 30,
        lastResetDate: '2024-01-01T00:00:00Z',
        expiresAt: '2024-12-31T23:59:59Z', // Active
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      };

      mockClient.models.UserProfile.list.mockResolvedValueOnce({
        data: [activeUser],
        nextToken: null,
      });

      await handler(mockEvent, mockContext);

      expect(mockClient.models.UserProfile.update).not.toHaveBeenCalled();
    });
  });

  describe('free tier users', () => {
    it('should reset usage for free tier users due for monthly reset', async () => {
      const freeTierUser = {
        id: 'user-3',
        username: 'freetier',
        email: 'free@example.com',
        usage: 25,
        lastResetDate: '2023-11-01T00:00:00Z', // 2 months ago
        expiresAt: null, // Free tier
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      };

      mockClient.models.UserProfile.list.mockResolvedValueOnce({
        data: [freeTierUser],
        nextToken: null,
      });

      mockClient.models.UserProfile.update.mockResolvedValueOnce({
        data: { ...freeTierUser, usage: 0 },
      });

      await handler(mockEvent, mockContext);

      expect(mockClient.models.UserProfile.update).toHaveBeenCalledWith({
        id: 'user-3',
        usage: 0,
        lastResetDate: expect.any(String),
      });
    });

    it('should not reset usage for free tier users not due for reset', async () => {
      const recentUser = {
        id: 'user-4',
        username: 'recentuser',
        email: 'recent@example.com',
        usage: 15,
        lastResetDate: new Date().toISOString(), // Just reset
        expiresAt: null, // Free tier
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      };

      mockClient.models.UserProfile.list.mockResolvedValueOnce({
        data: [recentUser],
        nextToken: null,
      });

      await handler(mockEvent, mockContext);

      expect(mockClient.models.UserProfile.update).not.toHaveBeenCalled();
    });
  });

  describe('batch processing', () => {
    it('should process multiple batches of users', async () => {
      const batch1 = Array.from({ length: 100 }, (_, i) => ({
        id: `user-${i}`,
        username: `user${i}`,
        email: `user${i}@example.com`,
        usage: 10,
        lastResetDate: '2023-01-01T00:00:00Z',
        expiresAt: null,
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      }));

      const batch2 = Array.from({ length: 50 }, (_, i) => ({
        id: `user-${i + 100}`,
        username: `user${i + 100}`,
        email: `user${i + 100}@example.com`,
        usage: 5,
        lastResetDate: '2023-01-01T00:00:00Z',
        expiresAt: null,
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      }));

      mockClient.models.UserProfile.list
        .mockResolvedValueOnce({
          data: batch1,
          nextToken: 'batch2-token',
        })
        .mockResolvedValueOnce({
          data: batch2,
          nextToken: null,
        });

      mockClient.models.UserProfile.update.mockResolvedValue({
        data: { usage: 0 },
      });

      await handler(mockEvent, mockContext);

      expect(mockClient.models.UserProfile.list).toHaveBeenCalledTimes(2);
      expect(mockClient.models.UserProfile.update).toHaveBeenCalledTimes(150);
    });
  });

  describe('error handling', () => {
    it('should handle individual user processing errors gracefully', async () => {
      const users = [
        {
          id: 'user-good',
          username: 'good',
          email: 'good@example.com',
          usage: 10,
          lastResetDate: '2023-01-01T00:00:00Z',
          expiresAt: null,
          createdAt: '2023-01-01T00:00:00Z',
          updatedAt: '2024-01-01T00:00:00Z',
        },
        {
          id: 'user-bad',
          username: 'bad',
          email: 'bad@example.com',
          usage: 20,
          lastResetDate: '2023-01-01T00:00:00Z',
          expiresAt: null,
          createdAt: '2023-01-01T00:00:00Z',
          updatedAt: '2024-01-01T00:00:00Z',
        },
      ];

      mockClient.models.UserProfile.list.mockResolvedValueOnce({
        data: users,
        nextToken: null,
      });

      mockClient.models.UserProfile.update
        .mockResolvedValueOnce({ data: { usage: 0 } }) // Success for first user
        .mockRejectedValueOnce(new Error('Update failed')); // Failure for second user

      await handler(mockEvent, mockContext);

      expect(mockClient.models.UserProfile.update).toHaveBeenCalledTimes(2);
      expect(console.error).toHaveBeenCalledWith(
        expect.stringContaining('Failed to process user user-bad'),
        expect.any(Object)
      );
    });

    it('should retry failed updates with exponential backoff', async () => {
      const user = {
        id: 'user-retry',
        username: 'retry',
        email: 'retry@example.com',
        usage: 10,
        lastResetDate: '2023-01-01T00:00:00Z',
        expiresAt: null,
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      };

      mockClient.models.UserProfile.list.mockResolvedValueOnce({
        data: [user],
        nextToken: null,
      });

      mockClient.models.UserProfile.update
        .mockRejectedValueOnce(new Error('Temporary failure'))
        .mockRejectedValueOnce(new Error('Temporary failure'))
        .mockResolvedValueOnce({ data: { usage: 0 } }); // Success on third try

      await handler(mockEvent, mockContext);

      expect(mockClient.models.UserProfile.update).toHaveBeenCalledTimes(3);
    });
  });
});