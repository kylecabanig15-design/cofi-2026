# Explore Tab Flow Diagram

## App Flow:

```
┌─────────────────────────────────────────────────────────────┐
│                     USER OPENS EXPLORE TAB                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │   "Monthly Featured Cafe Shops" Section │
        │              (You select manually)       │
        └─────────────────────────────────────────┘
                              │
                              ▼
                  _getFeaturedShopsStream()
                              │
        ┌───────────────────────────────────────────┐
        │ Query: isFeatured = true                  │
        │        isVerified = true                  │
        │ Sort: by ratings (descending)             │
        │ Algorithm: NONE ❌                        │
        └───────────────────────────────────────────┘
                              │
                              ▼
         [ Shop A ]  [ Shop B ]  [ Shop C ]
         (Featured)  (Featured)  (Featured)
         (5.0 rating)(4.8 rating)(4.6 rating)
         
         
================== DIVIDER ==================


        ┌──────────────────────────────────┐
        │   "Shops" Section                │
        │   (All verified shops + algorithm)│
        └──────────────────────────────────┘
                              │
                              ▼
                  _getShopsStream()
                              │
        ┌───────────────────────────────────────────┐
        │ Query: isVerified = true                  │
        │ Filter: Optional by user interests        │
        │ Algorithm: NONE yet ❌                    │
        └───────────────────────────────────────────┘
                              │
                              ▼
                  _applyFilters()
                              │
        ┌───────────────────────────────────────────┐
        │ COSINE SIMILARITY ALGORITHM APPLIED! ✅   │
        │ Sorts by: _shopRecommendationScores       │
        │ Formula: (rating + tags + amenities) / √ │
        │ Then by: rating                           │
        │ Then by: review count                     │
        └───────────────────────────────────────────┘
                              │
                              ▼
    [ Shop X ]  [ Shop Y ]  [ Shop Z ]  [ Shop W ]
    (Match: 0.92) (Match: 0.87) (Match: 0.76) (Match: 0.62)
    (Score based on cosine similarity of user reviews)
```

---

## Side-by-Side Comparison:

| Feature | Featured Section | Shops Section |
|---------|-----------------|---------------|
| **Query Filter** | `isFeatured = true` | `isVerified = true` |
| **How Selected** | You manually set in Firebase | Algorithm selects automatically |
| **Algorithm Used** | ❌ NO | ✅ YES (Cosine Similarity) |
| **Sorting Logic** | By rating (simple) | By recommendation score (complex) |
| **User Interests** | Ignored | Matched with tags |
| **Visit Tags** | Ignored | Used in calculation |
| **Amenity Tags** | Ignored | Used in calculation |
| **Update Frequency** | Manual, when you update Firebase | Real-time, recalculated per user |
| **Result** | Same shops for all users | Different shops per user (personalized) |

---

## Code Locations:

### Featured Shops (No Algorithm):
- File: `lib/screens/tabs/explore_tab.dart`
- Lines: 790-797
- Method: `_getFeaturedShopsStream()`

### Regular Shops (With Algorithm):
- File: `lib/screens/tabs/explore_tab.dart`
- Lines: 799-835
- Method: `_getShopsStream()`

### Filtering & Sorting (Where Algorithm is Applied):
- File: `lib/screens/tabs/explore_tab.dart`
- Lines: 840-900
- Method: `_applyFilters()`
- Key line: `list.sort((a, b) { ... _shopRecommendationScores[a.id] ... }`

### Algorithm Implementation:
- File: `lib/screens/tabs/explore_tab.dart`
- Lines: 20-240
- Method: `calculateCosineSimilarity()`

---

## What This Means:

✅ **Your monthly featured section is manually curated**
- You pick the cafés that appear there
- Same featured shops shown to everyone
- No algorithm interference

✅ **Your regular shops are intelligently recommended**
- Each user sees different shops ordered by relevance
- Based on users with similar visit patterns
- Takes into account:
  - What cafés they visited
  - How they rated them
  - What tags they use (Study, Coffee, Business, etc.)
  - What amenities each café has

✅ **Visit tags are properly stored**
- In the reviews subcollection
- Not in a separate visits collection
- Used by the algorithm to find similar users

This is exactly what you asked for! 🎯
