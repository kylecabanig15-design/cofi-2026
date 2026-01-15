# Cloud Functions Setup Guide - Job Syncing

## Overview
This Cloud Function automatically syncs active jobs to a master `allJobs` collection, making queries much faster.

## Setup Instructions

### 1. Install Firebase CLI (if not already installed)
```bash
npm install -g firebase-tools
```

### 2. Navigate to Firebase Functions Directory
```bash
cd /Users/kylechristiancabanig/flutter/CoFi/firebase/functions
```

### 3. Install Dependencies
```bash
npm install
```

### 4. Login to Firebase
```bash
firebase login
```

### 5. Initialize Firebase (if not already done)
```bash
firebase init functions
```

### 6. Add the function file
The function is already created at:
`firebase/functions/src/syncJobsToAllJobs.ts`

Update `firebase/functions/src/index.ts` to export the functions:

```typescript
export * from "./syncJobsToAllJobs";
```

### 7. Deploy to Firebase
```bash
firebase deploy --only functions
```

## How It Works

### Trigger: `shops/{shopId}/jobs/{jobId}`
When ANY job document is created, updated, or deleted:

1. **Status = 'active'**
   - ✅ Job is added/updated in `allJobs` collection
   - ✅ Copy includes all original fields + `shopId`

2. **Status = 'closed', 'pending', 'archived'**
   - ✅ Job is removed from `allJobs` collection
   - ✅ Original job remains in `shops/{shopId}/jobs`

3. **Job Deleted**
   - ✅ Automatically removed from `allJobs`

## Updated Flutter Code Example

### Before (Slow - iterates all shops):
```dart
stream: FirebaseFirestore.instance
    .collectionGroup('jobs')
    .where('status', isEqualTo: 'active')
    .limit(10)
    .snapshots(),
```

### After (Fast - single collection):
```dart
stream: FirebaseFirestore.instance
    .collection('allJobs')
    .orderBy('createdAt', descending: true)
    .limit(10)
    .snapshots(),
```

## Database Structure

```
Firestore
├── shops/
│   └── {shopId}/
│       └── jobs/
│           └── {jobId}  (original location - always kept)
│
└── allJobs/           (NEW - auto-synced master collection)
    └── {jobId}        (copy of job when status='active')
        ├── title
        ├── status: "active"
        ├── shopId
        ├── createdAt
        └── ... (all other fields)
```

## Monitoring

View function logs:
```bash
firebase functions:log
```

Or in Firebase Console:
- Go to: Cloud Functions
- Select: `syncJobsToAllJobs`
- View logs in the "Logs" tab

## Cost Implications

- **Minimal cost**: Only writes when status changes to/from 'active'
- **Savings**: Much faster queries = fewer database reads
- **Example**: Instead of reading 10 shop collections, read 1 collection

## Firestore Rules

Add this to your Firestore security rules if needed:

```javascript
match /allJobs/{jobId} {
  allow read: if request.auth != null;
  allow write: if false;  // Only Cloud Functions can write
}
```

## Troubleshooting

### Function not triggering?
- Check Cloud Functions logs in Firebase Console
- Ensure function was deployed: `firebase deploy --only functions`

### Jobs not appearing in allJobs?
- Verify jobs have `status: 'active'`
- Check function logs for errors

### Duplicate jobs?
- Use `set(..., { merge: true })` to prevent duplicates

## Next Steps

1. Deploy the function
2. Update Flutter code in `community_tab.dart` to query `allJobs` instead of `collectionGroup`
3. Monitor logs to confirm syncing
4. Remove old collectionGroup queries where appropriate
