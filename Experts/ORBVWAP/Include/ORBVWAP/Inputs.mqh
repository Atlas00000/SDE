//+------------------------------------------------------------------+
//| Inputs.mqh                                                       |
//| Default values = PROD v3 (ORBVWAP_PROD_EURUSD-M1.set)            |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_INPUTS_MQH__
#define __ORBVWAP_INPUTS_MQH__

#include "Types.mqh"
#include "Constants.mqh"

input group "=== General ==="
input long   InpMagicNumber   = ORBVWAP_DEFAULT_MAGIC;
input bool   InpEnableTrading = true;

input group "=== Session (GMT) ==="
input int    InpGmtOffsetHours    = 2;     // Broker hours ahead of GMT
input int    InpLondonStartHour   = 7;
input int    InpLondonEndHour     = 12;
input int    InpNyStartHour       = 13;
input int    InpNyEndHour         = 17;
input ENUM_ORBVWAP_ACTIVE_SESSION InpActiveSession = ORBVWAP_ACTIVE_BOTH;
input int    InpNoEntryAfterHour  = 16;    // P2B-004: 0=off, block entries at/after GMT hour
input int    InpSkipWeekdays      = 40;    // P2B-005: GMT weekday bitmask to skip (Sun=1<<0 .. Sat=1<<6); Wed+Fri=40
input int    InpNyEntryDelayMin   = 30;     // P4B-001/PROD v3: 0=off, block NY entries for N min after NY open (GMT)
input int    InpLondonEntryDelayMin = 0;   // P4B-002: 0=off, block London entries for N min after London open (GMT)

input group "=== Opening Range ==="
input int    InpRangeMinutes        = 5;
input int    InpMaxBarsAfterLock    = 0;     // P4B-003/P2B-006: 0=off, breakout within N M1 bars of lock
input double InpMinRangeAtrFactor   = 0.8;
input double InpTpRangeMult         = 1.0;    // P2-003: TP = entry +/- mult x range width
input ENUM_ORBVWAP_SL_MODE InpSlMode = ORBVWAP_SL_OPPOSITE; // P2-001: opposite boundary vs midpoint

input group "=== Execution ==="
input bool   InpTestExecution     = false;   // Dev only: one test order on first bar
input uint   InpSlippagePoints    = 10;
input int    InpMaxSpreadPoints   = 30;

input group "=== Risk ==="
input ENUM_ORBVWAP_SIZING_MODE      InpSizingMode      = ORBVWAP_SIZING_FIXED_LOT;
input double InpFixedLot            = 0.01;
input double InpRiskPercent         = 1.0;
input ENUM_ORBVWAP_SLTP_MODE        InpSltpMode        = ORBVWAP_SLTP_STRATEGY_NATIVE;
input int    InpStopLossPoints      = 50;
input int    InpTakeProfitPoints    = 50;
input double InpSlAtrMult           = 1.5;
input double InpTpAtrMult           = 1.0;
input int    InpMaxOpenTrades       = 1;
input int    InpCooldownSeconds     = 60;
input ENUM_ORBVWAP_TRADE_PERMISSION InpTradePermission = ORBVWAP_TRADE_BOTH;
input double InpMinEquityRatio      = 0.8;
input int    InpMaxHoldMinutes      = 120;   // P2-005: 0=off, close at market after N minutes
input double InpBeTrigger           = 0.0;   // P2-006: 0=off, move SL to entry at mult x range_width profit
input double InpMinRR               = 0.9;   // P2-004: 0=off, minimum TP distance / SL distance at entry
input double InpPartialClosePct     = 0.0;   // P4A: 0=off, close this % at partial level
input double InpPartialAtRangeMult  = 1.0;   // P4A: partial trigger at N x range width
input double InpRunnerTpRangeMult   = 0.0;   // P4A: 0=off, runner TP at N x range (after partial)
input double InpTrailAtr            = 0.0;   // P4A-003/P2-007: 0=off, trail runner SL by N x ATR after partial

input group "=== Indicators ==="
input int    InpAtrPeriod           = 14;
input int    InpVolumeMaPeriod      = 20;
input double InpVolumeMultiplier    = 1.5;
input int    InpAtrSlowPeriod       = 50;    // P2C-004 slow ATR period
input int    InpAdxPeriod           = 14;    // P2C-003 ADX period on M15

input group "=== Entry filters (P2C) ==="
input int    InpD1EmaPeriod         = 0;     // P2C-001: 0=off, D1 EMA bias
input int    InpH4SwingPivotBars    = 0;     // P2C-002: 0=off, H4 pivot width
input double InpAdxMax              = 0.0;   // P2C-003: 0=off, M15 ADX must be below
input double InpAtrExpMax           = 0.0;   // P2C-004: 0=off, ATR/ATRslow max ratio
input double InpMaxSpreadPctRange   = 20.0;  // P2C-005: 0=off, max spread % of range
input double InpVolMaxMult          = 0.0;   // P2C-006: 0=off, block vol spike above mult x MA
input double InpMaxVwapDistAtr      = 0.0;   // P2C-007: 0=off, max |close-vwap| in ATR units

input group "=== Circuit breakers (P2D) ==="
input double InpDailyLossPct        = 0.0;   // P2D-001: 0=off, halt if day loss >= pct of day-start equity
input int    InpConsecLossMax       = 0;     // P2D-002: 0=off, consecutive closed losses before pause
input int    InpConsecLossPauseMin  = 120;   // P2D-002: pause duration (minutes)
input double InpEqTrailPct          = 0.0;   // P2D-004: 0=off, halt if equity drops pct from day peak

input group "=== AI export (AI-0) ==="
input bool   InpEnableDecisionExport = false;  // AI-0: write ORBVWAP_decisions.csv + outcomes
input bool   InpEnableFeatureParityExport = false; // INF-4: append feat_* columns to decisions CSV
input bool   InpEnableAiShadowLog    = false;  // INF-1: write ORBVWAP_ai_shadow.csv

input group "=== AI Layer 1 (AI-1) ==="
input ENUM_ORBVWAP_AI_GATE_MODE InpAiGateMode = ORBVWAP_AI_OFF; // OFF / SHADOW (log) / LIVE (block)
input double InpAiMinScore       = 0.0;      // Min score to take; 0 = use model tau (protection mode)

input group "=== AI Layer 2 (AI-2) ==="
input ENUM_ORBVWAP_AI_SIZE_MODE InpAiSizeMode = ORBVWAP_AI_SIZE_OFF; // OFF / SHADOW (log) / LIVE (scale lot)

input group "=== AI Layer 3 (AI-3) ==="
input ENUM_ORBVWAP_AI_REGIME_MODE InpAiRegimeMode = ORBVWAP_AI_REGIME_OFF; // OFF / SHADOW / LIVE (skip session)

input group "=== AI Layer 4 (AI-4) ==="
input ENUM_ORBVWAP_AI_EXIT_MODE InpAiExitMode = ORBVWAP_AI_EXIT_OFF; // OFF / SHADOW / LIVE (stall scratch)
input bool   InpEnablePathExport  = false;   // AI-4: write ORBVWAP_paths.csv on close

input group "=== Debug ==="
input bool   InpEnableFileJournal   = false;
input bool   InpLogSessionState     = false;

#endif // __ORBVWAP_INPUTS_MQH__
