# CoFi Recommendation Algorithm: A Teacher's Story and Code Guide

> Current implementation guide. Last verified: August 28, 2026.

## First, imagine how a teacher would explain CoFi

Imagine that Ana has just joined CoFi. She says she likes quiet cafés, specialty
coffee, and places with Wi-Fi, but the app still does not know how she actually
rates cafés. Her selected interests are useful clues, but they are not yet proof
of her taste. CoFi therefore begins with a practical fallback: show cafés that
match her interests and use public ratings and review activity to break ties.

After Ana reviews cafés, CoFi learns something stronger. Suppose she gives one
café five stars and another café two stars. Ben has reviewed some of the same
cafés. If Ben's pattern is similar—high ratings where Ana rates highly and low
ratings where Ana rates poorly—CoFi treats Ben as a possible “Taste Twin.” It
does the same comparison with other users and keeps the strongest matches.

The comparison uses **cosine similarity**. You can picture every user's café
ratings as an arrow. Two arrows pointing in nearly the same direction represent
similar rating patterns and produce a score near `1`. Very different patterns
produce a score closer to `0`. CoFi compares users only through cafés they have
both rated, because without a shared café there is no fair point of comparison.

The star rating is the main value in each shared café comparison. Matching visit
tags add context: two people who both describe a café as a study destination
have more evidence in common. Café amenities also add the paper's contextual
weights. These additions do not replace the rating; they refine it.

Once CoFi finds up to five similar users, it looks at cafés those users rated
that Ana has not already bookmarked or visited. A Taste Twin with stronger
similarity contributes more to the prediction. For example, a rating from a
user with similarity `0.90` matters more than a rating from a user with
similarity `0.30`. The result is a predicted rating for each unseen café.

Finally, Explore adds Ana's current interests. This is deliberately a separate,
lightweight step. If a café has tags matching two of Ana's interests, it gets
two interest bonuses. This means interest edits can reshape Explore immediately
without repeating the expensive search for Taste Twins.

The algorithm therefore has two layers:

1. A comparatively expensive collaborative prediction based on ratings,
   similar users, visit context, and amenities.
2. A cheap local ranking layer that adds current interest matches and applies
   public-rating tie-breakers.

The 24-hour cache is like keeping yesterday's solved worksheet. CoFi can reuse
the collaborative answers while nothing meaningful has changed. If Ana submits
a new rating, the app does not throw that worksheet away and show a blank page.
It keeps displaying the previous results, marks them as outdated, and prepares
one replacement calculation in the background. This pattern is called
**stale-while-revalidate**.

If Ana reviews several cafés close together, each review advances an input
version. The short debounce combines rapid signals, and only one calculation is
allowed to run at a time. If another rating arrives during that calculation,
CoFi queues one follow-up so the final cache includes the newest version.

Reviews and business replies follow a different path. They are conversation
data, so Firestore streams update them while the relevant screen is open. A
business reply does not change Ana's rating vector and must not run cosine
similarity. This is why a reply can appear without a manual reload while the
recommendation cache remains untouched.

## Proof that CoFi uses explicit ratings

An **explicit rating** is a score the user deliberately supplies. In CoFi, it
is the selected star value held in `_rating`; it is not inferred from opening,
bookmarking, or visiting a café.

### 1. The user submits the rating

The review screen places `_rating` in the review document's `rating` field:

```dart
final reviewMap = {
  'userId': user.uid,
  'rating': _rating,
  // Other review fields...
};
```

- **[EXPLICIT-01]** Variable: `_rating`
- **[EXPLICIT-02]** Stored field: `reviewMap['rating']`
- **Code:** `lib/features/cafe/review_shop_screen.dart:171-180`

The complete `reviewMap` is written to
`shops/{shopId}/reviews/{reviewId}` through `batch.set(docRef, reviewMap)` at
`review_shop_screen.dart:181-192`.

### 2. The recommendation input requires a numeric rating

Before a review enters the rating vector, the service checks that its `rating`
field contains a number:

```dart
final shopId = review['shopId'] as String?;
if (shopId == null || review['rating'] is! num) continue;
```

- **[EXPLICIT-03]** Variable: `review`
- **[EXPLICIT-04]** Required explicit value: `review['rating']`
- **Code:** `lib/features/home/explore/services/recommendation_service.dart:213-221`

This is the main guard proving that a signal without a star rating is excluded
from collaborative filtering.

### 3. Firestore ratings become the similarity variables

