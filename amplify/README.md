# Server-Side Usage Reset Backup System

This directory contains the AWS Amplify Gen 2 implementation of a server-side usage reset backup system that ensures usage limits are reset even if the client fails.

## Overview

The system provides redundancy for usage reset operations by implementing a scheduled Lambda function that runs daily to check all UserProfile records and reset usage where appropriate.

## Architecture

### Components

1. **Scheduled Lambda Function** (`amplify/functions/resetUsageScheduled/`)
   - Runs daily via EventBridge schedule
   - Processes all UserProfile records in batches
   - Implements retry logic with exponential backoff
   - Provides comprehensive logging and metrics

2. **Data Schema** (`amplify/data/resource.ts`)
   - UserProfile model with usage tracking fields
   - Proper authorization rules for data access

3. **Backend Configuration** (`amplify/backend.ts`)
   - Integrates all components
   - Sets up proper IAM permissions
   - Configures CloudWatch access

## Features

### Reset Logic

#### Subscription Users
- Checks if `expiresAt` date has passed
- Resets usage and updates `lastResetDate`
- Handles edge cases with null/invalid dates

#### Free Tier Users
- Calculates next reset date based on 30-day intervals
- Uses `createdAt` or `lastResetDate` as base date
- Resets usage when current date >= next reset date

### Batch Processing
- Processes users in batches of 100 to avoid timeouts
- Uses pagination to handle large datasets
- Continues processing even if individual users fail
- Implements proper error handling

### Monitoring & Logging
- Comprehensive logging for all operations
- Tracks metrics (processed, successful, failed)
- Sends CloudWatch metrics
- Alerts on high failure rates

### Error Handling
- Retry logic with exponential backoff (up to 3 retries)
- Graceful handling of individual user failures
- Detailed error logging with context
- Continues processing despite failures

## Usage

### Development

1. **Setup Development Environment**
   ```bash
   cd home/shells/aws-amplify
   nix develop
   ```

2. **Install Dependencies**
   ```bash
   npm install
   ```

3. **Run Tests**
   ```bash
   npm test
   ```

4. **Build Project**
   ```bash
   npm run build
   ```

### Deployment

1. **Deploy to Staging**
   ```bash
   npm run deploy:staging
   ```

2. **Deploy to Production**
   ```bash
   npm run deploy:prod
   ```

### Monitoring

The Lambda function provides detailed logging and metrics:

- **CloudWatch Logs**: Detailed operation logs
- **CloudWatch Metrics**: Processing statistics
- **Failure Alerts**: High failure rate notifications

## Configuration

### Environment Variables

The function uses these environment variables:

- `NODE_ENV`: Environment (development/production)
- `AWS_REGION`: AWS region for deployment

### Scheduling

The function runs daily using EventBridge:
- **Schedule**: `rate(1 day)`
- **Timeout**: 5 minutes
- **Memory**: 512 MB

## Testing

The implementation includes comprehensive tests:

- **Unit Tests**: Individual function testing
- **Integration Tests**: End-to-end workflow testing
- **Error Handling Tests**: Failure scenario testing
- **Performance Tests**: Batch processing validation

Run tests:
```bash
npm test
npm run test:watch  # Watch mode
```

## Compatibility

The system is designed to work alongside the existing client-side usage reset system:

- **Idempotency**: Prevents duplicate resets
- **Date Tracking**: Uses `lastResetDate` for coordination
- **Schema Compatibility**: Works with existing UserProfile model

## Security

- **IAM Permissions**: Minimal required permissions
- **Data Access**: Proper authorization rules
- **Logging**: No sensitive data in logs

## Performance Considerations

- **Batch Size**: 100 users per batch (configurable)
- **Timeout**: 5-minute Lambda timeout
- **Memory**: 512 MB allocation
- **Concurrency**: Single function instance to avoid conflicts

## Future Enhancements

- CloudWatch dashboard for monitoring
- SNS notifications for critical failures
- Dynamic batch size based on processing time
- Support for different reset intervals per user type