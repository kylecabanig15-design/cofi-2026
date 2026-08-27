const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Mirror shops/{shopId}/jobs/{jobId} into the denormalized allJobs feed.
// Cloud Functions bypass security rules, so clients no longer dual-write
// allJobs — this is the single coordinated writer.
//
// The embedded `applications` array holds applicant PII (emails, phone
// numbers, resume URLs). allJobs is readable by every signed-in user, so
// it must never be mirrored there.
function publicJobData(jobData) {
  const data = { ...jobData };
  data.applications = admin.firestore.FieldValue.delete();
  return data;
}

function mirrorJobToAllJobs(shopId, jobId, jobData) {
  const data = { ...publicJobData(jobData), shopId, jobId };
  return admin
    .firestore()
    .collection("allJobs")
    .doc(jobId)
    // Full overwrite (NOT merge) — merge:true keeps stale values for any
    // field that was removed or nulled out at the source (e.g. closedAt
    // cleared on republish), causing permanent drift between the mirror
    // and shops/{shopId}/jobs.
    .set(data);
}

exports.onJobCreate = functions.firestore
  .document("shops/{shopId}/jobs/{jobId}")
  .onCreate(async (snapshot, context) => {
    const jobId = context.params.jobId;
    const shopId = context.params.shopId;

    try {
      await mirrorJobToAllJobs(shopId, jobId, snapshot.data());
      console.log(`Mirrored new job ${jobId} to allJobs`);
      return null;
    } catch (error) {
      console.error(`Error mirroring new job ${jobId} to allJobs: ${error}`);
      throw error;
    }
  });

exports.onJobUpdate = functions.firestore
  .document("shops/{shopId}/jobs/{jobId}")
  .onUpdate(async (change, context) => {
    const jobId = context.params.jobId;
    const shopId = context.params.shopId;
    const newData = change.after.data();

    try {
      // Re-mirror on ANY field change (status, applications, edits, ...)
      // using the full post-update document.
      await mirrorJobToAllJobs(shopId, jobId, newData);
      console.log(`Re-mirrored job ${jobId} to allJobs`);
      return null;
    } catch (error) {
      console.error(`Error re-mirroring job ${jobId} to allJobs: ${error}`);
      throw error;
    }
  });

exports.onJobDelete = functions.firestore
  .document("shops/{shopId}/jobs/{jobId}")
  .onDelete(async (snapshot, context) => {
    const jobId = context.params.jobId;

    try {
      await admin.firestore().collection("allJobs").doc(jobId).delete();
      console.log(`Removed deleted job ${jobId} from allJobs`);
      return null;
    } catch (error) {
      console.error(
        `Error removing deleted job ${jobId} from allJobs: ${error}`
      );
      throw error;
    }
  });

// Keep the shop's denormalized rating aggregate and embedded reviews array
// in sync when a review is deleted (account cleanup, author removal).
// Without this, ratings drift permanently from the reviews subcollection.
exports.onReviewDelete = functions.firestore
  .document("shops/{shopId}/reviews/{reviewId}")
  .onDelete(async (snapshot, context) => {
    const shopId = context.params.shopId;
    const removed = snapshot.data() || {};

    try {
      await admin.firestore().runTransaction(async (tx) => {
        const shopRef = admin.firestore().collection("shops").doc(shopId);
        const shopSnap = await tx.get(shopRef);
        if (!shopSnap.exists) return;

        const data = shopSnap.data();
        const currentReviews = Array.isArray(data.reviews)
          ? data.reviews.slice()
          : [];

        // Match on author + text + rating; legacy entries carry no reviewId,
        // so remove the first entry matching the deleted review's content.
        const index = currentReviews.findIndex(
          (r) =>
            r &&
            r.authorName === removed.authorName &&
            r.rating === removed.rating &&
            r.text === removed.text
        );
        if (index >= 0) {
          currentReviews.splice(index, 1);
        }

        let avgRating = 0;
        if (currentReviews.length > 0) {
          const total = currentReviews.reduce(
            (sum, r) => sum + ((r && r.rating) || 0),
            0
          );
          avgRating = total / currentReviews.length;
        }

        tx.update(shopRef, {
          reviews: currentReviews,
          ratings: avgRating,
        });
      });
      console.log(`Recomputed rating aggregate for shop ${shopId}`);
      return null;
    } catch (error) {
      console.error(
        `Error recomputing rating for shop ${shopId}: ${error}`
      );
      throw error;
    }
  });