The collection-group review read copies the stored field into each `signal`:

```dart
final signal = <String, dynamic>{
  'shopId': shopId,
  'rating': reviewData['rating'],
  'tags': ...,
};
```

- **[EXPLICIT-05]** Source variable: `reviewData['rating']`
- **[EXPLICIT-06]** Algorithm record: `signal['rating']`
- **Code:** `recommendation_service.dart:475-491`

For every café rated by both users, those explicit values become `xp` and
`yp`:

```dart
final double xp = (review1['rating'] as num?)?.toDouble() ?? 0.0;
final double yp = (review2['rating'] as num?)?.toDouble() ?? 0.0;
```

- **[EXPLICIT-07]** `xp`: first user's explicit rating **[SIM-07]**
- **[EXPLICIT-08]** `yp`: second user's explicit rating **[SIM-08]**
- **Code:** `recommendation_service.dart:326-334`

The cosine-similarity vector then starts with those ratings:

```dart
final double user1Score = xp + tp + ap;
final double user2Score = yp + tp + ap;
```

**Code:** `recommendation_service.dart:374-375`

### 4. Taste Twin ratings create the prediction

For an unseen café, the implementation reads the Taste Twin's explicit rating
into `rating` and weights it using `sim`:

```dart
final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
score += sim * rating;
totalSim += sim;
```

- **[EXPLICIT-09]** Variable: `rating` **[PRED-06]**
- **[EXPLICIT-10]** Weighted total: `score` **[PRED-07]**
- **Code:** `recommendation_service.dart:719-730`

The predicted rating is finally stored as `scores[shopId] = finalScore` at
`recommendation_service.dart:732-735`.

### 5. A visit is not treated as an explicit rating

Visit records contain `shopId` and `tags`, but the recommendation service does
not add a `rating` to them. A visit is merged only if `merged[shopId]` already
contains a genuine rated review:

```dart
final ratedCafe = shopId == null ? null : merged[shopId];
if (ratedCafe == null) continue;
```

- **[EXPLICIT-11]** Variable: `ratedCafe`
- **Code:** `recommendation_service.dart:224-232`

Therefore, star ratings are CoFi's primary **explicit-feedback signal**. Visit
tags and café amenities only add context to an existing rated-café comparison;
they cannot create a rating on their own.

## The formulas

### 1. User-to-user similarity

For every café `p` that both users rated:

```text
UserOneValue(p) = Xp + Tp + Ap
UserTwoValue(p) = Yp + Tp + Ap

Similarity =
  Σ(UserOneValue × UserTwoValue)
  ─────────────────────────────────────────────────────
  √Σ(UserOneValue²) × √Σ(UserTwoValue²)
```

Where:

- `Xp` is named `xp` in the code: the first user's 1–5 star rating
  **[SIM-07]**.
- `Yp` is named `yp` in the code: the second user's 1–5 star rating
  **[SIM-08]**.
- `Tp` is named `tp` in the code: the sum of shared visit-tag weights
  **[SIM-09]**.
- `Ap` is named `ap` in the code: the sum of the café's amenity weights
  **[SIM-10]**.
- `UserOneValue` is named `user1Score` in the code **[SIM-11]**.
- `UserTwoValue` is named `user2Score` in the code **[SIM-12]**.
- The top of the fraction is named `numerator` **[SIM-13]**.
- The bottom of the fraction is named `denominator` **[SIM-16]**.
- The calculated result is named `similarity` **[SIM-17]**.

The result is clamped between `0` and `1`. CoFi keeps candidates above `0.1`,
sorts them from most similar to least similar, and takes the top five.

### 2. Predicted café rating

```text
PredictedRating(café) =
  Σ(TasteTwinSimilarity × TasteTwinRating)
  ─────────────────────────────────────────
  Σ(TasteTwinSimilarity)
```

The predicted value is clamped to the public star-rating scale of `0–5`.

The exact variable form used by the implementation is:

```text
score    = score + (sim × rating)
totalSim = totalSim + sim
finalScore = clamp(score / totalSim, 0.0, 5.0)
scores[shopId] = finalScore
```

Here, `sim` is the Taste Twin's similarity **[PRED-05]**, `rating` is that
user's café rating **[PRED-06]**, `score` is the weighted-rating total
**[PRED-07]**, `totalSim` is the similarity total **[PRED-08]**, `finalScore`
is the predicted café rating **[PRED-09]**, and `scores` is the completed
`shopId`-to-prediction map **[PRED-10]**.

