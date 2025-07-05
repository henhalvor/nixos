#!/usr/bin/env node

// Simple test runner for the usage reset logic without external dependencies
import { handler } from './handler-standalone';

// Mock AWS Lambda event and context
const mockEvent = {
  id: 'test-event-id',
  'detail-type': 'Scheduled Event',
  source: 'aws.events',
  account: '123456789012',
  time: new Date().toISOString(),
  region: 'us-east-1',
  detail: {},
  version: '0',
  resources: ['arn:aws:events:us-east-1:123456789012:rule/test-rule'],
};

const mockContext = {
  callbackWaitsForEmptyEventLoop: false,
  functionName: 'resetUsageScheduled',
  functionVersion: '$LATEST',
  invokedFunctionArn: 'arn:aws:lambda:us-east-1:123456789012:function:resetUsageScheduled',
  memoryLimitInMB: '512',
  awsRequestId: 'test-request-id',
  logGroupName: '/aws/lambda/resetUsageScheduled',
  logStreamName: 'test-stream',
  getRemainingTimeInMillis: () => 30000,
  done: () => {},
  fail: () => {},
  succeed: () => {},
};

console.log('Starting test of usage reset handler...');

async function runTest() {
  try {
    await handler(mockEvent, mockContext);
    console.log('✅ Test completed successfully');
  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

runTest();