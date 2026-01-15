# Verification: Cosine Similarity Algorithm Implementation

## Status: ✅ CORRECTLY IMPLEMENTED

The collaborative algorithm (cosine similarity) **IS** being used for regular shops discovery and **IS NOT** being used for featured shops selection. This is exactly as requested.

---

## How It Works:

### 1. FEATURED SHOPS - Manual Selection (NO Algorithm)
**File**: `lib/screens/tabs/explore_tab.dart` lines 790-797

```dart
Stream<QuerySnapshot<Map<String, dynamic>>> _getFeaturedShopsStream() {
  // Query featured shops that are verified, sorted by rating
  return FirebaseFirestore.instance
      .collection('shops')
      .where('isVerified', isEqualTo: true)
      .where('isFeatured', isEqualTo: true)    // YOU set this in Firebase
      .orderBy('ratings', descending: true)
      .limit(10)
      .snapshots();
}
```

**What it does:**
- Simply queries shops where you manually set `isFeatured = true`
- NO cosine similarity algorithm
- NO user interest matching
- NO collaborative filtering
- Just sorted by rating

---

### 2. REGULAR SHOPS - Uses Cosine Similarity Algorithm ✓
**File**: `lib/screens/tabs/explore_tab.dart` lines 799-835

```dart
Stream<QuerySnapshot<Map<String, dynamic>>> _getShopsStream() {
  // If we have user interests and no filter is selected, show RECOMMENDED shops
  if (_userInterests.isNotEmpty && _selectedChip == -1) {
    // Query shops that match user interests and are verified
    return FirebaseFirestore.instance
        .collection('shops')
        .where('isVerified', isEqualTo: true)
        .where('tags', arrayContainsAny: _userInterests)  // User interests matching
        .orderBy('postedAt', descending: true)
        .snapshots();
  } else {
    // Default behavior based on selected chip
    // ...
  }
}
```

Then shops are SORTED by recommendation score (lines 880-894):

```dart
// Sort primarily by recommendation score (cosine-based), then by rating and review count
list.sort((a, b) {
  final sa = _shopRecommendationScores[a.id] ?? 0.0;    // COSINE SIMILARITY SCORE
  final sb = _shopRecommendationScores[b.id] ?? 0.0;    // COSINE SIMILARITY SCORE

  // 1) Primary: recommendation score (higher is better)
  if (sb != sa) return sb.compareTo(sa);                // Algorithm sorts first!

  // 2) Fallback: rating
  // 3) Fallback: review count
});
```

**What it does:**
- ✅ Uses cosine similarity to calculate `_shopRecommendationScores`
- ✅ Filters by user interests
- ✅ Matches visit tags from reviews
- ✅ Considers amenity tags
- ✅ Calculates score: (rating + visit_tag_weights + amenity_weights)
- ✅ Sorts shops by this score FIRST, then by rating, then by review count

---

## The Algorithm In Detail:

**Location**: `lib/screens/tabs/explore_tab.dart` lines 20-240

The cosine similarity algorithm:
1. Gets current user's reviews (their ratings and visit tags)
2. Finds similar users (by comparing their reviews)
3. Uses those similar users' preferences to recommend shops
4. Formula: 
   ```
   Similarity = Σ(Rating + VisitTags + Amenities)² 
                / √[user1_vector] × √[user2_vector]
   ```
5. Generates recommendation scores for each shop
6. Stores in `_shopRecommendationScores` map

---

## Visit Tags Location: ✅ CORRECT

Visit tags are stored in **reviews**, not in a separate visits collection:

```firestore
shops/{shopId}/reviews/{reviewId} {
  "userId": "...",
  "rating": 5,
  "text": "Great coffee!",
  "tags": [                    // VISIT TAGS HERE
    "Study Session",
    "Specialty Coffee",
    "Work-Friendly"
  ],
  "createdAt": Timestamp
}
```

**NOT** in a separate visits collection. ✓

---

## Usage Flow:

### User Views "Monthly Featured Cafe Shops" Section
1. App calls `_getFeaturedShopsStream()`
2. Queries: `isFeatured = true` + `isVerified = true`
3. Sorts by rating
4. **NO algorithm used** ✓
5. Shows whatever YOU manually marked as featured

### User Views "Shops" Section
1. App calls `_getShopsStream()`
2. Filters by user interests (optional)
3. Gets list of shops
4. App calls `_applyFilters()` which **SORTS by cosine similarity score**
5. **Algorithm USED here** ✓
6. Shops are ordered by recommendation score first

---

## Database Fields Used by Algorithm:

From shops:
- `ratings` - shop average rating
- `tags` - amenity tags (e.g., "Work-Friendly", "Pet-Friendly")
- `reviews` - subcollection with user reviews

From reviews:
- `rating` - user's rating (1-5)
- `tags` - visit tags (e.g., "Study Session", "Business Meeting")
- `userId` - to identify user for similarity calculation

---

## Summary:

✅ **Featured Shops** = Manual selection (no algorithm)
✅ **Regular Shops** = Cosine similarity algorithm (user interests + tags)
✅ **Visit Tags** = Stored in reviews (not separate collection)
✅ **Collaborative Algorithm** = Active in shops section, not featured

**This is exactly what you requested!**
