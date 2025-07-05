#!/usr/bin/env node

// Simple demo script to show the core logic working
console.log('🚀 Server-Side Usage Reset Demo');
console.log('================================');
console.log('');

// Sample user data for demonstration
const sampleUsers = [
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

// Constants from the handler
const FREE_TIER_RESET_INTERVAL_DAYS = 30;

// Core reset logic functions (extracted from handler)
function determineResetEligibility(userProfile, currentTime) {
  const userId = userProfile.id;
  const lastResetDate = userProfile.lastResetDate ? new Date(userProfile.lastResetDate) : null;
  const createdAt = new Date(userProfile.createdAt);
  const expiresAt = userProfile.expiresAt ? new Date(userProfile.expiresAt) : null;
  
  // Check for subscription reset
  if (expiresAt && expiresAt <= currentTime) {
    return {
      shouldReset: true,
      resetType: 'subscription',
      reason: 'Subscription expired',
    };
  }
  
  // Check for free tier reset
  if (!expiresAt || expiresAt < currentTime) {
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

function calculateNextFreeTierResetDate(createdAt, lastResetDate) {
  const baseDate = lastResetDate || createdAt;
  const nextReset = new Date(baseDate.getTime());
  nextReset.setDate(nextReset.getDate() + FREE_TIER_RESET_INTERVAL_DAYS);
  return nextReset;
}

// Demo execution
const currentTime = new Date();
console.log(`Current time: ${currentTime.toISOString()}`);
console.log('');

console.log('Analyzing sample users:');
console.log('======================');

sampleUsers.forEach((user, index) => {
  console.log(`${index + 1}. ${user.username} (${user.email})`);
  console.log(`   Current usage: ${user.usage}`);
  console.log(`   User type: ${user.expiresAt ? 'Subscription' : 'Free Tier'}`);
  
  if (user.expiresAt) {
    const expiryDate = new Date(user.expiresAt);
    console.log(`   Subscription expires: ${expiryDate.toLocaleDateString()} (${expiryDate > currentTime ? 'Active' : 'Expired'})`);
  }
  
  console.log(`   Last reset: ${user.lastResetDate ? new Date(user.lastResetDate).toLocaleDateString() : 'Never'}`);
  console.log(`   Created: ${new Date(user.createdAt).toLocaleDateString()}`);
  
  // Apply reset logic
  const resetInfo = determineResetEligibility(user, currentTime);
  
  if (resetInfo.shouldReset) {
    console.log(`   ✅ ACTION: Reset usage (${resetInfo.reason})`);
    console.log(`   📊 Reset type: ${resetInfo.resetType}`);
    console.log(`   💻 New usage: 0 (was ${user.usage})`);
  } else {
    console.log(`   ⏸️  ACTION: Skip reset (${resetInfo.reason})`);
    if (resetInfo.nextResetDate) {
      console.log(`   📅 Next reset due: ${resetInfo.nextResetDate.toLocaleDateString()}`);
    }
  }
  
  console.log('');
});

console.log('Summary:');
console.log('========');
const resetCount = sampleUsers.filter(user => determineResetEligibility(user, currentTime).shouldReset).length;
const skipCount = sampleUsers.length - resetCount;

console.log(`Total users processed: ${sampleUsers.length}`);
console.log(`Users reset: ${resetCount}`);
console.log(`Users skipped: ${skipCount}`);
console.log('');
console.log('✨ Demo completed successfully!');
console.log('');
console.log('This demonstrates the core logic of the server-side usage reset system:');
console.log('• Subscription users are reset when their subscription expires');
console.log('• Free tier users are reset every 30 days from their last reset');
console.log('• The system handles both types correctly and provides comprehensive logging');
console.log('• Batch processing and retry logic ensure reliable operation at scale');