### 3. Final For You ordering

```text
InterestBonus(café) = ExactInterestMatchCount × 1.5

ForYouScore(café) = PredictedRating(café) + InterestBonus(café)
```

The exact Explore variables are:

```text
sa = _shopRecommendationScores[a.id] ?? 0.0
sb = _shopRecommendationScores[b.id] ?? 0.0

bonusA = getBonus(a, interests)
bonusB = getBonus(b, interests)

scoreA = sa + bonusA
scoreB = sb + bonusB
```

`sa` and `sb` are the two cached predictions being compared **[RANK-03]**;
`bonusA` and `bonusB` are their interest bonuses **[RANK-05]**; and `scoreA`
and `scoreB` are the final internal ranking values **[RANK-06]**.

If two cafés have the same `ForYouScore`, Explore prefers the café with the
higher public rating, then the one with more embedded review previews.

The `ForYouScore` is an internal ordering value. It is not shown to users as a
public star rating.

## Code tags and exact variable names

This guide uses tags such as **[SIM-01]** so a teacher, reviewer, or developer
can move from the explanation to the exact implementation. Line numbers refer
to the current implementation verified on August 28, 2026.

### Similarity formula variables

| Tag | Story/formula name | Exact code variable | Meaning | Code location |
|---|---|---|---|---|
| **[SIM-01]** | First user's reviews | `user1Reviews` | Rated-café signals supplied for the current user | `recommendation_service.dart:252` |
| **[SIM-02]** | Second user's reviews | `user2Reviews` | Rated-café signals supplied for the user being compared | `recommendation_service.dart:253` |
| **[SIM-03]** | Café amenities | `shopAmenities` | Map from each `shopId` to its café tags | `recommendation_service.dart:254` |
| **[SIM-04]** | Visit weights | `visitWeights` | `visitTagWeights` when supplied; otherwise `defaultVisitTagWeights` | `recommendation_service.dart:280` |
| **[SIM-05]** | Amenity weights | `amenityWeights` | `amenityTagWeights` when supplied; otherwise `defaultAmenityTagWeights` | `recommendation_service.dart:281` |
| **[SIM-06]** | Shared cafés | `commonShops` | Intersection of `user1Shops` and `user2Shops` | `recommendation_service.dart:303-305` |
| **[SIM-07]** | `Xp` | `xp` | First user's rating for the current shared `shopId` | `recommendation_service.dart:333` |
| **[SIM-08]** | `Yp` | `yp` | Second user's rating for the current shared `shopId` | `recommendation_service.dart:334` |
| **[SIM-09]** | `Tp` | `tp` | Sum of `visitWeights` for visit tags shared by both users | `recommendation_service.dart:342-353` |
| **[SIM-10]** | `Ap` | `ap` | Sum of `amenityWeights` for the café's amenities | `recommendation_service.dart:361-365` |
| **[SIM-11]** | First vector value | `user1Score` | `xp + tp + ap` | `recommendation_service.dart:374` |
| **[SIM-12]** | Second vector value | `user2Score` | `yp + tp + ap` | `recommendation_service.dart:375` |
| **[SIM-13]** | Dot-product total | `numerator` | Sum of `user1Score * user2Score` | `recommendation_service.dart:320,381` |
| **[SIM-14]** | First magnitude total | `sumUser1Squared` | Sum of `user1Score²` | `recommendation_service.dart:321,384` |
| **[SIM-15]** | Second magnitude total | `sumUser2Squared` | Sum of `user2Score²` | `recommendation_service.dart:322,385` |
| **[SIM-16]** | Magnitude product | `denominator` | `sqrt(sumUser1Squared) * sqrt(sumUser2Squared)` | `recommendation_service.dart:394-396` |
| **[SIM-17]** | Final similarity | `similarity` | `numerator / denominator`, later clamped to `0.0–1.0` | `recommendation_service.dart:404-411` |

In exact Dart variable names, the classroom formula is:

```text
user1Score = xp + tp + ap
user2Score = yp + tp + ap
similarity = numerator / denominator
```

### Taste Twin and predicted-rating variables

