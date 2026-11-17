# KPIs: how to read them in Firebase

Targets: **D1 ≥ 35%**, **D7 ≥ 14%**, **blended ARPDAU ≥ $0.08**.

## 1. Events and parameters (source of truth: `lib/services/analytics/game_analytics.dart`)

| Event | Parameters | Use |
| --- | --- | --- |
| `level_start` | level, kind, attempt | funnel, attempts per level |
| `level_complete` | level, moves, optimal_moves, stars, duration_s, boosters_used | difficulty tuning |
| `level_fail` | level, reason (stuck / dead_end / out_of_moves / quit), moves, duration_s | churn points |
| `level_restart` | level, moves | frustration signal |
| `booster_used` | type, source (free / coins / ad / inventory), level | booster economy |
| `ad_request` / `ad_loaded` | format, placement | fill rate |
| `ad_impression` | format, placement, network, value_micros, currency, value | **ad revenue** |
| `ad_reward_granted` | placement | rewarded completion |
| `ad_failed` | format, placement, error | no-fill and errors |
| `iap_view` / `iap_purchase` / `iap_failed` | placement / product_id, price, currency, value / status | IAP funnel |
| `coins_earned` / `coins_spent` | amount, source / sink | economy balance |
| `bazaar_item_restored`, `area_complete` | item, area, cost / area, levels_played | meta progress |
| `daily_reward_claimed`, `daily_challenge_complete` | day, coins / streak, moves | daily habit |
| `tutorial_step` | step, level | onboarding funnel |
| `consent_result` | result (personalization_tracking) | consent rates |
| `settings_changed` | setting, value | |

**User properties:** `install_country_tier` (tier1/2/3), `payer` (yes/no), `ad_free` (yes/no), `exp_group` (from Remote Config).

**Before reading anything:** in Firebase → Custom definitions, register the numeric parameters (`level`, `moves`, `optimal_moves`, `stars`, `duration_s`, `value_micros`, `amount`) as custom metrics, the string parameters (`placement`, `format`, `network`, `source`, `sink`, `reason`, `kind`, `product_id`) as custom dimensions, and all four user properties.

## 2. Retention (D1 / D7)

- **Firebase console → Analytics → Retention** shows the cohort table by install week. Read the *Day 1* and *Day 7* columns.
- For daily cohorts or splitting by country, link **BigQuery** (Project settings → Integrations) and run:

```sql
-- D1/D7 retention by install date and country tier
WITH installs AS (
  SELECT user_pseudo_id,
         DATE(TIMESTAMP_MICROS(user_first_touch_timestamp)) AS install_date,
         ANY_VALUE((SELECT value.string_value FROM UNNEST(user_properties)
                    WHERE key = 'install_country_tier')) AS tier
  FROM `PROJECT.analytics_XXXX.events_*`
  GROUP BY 1, 2
), active AS (
  SELECT DISTINCT user_pseudo_id, PARSE_DATE('%Y%m%d', event_date) AS d
  FROM `PROJECT.analytics_XXXX.events_*`
)
SELECT install_date, tier, COUNT(DISTINCT i.user_pseudo_id) AS installs,
  SAFE_DIVIDE(COUNT(DISTINCT IF(DATE_DIFF(a.d, install_date, DAY) = 1, a.user_pseudo_id, NULL)),
              COUNT(DISTINCT i.user_pseudo_id)) AS d1,
  SAFE_DIVIDE(COUNT(DISTINCT IF(DATE_DIFF(a.d, install_date, DAY) = 7, a.user_pseudo_id, NULL)),
              COUNT(DISTINCT i.user_pseudo_id)) AS d7
FROM installs i LEFT JOIN active a USING (user_pseudo_id)
GROUP BY 1, 2 ORDER BY 1 DESC, 2;
```

**Reading it:** if D1 is low, look at the tutorial funnel (`tutorial_step`, and `level_complete` for levels 1–10), consent drop-off, and cold-start crashes. If D7 is low, check difficulty spikes (`level_fail` rate per level), whether the meta loop is working (`bazaar_item_restored` per user) and daily habit (`daily_reward_claimed`).

## 3. ARPDAU

ARPDAU = (ad revenue + IAP revenue) / daily active users, per day.

- **Ad revenue:** use the AdMob → Firebase link (the `ad_impression` event from the AdMob SDK carries the paid-event revenue) or our own `ad_impression` events (`value` = USD-equivalent of `value_micros`). Sum `value` per day.
- **IAP revenue:** `in_app_purchase` (automatic) or our `iap_purchase` events (`value`). RevenueCat's dashboard is the source of truth for net revenue after store fees and refunds.
- **DAU:** Analytics → Dashboard → *Active users* (1-day).

```sql
SELECT PARSE_DATE('%Y%m%d', event_date) AS day,
  SUM(IF(event_name = 'ad_impression', (SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'value'), 0)) AS ad_rev,
  SUM(IF(event_name = 'iap_purchase', (SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'value'), 0)) AS iap_rev_gross,
  COUNT(DISTINCT user_pseudo_id) AS dau,
  SAFE_DIVIDE(SUM(IF(event_name IN ('ad_impression','iap_purchase'),
      (SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'value'), 0)),
    COUNT(DISTINCT user_pseudo_id)) AS arpdau
FROM `PROJECT.analytics_XXXX.events_*`
GROUP BY 1 ORDER BY 1 DESC;
```

Use gross IAP here for a fast read. Multiply by about 0.70–0.85 for net, depending on the store and the small-business programme.

## 4. Ad revenue per placement

Explorations → Free form: rows = `placement`, columns = `format`, values = sum of `value` and event count of `ad_impression`. Add `network` to see mediation performance.

| Placement | Format | Healthy sign |
| --- | --- | --- |
| `level_complete` | interstitial | ~0.3–0.5 per level completed (pacing) |
| `hint`, `extra_shelf`, `undo_refill`, `shuffle`, `extra_moves` | rewarded | opt-in rate ≥ 15% of stuck players |
| `double_coins` | rewarded | ≥ 25% of wins |
| `daily_spin` | rewarded | ≥ 40% of daily users |
| `bazaar` | banner (experiment only) | only if it doesn't hurt D7 |

**Fill rate** = `ad_loaded` / `ad_request` per format. Rewarded fill under 90% in Tier-1 means the mediation waterfall needs work.

## 5. Experiments (Remote Config A/B testing)

1. Firebase → Remote Config → A/B testing → create an experiment on one or more keys from `remote_config_defaults.dart`.
2. Set `exp_group` to a different value in each variant (for example `int_gap_2` / `int_gap_3`). It becomes a user property, so every report can be split by it.
3. Use **D7 retention** as the primary metric, plus ad revenue and purchase revenue. Run at least 7 days and only conclude at ≥ 95% probability.

Good first experiments:
- `ads_interstitial_level_gap_min` / `_max` (2–3 vs 3–4)
- `iap_starter_hours` (24 vs 48 vs 72)
- `eco_price_extra_shelf` (90 vs 120 vs 150)
- `difficulty_curve_json` with `{"typesGrowthLevels": 350}`, a gentler ramp

## 6. Stability

Crashlytics → Dashboard → **crash-free users** (target ≥ 99.5%). Non-fatal errors are recorded with reasons (`level_load`, `save_decode`, `startup_*`, `purchase *`) and can be filtered under *Non-fatals*.
