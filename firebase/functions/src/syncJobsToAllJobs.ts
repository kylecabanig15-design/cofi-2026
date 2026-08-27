import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * Cloud Function to sync jobs to allJobs collection
 * Triggered when any job document is created, updated, or deleted
 * 
 * Only public job fields are synced to allJobs. Applicant records contain
 * contact details and resume URLs and must remain on the staff-only source doc.
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
        const { applications: _privateApplications, ...publicFields } = newData;
        const jobData = {
          ...publicFields,
          shopId: shopId,
          jobId: jobId,
          syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        // A full replacement also removes private/stale fields copied by older
        // versions of this function.
        await db.collection("allJobs").doc(jobId).set(jobData);
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

/** Removes applicant data left in public mirrors by pre-fix deployments. */
export const scrubPublicJobFeed = functions.pubsub
  .schedule("every 60 minutes")
  .onRun(async () => {
    const snapshot = await db.collection("allJobs").get();
    let batch = db.batch();
    let operations = 0;
    let scrubbed = 0;

    for (const doc of snapshot.docs) {
      if (!("applications" in doc.data())) continue;
      batch.update(doc.ref, {
        applications: admin.firestore.FieldValue.delete(),
      });
      operations++;
      scrubbed++;
      if (operations >= 400) {
        await batch.commit();
        batch = db.batch();
        operations = 0;
      }
    }
    if (operations > 0) await batch.commit();
    functions.logger.info(`scrubPublicJobFeed: scrubbed ${scrubbed} jobs`);
    return null;
  });