| Tag | Exact code variable | Meaning | Code location |
|---|---|---|---|
| **[TWIN-01]** | `currentUserCombined` | Current user's reviews with eligible visit tags merged in | `recommendation_service.dart:513-516` |
| **[TWIN-02]** | `otherUserCombined` | One candidate user's merged rated-café signals | `recommendation_service.dart:535-540` |
| **[TWIN-03]** | `similarityCandidates` | Users whose `similarity` is greater than `0.1` | `recommendation_service.dart:530-564` |
| **[TWIN-04]** | `topCandidates` | The five highest-similarity users | `recommendation_service.dart:569` |
| **[PRED-01]** | `similarUsers` | Taste Twins returned by `_findSimilarUsers(user)` | `recommendation_service.dart:652` |
| **[PRED-02]** | `userSimilarity` | Map of Taste Twin `userId` to similarity value | `recommendation_service.dart:674-677` |
| **[PRED-03]** | `currentShopSet` | Union of `currentBookmarks` and `currentVisited`; these cafés are skipped | `recommendation_service.dart:693-698` |
| **[PRED-04]** | `candidateReviews` | Reviews grouped by candidate `shopId` | `recommendation_service.dart:699-705` |
| **[PRED-05]** | `sim` | Similarity weight for the review author | `recommendation_service.dart:723` |
| **[PRED-06]** | `rating` | Taste Twin's star rating for the candidate café | `recommendation_service.dart:726` |
| **[PRED-07]** | `score` | Running numerator: `score += sim * rating` | `recommendation_service.dart:716,728` |
| **[PRED-08]** | `totalSim` | Running denominator: `totalSim += sim` | `recommendation_service.dart:717,729` |
| **[PRED-09]** | `finalScore` | Predicted rating: `(score / totalSim).clamp(0.0, 5.0)` | `recommendation_service.dart:734` |
| **[PRED-10]** | `scores` | Result map from `shopId` to `finalScore` | `recommendation_service.dart:708,735` |

### Final Explore ordering variables

| Tag | Exact code variable | Meaning | Code location |
|---|---|---|---|
| **[RANK-01]** | `_shopRecommendationScores` | Collaborative `scores` map held by Explore | `explore_tab.dart:111,272` |
| **[RANK-02]** | `_userInterests` | Current interests loaded from the user document | `explore_tab.dart:102,223` |
| **[RANK-03]** | `sa`, `sb` | Collaborative scores of cafés `a` and `b` | `explore_tab.dart:949-950` |
| **[RANK-04]** | `matchCount` | Number of exact café-tag/interests matches | `explore_tab.dart:957` |
| **[RANK-05]** | `bonusA`, `bonusB` | Interest bonuses returned by `getBonus` | `explore_tab.dart:961-962` |
| **[RANK-06]** | `scoreA`, `scoreB` | Final internal ordering values: collaborative score plus bonus | `explore_tab.dart:963-964` |
| **[RANK-07]** | `ra`, `rb` | Public-rating tie-breakers | `explore_tab.dart:970-976` |
| **[RANK-08]** | `ca`, `cb` | Embedded-review-count tie-breakers | `explore_tab.dart:979-981` |

Thus, the exact implemented final comparison is `scoreA = sa + bonusA` versus
`scoreB = sb + bonusB` **[RANK-06]**. The bonus itself is
`matchCount * 1.5` **[RANK-04]**.

### Cache and refresh-control variables

| Tag | Exact code variable | Meaning | Code location |
|---|---|---|---|
| **[CACHE-01]** | `recommendationCacheLifetime` | Cache lifetime of 24 hours | `recommendation_service.dart:86` |
| **[CACHE-02]** | `recommendationAlgorithmVersion` | Formula/cache compatibility number, currently `2` | `recommendation_service.dart:87` |
| **[CACHE-03]** | `staleScores` | Last usable cached map, retained during refresh/failure | `recommendation_service.dart:615` |
| **[CACHE-04]** | `inputVersionAtStart` | Input version captured before calculation begins | `recommendation_service.dart:647` |
| **[CACHE-05]** | `latestInputVersion` | Input version checked after a successful calculation | `recommendation_service.dart:765` |
| **[FLOW-01]** | `recommendationVersion` | Cross-screen signal for changed rating-context inputs | `app_signals.dart:9,16-18` |
| **[FLOW-02]** | `interestsVersion` | Separate signal that only reloads interests and re-sorts | `app_signals.dart:14,20-22` |
| **[FLOW-03]** | `_recommendationRequestId` | Prevents an older async result from replacing a newer one | `explore_tab.dart:113,260,268` |
| **[FLOW-04]** | `_recommendationDebounce` | Holds the two-second debounce timer | `explore_tab.dart:114,286-292` |
| **[FLOW-05]** | `_recommendationRefreshRunning` | Enforces one active collaborative refresh | `explore_tab.dart:115,297,309-320` |
| **[FLOW-06]** | `_recommendationRefreshQueued` | Requests one follow-up when input changes during a run | `explore_tab.dart:116,298,312-318` |
| **[FLOW-07]** | `_recommendationSignalPending` | Records an unprocessed recommendation signal | `explore_tab.dart:117,196,304-318` |

