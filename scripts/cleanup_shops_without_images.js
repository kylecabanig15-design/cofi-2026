#!/usr/bin/env node

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
// You'll need to set GOOGLE_APPLICATION_CREDENTIALS environment variable
// or place your service account key file here
const serviceAccount = process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!serviceAccount) {
  console.error('❌ Error: GOOGLE_APPLICATION_CREDENTIALS environment variable not set');
  console.error('Please set it to your Firebase service account JSON file path');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(path.resolve(serviceAccount)))
});

const db = admin.firestore();

async function cleanupShopsWithoutImages() {
  try {
    console.log('🔍 Starting cleanup: Finding shops without images...\n');

    const shopsRef = db.collection('shops');
    const snapshot = await shopsRef.get();

    console.log(`📊 Total shops found: ${snapshot.size}\n`);

    if (snapshot.empty) {
      console.log('✅ No shops found. Nothing to clean up.');
      process.exit(0);
    }

    let deletedCount = 0;
    let skippedCount = 0;

    for (const doc of snapshot.docs) {
      const shopData = doc.data();
      const shopName = shopData.name || 'Unknown';
      const logoUrl = shopData.logoUrl;
      const menuImages = shopData.menuImages;

      // Check if shop has no images
      const hasNoImages = 
        (!logoUrl || logoUrl.toString().trim() === '') &&
        (!menuImages || (Array.isArray(menuImages) && menuImages.length === 0));

      if (hasNoImages) {
        console.log(`🗑️  Deleting: "${shopName}" (ID: ${doc.id})`);
        console.log(`   └─ logoUrl: ${logoUrl || 'null'}`);
        console.log(`   └─ menuImages: ${menuImages || 'null'}\n`);

        await doc.ref.delete();
        deletedCount++;
      } else {
        skippedCount++;
        console.log(`✅ Keeping: "${shopName}" (has images)\n`);
      }
    }

    console.log('\n========== CLEANUP SUMMARY ==========');
    console.log(`🗑️  Shops deleted: ${deletedCount}`);
    console.log(`✅ Shops kept: ${skippedCount}`);
    console.log(`📊 Total processed: ${deletedCount + skippedCount}`);
    console.log('====================================\n');

    if (deletedCount > 0) {
      console.log(`✨ Cleanup complete! ${deletedCount} shop(s) removed.`);
    } else {
      console.log('✨ No shops to delete. All shops have images.');
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    process.exit(1);
  }
}

cleanupShopsWithoutImages();
