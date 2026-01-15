const admin = require('firebase-admin');
const serviceAccount = require('../android/app/google-services.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteAllJobs() {
  console.log('Starting to delete all jobs...');
  
  try {
    // Delete all pendingJobs first
    console.log('\n1. Deleting all pendingJobs...');
    const pendingJobsRef = db.collection('pendingJobs');
    const pendingJobsSnapshot = await pendingJobsRef.get();
    
    let pendingJobsCount = 0;
    for (const doc of pendingJobsSnapshot.docs) {
      await doc.ref.delete();
      pendingJobsCount++;
      process.stdout.write(`\rDeleted pendingJobs: ${pendingJobsCount}`);
    }
    console.log(`\n✓ Deleted ${pendingJobsCount} pending jobs\n`);

    // Delete all jobs from each shop
    console.log('2. Deleting all jobs from shops...');
    const shopsRef = db.collection('shops');
    const shopsSnapshot = await shopsRef.get();
    
    let totalJobsDeleted = 0;
    
    for (const shopDoc of shopsSnapshot.docs) {
      const shopId = shopDoc.id;
      const jobsRef = db.collection('shops').doc(shopId).collection('jobs');
      const jobsSnapshot = await jobsRef.get();
      
      let shopJobsCount = 0;
      for (const jobDoc of jobsSnapshot.docs) {
        await jobDoc.ref.delete();
        shopJobsCount++;
        totalJobsDeleted++;
      }
      
      if (shopJobsCount > 0) {
        console.log(`  Shop "${shopId}": Deleted ${shopJobsCount} jobs`);
      }
    }
    
    console.log(`\n✓ Deleted ${totalJobsDeleted} jobs from all shops`);
    console.log(`\n✓ Total deleted: ${pendingJobsCount + totalJobsDeleted} documents\n`);
    console.log('All jobs have been successfully deleted!');
    
    process.exit(0);
  } catch (error) {
    console.error('Error deleting jobs:', error);
    process.exit(1);
  }
}

deleteAllJobs();