The write-side tags are: a review calls `markInputsChanged(...)` and
`notifyRecommendationInputsChanged()` at `review_shop_screen.dart:212-216`; an
eligible rated-café visit uses the same path at `log_visit_screen.dart:95-115`;
and an interest edit calls `notifyInterestsChanged()` at
`interest_selection_screen.dart:217-219`.

## What data enters the algorithm

| Data | Firestore location | Role |
|---|---|---|
| Star rating | `shops/{shopId}/reviews/{reviewId}.rating` | Primary collaborative signal |
| Review visit tags | `shops/{shopId}/reviews/{reviewId}.tags` | Context for rated cafés |
| Logged visit tags | `shops/{shopId}/visits/{visitId}.tags` | Merged only when the same café also has a rating |
| Café amenities | `shops/{shopId}.tags` | Contextual amenity weight |
| User interests | `users/{uid}.interests` | Local Explore bonus, outside cached prediction |
| Bookmarked/visited IDs | `users/{uid}` | Prevents recommending already-known cafés |
| Public rating/review count | Café document | Tie-breakers and fallback ranking |

An unrated standalone visit does not become a fake zero-star review. It updates
visit history immediately, but does not affect cosine similarity until there is
a genuine rating for that café.

## Where the code is located

| Responsibility | File |
|---|---|
| Weights, signal merging, cosine similarity, Taste Twins, prediction, cache policy | `lib/features/home/explore/services/recommendation_service.dart` |
| Explore startup, debouncing, one-at-a-time refresh, filters, and final sorting | `lib/features/home/explore_tab.dart` |
| Cross-screen recommendation and interest signals | `lib/utils/app_signals.dart` |
| Review submission and recommendation-input version update | `lib/features/cafe/review_shop_screen.dart` |
| Visit submission and rated-visit eligibility check | `lib/features/cafe/log_visit_screen.dart` |
| Interest saving and interest-only Explore refresh | `lib/features/auth/interest_selection_screen.dart` |
| Business Guest Feedback real-time review/reply stream | `lib/features/cafe/reviews_screen.dart` |
| Customer café-detail real-time recent-review/reply stream | `lib/features/cafe/cafe_details_screen.dart` |
| Business response write/edit/delete flow | `lib/features/business/response_review_bottom_sheet.dart` and `lib/features/cafe/reviews_screen.dart` |
| Review aggregate backend | `firebase/functions/src/syncReviewAggregates.ts` |
| Collection-group read permissions | `firebase/firestore.rules` |
| Algorithm and cache-policy tests | `test/algorithm_test.dart` |

## How a calculation moves through the code

```mermaid
flowchart TD
    A[Explore opens] --> B[Read cached prediction map]
    B --> C{Cache exists?}
    C -->|No| D[Calculate collaborative scores]
    C -->|Yes| E[Show cache immediately]
    E --> F{Dirty, expired, or old formula?}
    F -->|No| G[No expensive work]
    F -->|Yes| H[Debounce background revalidation]
    D --> I[Load rating and visit signals]
    H --> I
    I --> J[Calculate cosine similarity]
    J --> K[Keep top 5 Taste Twins]
    K --> L[Predict unseen café ratings]
    L --> M[Replace cache only after success]
    G --> N[Add current interest bonus]
    M --> N
    N --> O[Sort and render Explore cards]
```

`ExploreTab.initState()` first requests recommendation scores. A fresh,
compatible cache returns immediately. A stale cache also returns immediately,
but `RecommendationService.shouldRevalidate()` tells Explore to schedule a
background replacement. If no cache exists, the initial calculation runs while
the normal café stream can still provide fallback cards.

`RecommendationService._findSimilarUsers()` reads the ranked café set, review
signals, visit signals, and relevant amenities. It builds the current user's
vector and other-user vectors, calculates similarity, keeps the top five, and
loads those users' display names for diagnostics.

