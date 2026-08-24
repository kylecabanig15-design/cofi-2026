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
    .set(data, { merge: true });
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
