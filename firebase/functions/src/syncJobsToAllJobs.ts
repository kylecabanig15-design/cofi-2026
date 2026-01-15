import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * Cloud Function to sync jobs to allJobs collection
 * Triggered when any job document is created, updated, or deleted
 * 
 * All jobs (pending and active) are synced to allJobs for public listing
 * Only closed and archived jobs are removed from allJobs
 */
export const syncJobsToAllJobs = functions.firestore
  .document("shops/{shopId}/jobs/{jobId}")
  .onWrite(async (change: any, context: any) => {
    const { shopId, jobId } = context.params;
    const newData = change.after.data();

    try {
      // If job was deleted
      if (!newData) {
        await db.collection("allJobs").doc(jobId).delete();
        console.log(`[Deleted] Job ${jobId} removed from allJobs`);
        return null;
      }

      // Get the status from the new data
      const status = (newData.status as string) || "pending";
      const statusLower = status.toLowerCase();

      // Sync all jobs except archived ones
      if (statusLower !== "archived") {
        // Add to allJobs (pending, active, closed, or any other status)
        const jobData = {
          ...newData,
          shopId: shopId,
          syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        await db.collection("allJobs").doc(jobId).set(jobData, { merge: true });
        console.log(`[${status}] Job ${jobId} synced to allJobs from shop ${shopId}`);
      } else {
        // Remove archived jobs from allJobs
        await db.collection("allJobs").doc(jobId).delete();
        console.log(`[${status}] Job ${jobId} removed from allJobs`);
      }

      return null;
    } catch (error) {
      console.error(`Error syncing job ${jobId}:`, error);
      throw error;
    }
  });

/**
 * Reverse-sync: when status is changed directly on allJobs/{jobId},
 * propagate the new status back to the source document
 * shops/{shopId}/jobs/{jobId}.
 *
 * This lets you approve/activate jobs by editing allJobs in the console
 * while keeping the shop job as the single source of truth for UI queries.
 */
export const syncAllJobsStatusBackToShops = functions.firestore
  .document("allJobs/{jobId}")
  .onUpdate(async (change: any, context: any) => {
    const { jobId } = context.params;
    const before = change.before.data();
    const after = change.after.data();

    if (!before || !after) {
      return null;
    }

    const oldStatus = (before.status as string) || "pending";
    const newStatus = (after.status as string) || "pending";

    // Only act when status actually changes
    if (oldStatus === newStatus) {
      return null;
    }

    const shopId = after.shopId as string | undefined;
    if (!shopId) {
      console.log(
        `[reverse-sync] Skipping job ${jobId} because shopId is missing on allJobs doc.`,
      );
      return null;
    }

    try {
      const jobRef = db
        .collection("shops")
        .doc(shopId)
        .collection("jobs")
        .doc(jobId);

      const jobSnap = await jobRef.get();
      if (!jobSnap.exists) {
        console.log(
          `[reverse-sync] Job ${jobId} not found under shop ${shopId}, nothing to update.`,
        );
        return null;
      }

      const current = jobSnap.data() || {};
      const currentStatus = (current.status as string) || "pending";
      if (currentStatus === newStatus) {
        console.log(
          `[reverse-sync] Job ${jobId} under shop ${shopId} already has status ${newStatus}.`,
        );
        return null;
      }

      await jobRef.update({
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(
        `[reverse-sync] Job ${jobId} status updated in shops/${shopId}/jobs/${jobId} to ${newStatus}.`,
      );

      return null;
    } catch (error) {
      console.error(`Error reverse-syncing job ${jobId} from allJobs:`, error);
      throw error;
    }
  });


