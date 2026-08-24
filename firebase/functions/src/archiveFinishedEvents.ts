import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Scheduled function: archive finished events.
 *
 * Runs hourly and marks events whose endDate has passed as isArchived: true.
 * Replaces the previous client-side auto-archive, which made every installed
 * app perform redundant writes on every snapshot emission (billed writes +
 * listener churn).
 *
 * Events keep `endDate` either as a Firestore Timestamp or an ISO-8601
 * string; both are handled.
 */
export const archiveFinishedEvents = functions.pubsub
  .schedule("every 60 minutes")
  .timeZone("Asia/Manila")
  .onRun(async (_context) => {
    const now = new Date();
    const shopsSnap = await db.collection("shops").get();

    let archived = 0;
    for (const shop of shopsSnap.docs) {
      const eventsSnap = await shop.ref
        .collection("events")
        .where("isArchived", "==", false)
        .get();

      const batch = db.batch();
      let batchOps = 0;

      for (const event of eventsSnap.docs) {
        const data = event.data();
        if (data.isArchived === true) continue;

        const rawEnd = data.endDate;
        let end: Date | null = null;
        if (rawEnd?.toDate) {
          end = rawEnd.toDate();
        } else if (typeof rawEnd === "string" && rawEnd.length > 0) {
          const parsed = new Date(rawEnd);
          if (!isNaN(parsed.getTime())) end = parsed;
        }

        if (end && end.getTime() < now.getTime()) {
          batch.update(event.ref, { isArchived: true });
          archived++;
          batchOps++;
          if (batchOps >= 400) {
            await batch.commit();
            batchOps = 0;
          }
        }
      }
      if (batchOps > 0) await batch.commit();
    }

    functions.logger.info(`archiveFinishedEvents: archived ${archived} events`);
    return null;
  });
