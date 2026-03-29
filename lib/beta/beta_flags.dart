// lib/beta/beta_flags.dart
// β branch feature flags
// kBetaFeatures: compile-time gate — false on α branch (set all below to false).
// Individual flags are ALSO controlled at runtime via AppSettings.betaXxx fields.
// Use the beta* helpers (which take AppSettings) throughout the app.

import '../models/models.dart'; // must be before any declarations

// ── Compile-time gates (set false to dead-code-eliminate on α branch) ────────
const bool kBetaFeatures        = true;
const bool kFeatureUsageStats   = kBetaFeatures;
const bool kFeatureTaskGravity  = kBetaFeatures;
const bool kFeatureSmartPlan        = kBetaFeatures;
const bool kFeatureStatsNewUI       = kBetaFeatures;
const bool kFeatureDeepFocusAnalysis = kBetaFeatures;
const bool kFeatureAmbientFx        = kBetaFeatures;
const bool kFeatureWeather          = kBetaFeatures;
const bool kFeaturePersistNotif     = kBetaFeatures;

// ── Runtime helpers ───────────────────────────────────────────────────────────
bool betaUsageStats(AppSettings s)        => kFeatureUsageStats         && s.betaUsageStats;
bool betaTaskGravity(AppSettings s)       => kFeatureTaskGravity        && s.betaTaskGravity;
bool betaSmartPlan(AppSettings s)         => kFeatureSmartPlan          && s.betaSmartPlan;
bool betaStatsNewUI(AppSettings s)        => kFeatureStatsNewUI         && s.betaStatsNewUI;
bool betaDeepFocusAnalysis(AppSettings s) => kFeatureDeepFocusAnalysis  && s.betaDeepFocusAnalysis;
bool betaAmbientFx(AppSettings s)         => kFeatureAmbientFx          && s.betaAmbientFx;
bool betaWeather(AppSettings s)           => kFeatureWeather             && s.betaWeather;
bool betaPersistNotif(AppSettings s)      => kFeaturePersistNotif        && s.betaPersistNotif;
