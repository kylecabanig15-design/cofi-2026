/**
 * One-time cleanup: strip applicant PII from the allJobs mirror.
 *
 * The mirror function previously copied the full job document — including
 * the embedded `applications` array (applicant emails, phone numbers,
 * resume URLs) into world-readable allJobs. The mirror now strips that
 * field going forward (see functions/index.js), but existing documents
 * keep it until this script runs.
 *
 * Requires the Admin SDK (client writes to allJobs are blocked by rules).
 *
 * USAGE:
 *   npm install --prefix functions          # ensures firebase-admin exists
 *   NODE_PATH="$(pwd)/functions/node_modules" node scripts/purge_alljobs_pii.js                # dry run
 *   PURGE_APPLY=1 NODE_PATH="$(pwd)/functions/node_modules" \
 *     GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
 *     node scripts/purge_alljobs_pii.js
 */

const admin = require("firebase-admin");

admin.initializeApp();

const apply = process.env.PURGE_APPLY === "1";
const BATCH_SIZE = 400;

async function main() {
  const db = admin.firestore();
  console.log(
    apply
      ? "⚠️  APPLY mode — documents WILL be modified\n"
      : "Dry run (set PURGE_APPLY=1 to apply)\n"
  );

  const snapshot = await db.collection("allJobs").get();
  console.log(`Found ${snapshot.size} allJobs documents.`);

  let dirty = 0;
  let batch = db.batch();
  let inBatch = 0;
  let batches = 0;

  for (const doc of snapshot.docs) {
    if (!doc.exists || !("applications" in doc.data())) continue;
    dirty++;
    batch.update(doc.ref, { applications: admin.firestore.FieldValue.delete() });
    inBatch++;

    if (inBatch === BATCH_SIZE) {
      if (apply) await batch.commit();
      batches++;
      batch = db.batch();
      inBatch = 0;
      console.log(`  committed batch #${batches} (${dirty} docs so far)`);
    }
  }

  if (inBatch > 0) {
    if (apply) await batch.commit();
    batches++;
  }

  console.log(
    `\n${dirty} document(s) contain applicant PII across ${batches} batch(es).`
  );
  console.log(apply ? "Done." : "Dry run complete — nothing was written.");

  await admin.app().delete();
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
