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
exports.syncAllJobsStatusBackToShops = exports.syncJobsToAllJobs = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
/**
 * Cloud Function to sync jobs to allJobs collection
 * Triggered when any job document is created, updated, or deleted
 *
 * All jobs (pending and active) are synced to allJobs for public listing
 * Only closed and archived jobs are removed from allJobs
 */
exports.syncJobsToAllJobs = functions.firestore
    .document("shops/{shopId}/jobs/{jobId}")
    .onWrite(async (change, context) => {
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
        const status = newData.status || "pending";
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
        }
        else {
            // Remove archived jobs from allJobs
            await db.collection("allJobs").doc(jobId).delete();
            console.log(`[${status}] Job ${jobId} removed from allJobs`);
        }
        return null;
    }
    catch (error) {
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
exports.syncAllJobsStatusBackToShops = functions.firestore
    .document("allJobs/{jobId}")
    .onUpdate(async (change, context) => {
    const { jobId } = context.params;
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) {
        return null;
    }
    const oldStatus = before.status || "pending";
    const newStatus = after.status || "pending";
    // Only act when status actually changes
    if (oldStatus === newStatus) {
        return null;
    }
    const shopId = after.shopId;
    if (!shopId) {
        console.log(`[reverse-sync] Skipping job ${jobId} because shopId is missing on allJobs doc.`);
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
            console.log(`[reverse-sync] Job ${jobId} not found under shop ${shopId}, nothing to update.`);
            return null;
        }
        const current = jobSnap.data() || {};
        const currentStatus = current.status || "pending";
        if (currentStatus === newStatus) {
            console.log(`[reverse-sync] Job ${jobId} under shop ${shopId} already has status ${newStatus}.`);
            return null;
        }
        await jobRef.update({
            status: newStatus,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`[reverse-sync] Job ${jobId} status updated in shops/${shopId}/jobs/${jobId} to ${newStatus}.`);
        return null;
    }
    catch (error) {
        console.error(`Error reverse-syncing job ${jobId} from allJobs:`, error);
        throw error;
    }
});
//# sourceMappingURL=syncJobsToAllJobs.js.map