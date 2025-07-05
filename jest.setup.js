// Global test setup
global.console = {
  ...console,
  log: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
  info: jest.fn(),
  debug: jest.fn(),
};

// Mock AWS SDK
jest.mock('aws-sdk', () => ({
  DynamoDB: {
    DocumentClient: jest.fn(() => ({
      scan: jest.fn(),
      query: jest.fn(),
      get: jest.fn(),
      put: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    })),
  },
  CloudWatch: jest.fn(() => ({
    putMetricData: jest.fn(),
  })),
}));

// Mock Date.now for consistent testing
const mockDate = new Date('2024-01-15T12:00:00Z');
jest.spyOn(global, 'Date').mockImplementation(() => mockDate as any);
Date.now = jest.fn(() => mockDate.getTime());