`RecommendationService.loadRecommendationScores()` then reads candidate café
ratings from those Taste Twins. It creates a map shaped like:

```text
{
  "shopA": 4.20,
  "shopB": 3.85
}
```

Explore stores this map in `_shopRecommendationScores`. During `_applyFilters`,
it retrieves each café's collaborative value, counts exact matches between the
café tags and `_userInterests`, adds `1.5` per match, and sorts the cards.

## The 24-hour cache

The recommendation cache is stored locally with `GetStorage` and is scoped by
Firebase UID. It is not a Firestore collection and is not shared across devices.

The cache records:

```text
shop_recommendations_{uid}         predicted-rating map
shop_rec_timestamp_{uid}           successful generation time
shop_rec_input_version_{uid}       latest rating-context input version
shop_rec_calculated_version_{uid}  version used by the last success
shop_rec_dirty_{uid}               whether newer input exists
shop_rec_algorithm_version_{uid}   formula/cache compatibility version
shop_rec_last_attempt_{uid}        most recent calculation attempt
```

A cache needs revalidation when it is missing, at least 24 hours old, marked
dirty, or produced by an older algorithm version. Dirty or expired results can
still be shown while replacement scores are calculated.

On success, CoFi stores the new scores and timestamp. It clears `dirty` only if
the input version has not changed during the calculation. On failure, CoFi
keeps the old scores and leaves the cache eligible for a later retry.

## Exact behavior for common actions

| Action | Immediate behavior | Collaborative calculation |
|---|---|---|
| Open Explore with unchanged cache under 24 hours | Show cache | None |
| Scroll, rebuild, filter, or switch tabs | Local UI work | None |
| Pull to refresh with unchanged inputs | Refresh lightweight data and reuse cache | None |
| Change interests | Fetch interests and re-sort locally | None |
| Submit a star-rated review | Publish review, mark visited, keep old feed visible | Debounced background calculation |
| Submit several rapid reviews | Save every review and advance input versions | Coalesced; never parallel |
| Log an unrated visit | Update visit state | None |
| Add visit context to a rated café | Update visit state | Debounced background calculation |
| Business replies to a review | Stream reply into visible review document | None |
| Another user posts a review | Stream review and public aggregates where observed | No global invalidation of every user's cache |
| Cache reaches 24 hours | Keep stale results visible | Background revalidation |

## Why reviews and replies do not need reload

`ReviewsScreen` listens to the selected café's `reviews` subcollection. The
café-detail screen also listens to its recent reviews. Responses are stored in
the review document's `responses` field, so adding, editing, or deleting a
response modifies a document those screens already observe. Firestore emits the
new snapshot and Flutter rebuilds the affected cards.

These listeners exist only while their widgets are mounted. When a user leaves
the screen, Flutter disposes the stream subscription. Reopening the screen
creates a listener that first receives the current stored data.

## Documentation compliance versus engineering decisions

The project paper requires explicit ratings as the main input, cosine
similarity for collaborative filtering, contextual visit/amenity weights, and a
dynamic Explore experience where recorded activity is reflected promptly. The
implemented formula preserves those requirements.

The paper does not prescribe a 24-hour duration, input-version keys, a two-second
debounce, or stale-while-revalidate. Those are engineering decisions used to
meet the paper's visible behavior without running the expensive algorithm on
every screen rebuild or pull gesture.

## Current limitation and future scaling work

The current collaborative pass still uses collection-group reads for reviews
and visits and filters them locally. This is much safer now because passive UI
actions do not trigger recalculation, but the query cost will still grow with
the database. The next scaling step should materialize per-user rating vectors
or server-generated recommendation inputs so a client does not need to scan
global signal collections.

Any future formula change must increment
`RecommendationService.recommendationAlgorithmVersion`, update the tests, and
update this guide. Otherwise an old locally cached score map could be treated as
compatible with a new formula.

## One-paragraph presentation answer

CoFi uses a hybrid recommendation algorithm. It compares users who rated the
same cafés through cosine similarity, keeping star ratings as the primary
signal and using visit tags and amenities as contextual weights. Ratings from
the five strongest Taste Twins predict how much the current user may like
unseen cafés. Explore then adds a lightweight bonus for exact interest matches
and uses public ratings as tie-breakers. Collaborative predictions are cached
locally for up to 24 hours; meaningful rating changes mark them outdated and
cause one controlled background replacement, while interests, live reviews,
and business replies update without requiring a manual reload.
