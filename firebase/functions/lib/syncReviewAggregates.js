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
exports.syncReviewAggregates = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
function timestampMillis(value) {
    return value && typeof value.toMillis === "function" ? value.toMillis() : 0;
}
/**
 * Keeps the shop's public rating and bounded review preview in sync with the
 * reviews subcollection. Clients never receive permission to write either
 * aggregate directly.
 */
exports.syncReviewAggregates = functions.firestore
    .document("shops/{shopId}/reviews/{reviewId}")
    .onWrite(async (_change, context) => {
    const { shopId } = context.params;
    const reviewsSnap = await db
        .collection("shops")
        .doc(shopId)
        .collection("reviews")
        .get();
    const reviews = reviewsSnap.docs.map((doc) => ({
        reviewId: doc.id,
        ...doc.data(),
    }));
    const ratings = reviews
        .map((review) => review.rating)
        .filter((rating) => typeof rating === "number" && rating >= 1 && rating <= 5);
    const average = ratings.length === 0
        ? 0
        : ratings.reduce((sum, rating) => sum + rating, 0) / ratings.length;
    reviews.sort((a, b) => timestampMillis(a.createdAt) - timestampMillis(b.createdAt));
    const previews = reviews.slice(-50).map((review) => ({
        reviewId: review.reviewId,
        authorName: review.authorName ?? "User",
        authorPhotoUrl: review.authorPhotoUrl ?? null,
        rating: review.rating,
        text: review.text ?? "",
        tags: Array.isArray(review.tags) ? review.tags : [],
        createdAt: review.createdAt ?? null,
        ...(review.imageUrl ? { imageUrl: review.imageUrl } : {}),
        ...(Array.isArray(review.responses) ? { responses: review.responses } : {}),
    }));
    const shopRef = db.collection("shops").doc(shopId);
    if (!(await shopRef.get()).exists)
        return null;
    await shopRef.update({
        reviews: previews,
        ratings: average,
    });
    return null;
});
//# sourceMappingURL=syncReviewAggregates.js.map