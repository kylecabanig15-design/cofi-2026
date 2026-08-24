"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.archiveFinishedEvents = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
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
exports.archiveFinishedEvents = functions.pubsub
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
            if (data.isArchived === true)
                continue;
            const rawEnd = data.endDate;
            let end = null;
            if (rawEnd?.toDate) {
                end = rawEnd.toDate();
            }
            else if (typeof rawEnd === "string" && rawEnd.length > 0) {
                const parsed = new Date(rawEnd);
                if (!isNaN(parsed.getTime()))
                    end = parsed;
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
        if (batchOps > 0)
            await batch.commit();
    }
    functions.logger.info(`archiveFinishedEvents: archived ${archived} events`);
    return null;
});
//# sourceMappingURL=archiveFinishedEvents.js.map