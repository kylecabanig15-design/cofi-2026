# Cleanup Scripts for CoFi

## Run Cleanup for Shops Without Images

This script removes shops from Firestore that don't have any images (no `logoUrl` or `menuImages`).

### Prerequisites

1. **Install Node.js dependencies:**
   ```bash
   npm install firebase-admin
   ```

2. **Set up Firebase credentials:**
   Download your Firebase service account key from Firebase Console:
   - Go to Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save it somewhere safe (e.g., `~/.config/firebase/serviceAccount.json`)

### Running the Cleanup

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"
node cleanup_shops_without_images.js
```

### What it does

- ✅ Queries all shops in Firestore
- ✅ Checks if each shop has images (logoUrl or menuImages)
- ✅ Deletes shops that have **no images**
- ✅ Shows a detailed report of what was deleted
- ✅ Displays summary statistics

### Example Output

```
🔍 Starting cleanup: Finding shops without images...

📊 Total shops found: 45

🗑️  Deleting: "Cafe No Logo" (ID: abc123)
   └─ logoUrl: null
   └─ menuImages: null

✅ Keeping: "Coffee House" (has images)

========== CLEANUP SUMMARY ==========
🗑️  Shops deleted: 3
✅ Shops kept: 42
📊 Total processed: 45
====================================

✨ Cleanup complete! 3 shop(s) removed.
```

### Safety

- The script **asks for confirmation** before deletion
- Always test in development first
- Keep backups of your database
