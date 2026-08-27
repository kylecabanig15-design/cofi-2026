# Explore Recommendation Changes

## Purpose

This document explains the difference between the previous Explore recommendation flow and the optimized implementation. The change aligns the application more closely with the documented behavior: preferences and community activity should update the dynamic Explore feed without requiring a manual reload.

## Before and After

| Area | Previous behavior | New behavior |
|---|---|---|
| Explore loading | Recommendation data was loaded through many sequential Firestore requests. | Recommendation signals are loaded using a small number of bulk collection-group requests. |
| Firestore requests | A refresh could issue approximately 120–220 requests, including separate review and visit requests for each café. | Reviews and visits are fetched in bulk, candidate reviews are fetched once, and only the top similar-user profiles are loaded. |
| Request execution | Most café queries waited for the previous query to finish. | Independent signal and profile requests execute concurrently. |
| Pull-to-refresh | Always bypassed the cache and waited for a complete collaborative-filtering rebuild. | Uses live Firestore streams and the existing cache, avoiding an unnecessary blocking rebuild. |
| Visible feed during refresh | The refresh gesture could remain active while the full algorithm ran. | Existing café results remain visible while scores update in the background. |
| Interest changes | Firestore saved interests but Explore could keep old local ordering. | Saving interests keeps collaborative scores and immediately re-sorts with the new local interest bonus. |
| Manual reload after changing interests | Sometimes required to see the complete updated ranking. | Not required. Explore listens to the user document and updates the interest-based ranking automatically. |
| Overlapping refreshes | Older computations could finish later and replace newer results. | Input versions, a debounce, and one-at-a-time execution coalesce changes and protect newer results. |
| Users with sparse data | An empty recommendation result was not cached, so the expensive calculation could repeat. | Valid empty results are cached to avoid unnecessary repeated work. |
| Error diagnostics | Recommendation failures produced one generic `_findSimilarUsers` error. | Errors identify the exact query stage, such as loading shops, signals, or profiles. |

## Previous Refresh Flow

```text
Pull to refresh
    -> ignore the 24-hour cache
    -> load 30 shops
    -> query reviews for each shop one at a time
    -> query visits for each shop one at a time
    -> repeat review and visit queries for collaborative data
    -> load similar-user profiles one at a time
    -> load up to 100 candidate shops
    -> query reviews for each candidate shop one at a time
    -> calculate scores
    -> update Explore
```

The number of network round trips increased with the number of cafés. Because the requests were largely sequential, network latency accumulated even when individual Firestore requests were fast.

## New Refresh Flow

```text
Open or refresh Explore
    -> show the current live café stream immediately
    -> use the valid recommendation cache when available
    -> load ranked shops
    -> bulk-load review and visit signals concurrently when recomputation is needed
    -> calculate similarity locally
    -> load only the top five similar-user profiles concurrently
    -> bulk-load candidate reviews once
    -> calculate and cache scores
    -> apply the newest result without replacing the visible feed while waiting
```

## Preference Update Flow

```text
User saves new interests
    -> update users/{uid}.interests in Firestore
    -> keep that user's collaborative recommendation cache
    -> increment the interest-only app signal
    -> Explore fetches the new interests
    -> apply the interest-to-shop-tag ranking bonus immediately
    -> do not recompute cosine similarity
```

The user does not need to close, reopen, or manually reload Explore after changing interests.

## Ranking Behavior

The optimization does not change the documented recommendation formula. The `For You` ranking still combines:

1. Explicit café ratings as the primary collaborative-filtering input.
2. Cosine similarity between users with common rated cafés.
3. Visit tags and café amenities as contextual weights.
4. Predicted scores from similar users' ratings.
5. A direct interest bonus for matches between saved interests and café tags.
6. Rating and review count as fallback ordering values.

## Cache Behavior

- Recommendation scores remain cached for up to 24 hours during normal browsing.
- Pull-to-refresh no longer discards a valid cache.
- Rating-context changes persist a dirty input version and use `recommendationVersion` to request a coalesced background recalculation.
- Changing interests keeps the collaborative cache and uses `interestsVersion` for local re-ranking.
- Unrated standalone visits update visit history without paying for a no-op collaborative pass.
- Empty results are cached as valid results for users who do not yet have enough collaborative data.

## Files Changed

- `lib/features/home/explore/services/recommendation_service.dart`
  - Bulk signal loading, concurrent profile loading, candidate-review reuse, empty-result caching, cache invalidation, and query-stage diagnostics.
- `lib/features/home/explore_tab.dart`
  - Cache-friendly pull-to-refresh, background refresh behavior, automatic interest reload, and stale-request protection.
- `lib/features/auth/interest_selection_screen.dart`
  - Interest-only Explore notification without collaborative-cache invalidation.
- `lib/utils/app_signals.dart`
  - Separates rating-context refreshes from interest-only refreshes.

## Expected Result

- Explore becomes interactive sooner.
- Pull-to-refresh completes quickly when cached scores are valid.
- Preference changes reorder the feed automatically.
- Existing café cards remain visible during recommendation recomputation.
- Firestore round-trip latency is substantially reduced.
- The implementation better matches the documentation's description of an up-to-date dynamic Explore feed.
