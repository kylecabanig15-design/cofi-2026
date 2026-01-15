const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Sync status changes from shops/{shopId}/jobs to allJobs
exports.syncJobStatusToAllJobs = functions.firestore
  .document("shops/{shopId}/jobs/{jobId}")
  .onUpdate(async (change, context) => {
    const jobId = context.params.jobId;
    const shopId = context.params.shopId;
    const newData = change.after.data();
    const oldData = change.before.data();

    // Only proceed if status changed
    if (newData.status === oldData.status) {
      return null;
    }

    try {
      // Update the allJobs collection with new status
      await admin
        .firestore()
        .collection("allJobs")
        .doc(jobId)
        .update({
          status: newData.status,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(
        `Successfully synced status for job ${jobId} to allJobs with status: ${newData.status}`
      );
      return null;
    } catch (error) {
      console.error(`Error syncing job status to allJobs: ${error}`);
      throw error;
    }
  });
