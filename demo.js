#!/usr/bin/env node

// Demo script to show the usage reset logic working with sample data
const { handler } = require('./dist/handler-simple.js');

// Mock sample user data for demonstration
const sampleUsers = [
  // Free tier user due for reset (created 35 days ago)
  {
    id: 'user-1',
    username: 'freetieruser',
    email: 'freetier@example.com',
    usage: 25,
    lastResetDate: new Date(Date.now() - 35 * 24 * 60 * 60 * 1000).toISOString(),
    expiresAt: null,
    createdAt: new Date(Date.now() - 60 * 24 * 60 * 60 * 1000).toISOString(),
    updatedAt: new Date().toISOString(),
  },
  // Subscription user with expired subscription
  {
    id: 'user-2',
    username: 'expireduser',
    email: 'expired@example.com',
    usage: 75,
    lastResetDate: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
    expiresAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString(), // Expired yesterday
    createdAt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
    updatedAt: new Date().toISOString(),
  },
  // Active subscription user (should not be reset)
  {
    id: 'user-3',
    username: 'activeuser',
    email: 'active@example.com',
    usage: 50,
    lastResetDate: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString(),
    expiresAt: new Date(Date.now() + 20 * 24 * 60 * 60 * 1000).toISOString(), // Expires in 20 days
    createdAt: new Date(Date.now() - 20 * 24 * 60 * 60 * 1000).toISOString(),
    updatedAt: new Date().toISOString(),
  },
  // Free tier user not due for reset (reset 5 days ago)
  {
    id: 'user-4',
    username: 'recentuser',
    email: 'recent@example.com',
    usage: 15,
    lastResetDate: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
    expiresAt: null,
    createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

// Override the mock client to return our sample data
const originalHandler = handler;
const mockClient = {
  models: {
    UserProfile: {
      list: async (params) => {
        console.log('📋 Fetching user profiles for processing...');
        return { 
          data: sampleUsers, 
          nextToken: undefined 
        };
      },
      update: async (params) => {
        console.log('✨ Updating user profile:', {
          id: params.id,
          newUsage: params.usage,
          resetDate: params.lastResetDate,
        });
        return { data: { ...params } };
      },
    },
  },
};

// Mock event and context
const mockEvent = {
  id: 'demo-event-id',
  'detail-type': 'Scheduled Event',
  source: 'aws.events',
  account: '123456789012',
  time: new Date().toISOString(),
  region: 'us-east-1',
  detail: {},
  version: '0',
  resources: ['arn:aws:events:us-east-1:123456789012:rule/demo-rule'],
};

const mockContext = {
  callbackWaitsForEmptyEventLoop: false,
  functionName: 'resetUsageScheduled',
  functionVersion: '$LATEST',
  invokedFunctionArn: 'arn:aws:lambda:us-east-1:123456789012:function:resetUsageScheduled',
  memoryLimitInMB: '512',
  awsRequestId: 'demo-request-id',
  logGroupName: '/aws/lambda/resetUsageScheduled',
  logStreamName: 'demo-stream',
  getRemainingTimeInMillis: () => 30000,
  done: () => {},
  fail: () => {},
  succeed: () => {},
};

console.log('🚀 Server-Side Usage Reset Demo');
console.log('================================');
console.log('');
console.log('Sample Users:');
sampleUsers.forEach((user, index) => {
  console.log(`${index + 1}. ${user.username} (${user.email})`);
  console.log(`   Usage: ${user.usage}`);
  console.log(`   Type: ${user.expiresAt ? 'Subscription' : 'Free Tier'}`);
  if (user.expiresAt) {
    const expiryDate = new Date(user.expiresAt);
    const now = new Date();
    console.log(`   Expires: ${expiryDate.toLocaleDateString()} (${expiryDate > now ? 'Active' : 'Expired'})`);
  }
  console.log(`   Last Reset: ${user.lastResetDate ? new Date(user.lastResetDate).toLocaleDateString() : 'Never'}`);
  console.log('');
});

console.log('Running usage reset process...');
console.log('==============================');

// Patch the handler to use our mock client
const fs = require('fs');
const handlerCode = fs.readFileSync('./dist/handler-simple.js', 'utf8');
const patchedCode = handlerCode.replace(
  'const mockClient = {',
  `const mockClient = ${JSON.stringify(mockClient, null, 2).replace(/"function[^"]*"/g, mockClient.models.UserProfile.list.toString())};`
);

// This is a simplified demo - in a real scenario, we'd properly mock the dependencies
eval(patchedCode);

// Run the handler directly with our sample data
async function runDemo() {
  try {
    console.log('');
    await handler(mockEvent, mockContext);
    console.log('');
    console.log('🎉 Demo completed successfully!');
    console.log('');
    console.log('Expected Results:');
    console.log('- user-1 (freetieruser): Should be reset (35 days since last reset)');
    console.log('- user-2 (expireduser): Should be reset (subscription expired)');
    console.log('- user-3 (activeuser): Should be skipped (active subscription)');
    console.log('- user-4 (recentuser): Should be skipped (reset 5 days ago)');
  } catch (error) {
    console.error('❌ Demo failed:', error);
    process.exit(1);
  }
}

runDemo();