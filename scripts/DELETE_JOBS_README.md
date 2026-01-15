# Delete All Jobs Script

This script will permanently delete all jobs from Firestore.

## Prerequisites

Make sure you have Node.js installed and firebase-admin is installed:

```bash
npm install
```

## Usage

Run the script:

```bash
node scripts/delete_all_jobs.js
```

## What It Does

1. **Deletes all pending jobs** from the `pendingJobs` collection
2. **Deletes all jobs** from each shop's `shops/{shopId}/jobs` subcollection

## Warning

⚠️ **This is a destructive operation!** 

- All jobs will be permanently deleted
- There is no undo
- This cannot be recovered

## Output

The script will show progress as it deletes:
- Count of deleted pending jobs
- Count of deleted jobs per shop
- Total count of deleted documents

## Example Output

```
Starting to delete all jobs...

1. Deleting all pendingJobs...
Deleted pendingJobs: 25
✓ Deleted 25 pending jobs

2. Deleting all jobs from shops...
  Shop "shop1": Deleted 10 jobs
  Shop "shop2": Deleted 15 jobs
  Shop "shop3": Deleted 8 jobs

✓ Deleted 33 jobs from all shops

✓ Total deleted: 58 documents

All jobs have been successfully deleted!
```
