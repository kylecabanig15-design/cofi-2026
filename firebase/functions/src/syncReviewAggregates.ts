import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

function timestampMillis(value: any): number {
  return value && typeof value.toMillis === "function" ? value.toMillis() : 0;
}

/**
 * Keeps the shop's public rating and bounded review preview in sync with the
 * reviews subcollection. Clients never receive permission to write either
 * aggregate directly.
 */
export const syncReviewAggregates = functions.firestore
  .document("shops/{shopId}/reviews/{reviewId}")
  .onWrite(async (_change: any, context: any) => {
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
      .map((review: any) => review.rating)
      .filter((rating: any) => typeof rating === "number" && rating >= 1 && rating <= 5);
    const average = ratings.length === 0
      ? 0
      : ratings.reduce((sum: number, rating: number) => sum + rating, 0) / ratings.length;

    reviews.sort(
      (a: any, b: any) => timestampMillis(a.createdAt) - timestampMillis(b.createdAt),
    );
    const previews = reviews.slice(-50).map((review: any) => ({
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
    if (!(await shopRef.get()).exists) return null;
    await shopRef.update({
      reviews: previews,
      ratings: average,
    });
    return null;
  });
