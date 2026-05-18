//+------------------------------------------------------------------+
//| VEM_Config.mqh                                                   |
//| Phase 1 inputs — grouped; safe vs structural per concept.md    |
//+------------------------------------------------------------------+
#ifndef VEM_CONFIG_MQH
#define VEM_CONFIG_MQH

enum ENUM_VEM_TRADE_DIRECTION
  {
   VEM_TRADE_BOTH = 0,
   VEM_TRADE_LONG_ONLY,
   VEM_TRADE_SHORT_ONLY
  };

enum ENUM_VEM_TP_MODE
  {
   VEM_TP_FIXED_RR = 0,
   VEM_TP_FIXED_POINTS,
   VEM_TP_BB_MIDLINE_ONLY
  };

enum ENUM_VEM_SL_MODE
  {
   VEM_SL_FIXED_POINTS = 0,
   VEM_SL_ATR
  };

enum ENUM_VEM_FAIL_EXIT_MODE
  {
   VEM_FAIL_EXIT_OFF = 0,
   VEM_FAIL_EXIT_E8A = 1,     // low MFE and/or still outside BB after N bars
   VEM_FAIL_EXIT_E8B = 2      // position still in loss after N bars
  };

//=== Structural / operational =====================================
input group "Structural"
input long             inp_magic                 = 2600511;
input string           inp_trade_comment         = "VEM";
input ENUM_VEM_TRADE_DIRECTION inp_direction   = VEM_TRADE_BOTH;
input bool             inp_log_verbose           = false;

//=== Signal bar model ===============================================
input group "Signal bar"
input int              inp_signal_shift          = 1;       // closed bar (1 = last closed)

//=== Indicators =====================================================
// Defaults below favour M1–M5: faster bands, easier RSI extremes, lighter volume filter.
// For H1+ mean reversion, raise inp_rsi_ob / lower inp_rsi_os, raise inp_bb_dev, raise inp_vol_spike_mult.
input group "Bollinger Bands"
input int              inp_bb_period             = 14;
input double           inp_bb_dev                = 1.8;

input group "RSI"
input int              inp_rsi_period            = 9;
input double           inp_rsi_ob                = 62.0;
input double           inp_rsi_os                = 38.0;

input group "Volume spike"
input int              inp_vol_ma_period         = 12;
input double           inp_vol_spike_mult        = 1.15;

input group "BB touch / pierce"
input double           inp_bb_penetration_pts    = 0.0;    // long: Low <= Lower - pts*point

//=== Risk gates =====================================================
input group "Risk gates"
input int              inp_max_spread_pts        = 80;
input int              inp_max_positions_total   = 2;
input int              inp_cooldown_bars         = 0;
input double           inp_max_dd_pct            = 0.0;     // 0 = off; block if (Bal-Equity)/Bal*100 exceeds

//=== Session filter (Step D1 — habitat) ===========================
// Hypothesis: mean reversion fails during NY overlap (server hours 13–15).
// D5 2026-05-16: keep — IS/OOS beat baseline on net $ and DD (see baseline-eurusd-m5-20260516.md).
// Default OFF so vem5m.set reproduces Step A baseline; use vem5m_d1_session.set with enable=true.
input group "Session filter"
input bool             inp_session_filter_enable = false;
input int              inp_block_hour_start       = 13;      // inclusive, server time
input int              inp_block_hour_end         = 15;      // inclusive, server time

//=== BB width filter (Step D6 — habitat) ==========================
// Hypothesis: wide bands = continuation/noise; block entries above width ratio.
// Ratio = (BB upper - lower) / middle on signal bar. Calibrated p66.7 on OOS bars (~0.00165).
// D6 OOS 2026-05-16: keep with session — 373 tr / -$4.58 vs session-only 701 / -$13.69.
// Default OFF; stack on session via vem5m_d6_session_bbwidth.set.
input group "BB width filter"
input bool             inp_bb_width_filter_enable = false;
input double           inp_bb_max_width_ratio     = 0.00165; // block if ratio > this; 0 with filter off

//=== RSI depth filter (Step D7 — habitat) =========================
// Hypothesis: shallow band touches fail — need deeper OS (long) / OB (short) at signal bar.
// B5: longs 25-30 and shorts 70-75/75-80 worst; deep_<20 and >=75-80 better.
// Default OFF; stack on D6 via vem5m_d7_session_bb_rsi.set.
input group "RSI depth filter"
input bool             inp_rsi_depth_filter_enable = false;
input bool             inp_rsi_depth_long_enable  = true;   // if false, no long depth gate
input bool             inp_rsi_depth_short_enable = true;   // if false, no short depth gate
input double           inp_rsi_long_max_depth      = 25.0;   // long: signal RSI must be <= this
input double           inp_rsi_short_min_depth     = 75.0;   // short: signal RSI must be >= this

//=== EMA slope filter (Step D8 — regime) ==========================
// Hypothesis: fading strong directional drift (BB walk) loses — block "against" trend entries.
// Slope bp = (EMA[signal] - EMA[signal+lookback]) / EMA[signal+lookback] * 10000 (matches Step B1).
// Block long if slope < -block_bp; block short if slope > +block_bp.
// Default OFF; stack on D7 via vem5m_d8_d7_ema_slope.set.
input group "EMA slope filter"
input bool             inp_ema_slope_filter_enable   = false;
input int              inp_ema_period                = 20;    // EMA on signal TF (B1 used 20)
input int              inp_ema_slope_lookback_bars   = 5;     // bars between EMA samples
input double           inp_ema_slope_block_bp        = 5.0;   // min |slope| to block fade-against-trend

//=== BB walk filter (Step D9 — regime) ============================
// Hypothesis: N consecutive closes outside same band = momentum walk — skip fade entry.
// Long: block if close < BB lower for N bars back from signal bar. Short: close > BB upper.
// Matches Step B9 walk_count (see scripts/step_b_complete_analyze.py). Default OFF.
input group "BB walk filter"
input bool             inp_bb_walk_filter_enable     = false;
input int              inp_bb_walk_min_closes        = 2;     // block when walk count >= this (2 or 3)

//=== Confirmation bar (Step D10 — entry path) =======================
// Setup bar = signal_shift+1 (extreme); confirm bar = signal_shift (re-entry / rejection).
// Default OFF; test via vem5m_d10_d7_confirm_bar.set on production stack (D7+E8c).
enum ENUM_VEM_CONFIRM_MODE
  {
   VEM_CONFIRM_REENTER = 0,   // confirm close back inside band
   VEM_CONFIRM_REJECT  = 1,   // confirm body opposes extreme (close>open long)
   VEM_CONFIRM_EITHER  = 2    // re-enter OR reject body
  };

input group "Confirmation bar (D10)"
input bool                 inp_confirm_bar_enable   = false;
input ENUM_VEM_CONFIRM_MODE inp_confirm_mode        = VEM_CONFIRM_EITHER;

//=== HTF regime gate (Step D11 — block fade into HTF continuation) ===
// H1 EMA slope: block long when HTF drift down; block short when HTF drift up.
// Default OFF; test via vem5m_d11_d7_htf_regime.set on production (D7+E8c).
input group "HTF regime gate (D11)"
input bool             inp_htf_regime_enable        = false;
input ENUM_TIMEFRAMES  inp_htf_timeframe            = PERIOD_H1;
input int              inp_htf_ema_period           = 50;
input int              inp_htf_slope_lookback_bars  = 5;
input double           inp_htf_slope_block_bp       = 6.0;

input group "Position sizing"
input double           inp_fixed_lots            = 0.01;
input double           inp_risk_pct             = 0.0;     // 0 = use fixed lots

input group "SL / TP"
input ENUM_VEM_SL_MODE inp_sl_mode               = VEM_SL_FIXED_POINTS;
input int              inp_sl_points             = 120;
input double           inp_sl_atr_mult           = 1.2;
input ENUM_VEM_TP_MODE inp_tp_mode               = VEM_TP_FIXED_RR;
input double           inp_tp_rr                 = 1.3;
input int              inp_tp_points             = 180;

input group "Execution"
input uint             inp_slippage_pts          = 20;
input uint             inp_deviation_pts         = 20;

//=== Exits ==========================================================
input group "Exits"
input bool             inp_exit_bb_midline       = true;
input bool             inp_exit_opposite_signal  = false;

//=== Partial midline TP E9 (Step E9 — bank mean, runner on rest) ===
// When enabled: first midline touch closes pct of volume; remainder uses SL/TP only.
// When disabled: full close at midline (Phase 1 behavior).
input group "Partial midline TP (E9)"
input bool             inp_partial_midline_enable = false;
input double           inp_partial_midline_pct    = 0.6;    // fraction to close at midline (0.5–0.7)

//=== Payoff after MFE proof E11 (Step E11 — conditional partial @ midline) ===
// At midline: full close unless MFE >= min R (reversion proved) — then partial + runner.
// Not E7 BE @ 0.5R; not E9 partial on every midline. Test: vem5m_e11_d7_payoff.set
input group "Payoff after MFE proof (E11)"
input bool             inp_e11_payoff_enable       = false;
input double           inp_e11_mfe_min_r           = 0.35;
input double           inp_e11_partial_pct         = 0.5;

//=== Breakeven E7 (Step E7 — protect winners) =======================
// Move SL to entry after trade proves itself (+R or optional midline touch on signal bar).
// Default OFF; enable via vem5m_e7_d7_breakeven.set on D7 habitat.
input group "Breakeven (E7)"
input bool             inp_be_enable             = false;
input double           inp_be_trigger_r          = 0.5;   // move SL when MFE >= this (R)
input bool             inp_be_on_midline         = false; // also trigger when bar touches BB mid

//=== Failure exit E8 (Step E8a / E8b — one mode per test) ===========
// E8a: vem5m_e8a_d7_fail_exit.set — low MFE and/or outside BB after N bars.
// E8b: vem5m_e8b_d7_time_loss.set — close if POSITION_PROFIT < 0 after N bars.
// Legacy inp_fail_exit_enable=true with mode OFF selects E8a.
input group "Failure exit (E8)"
input ENUM_VEM_FAIL_EXIT_MODE inp_fail_exit_mode     = VEM_FAIL_EXIT_OFF;
input bool             inp_fail_exit_enable          = false;
input int              inp_fail_exit_bars            = 4;
input double           inp_fail_exit_min_mfe_r       = 0.2;   // E8a only
input bool             inp_fail_exit_outside_bb      = true;   // E8a only

//=== Worse-structure exit E8c (Step E8c — BB penetration deepens) =====
// After N bars: close further outside band than at entry (not merely still outside — E8a).
input group "Worse structure exit (E8c)"
input bool             inp_worse_struct_exit_enable  = false;
input int              inp_worse_struct_exit_bars    = 4;
input int              inp_worse_struct_min_pen_pts  = 0;     // extra pts beyond entry penetration

//=== Invalidation exit E10 (Step E10 — MAE/MFE state scratch) =======
// After N bars: low MFE + high MAE => continuation / no revert — close before full SL.
// C1 tuned: bar 6, MFE <= 0.20R, MAE >= 0.50R. Not time-in-loss (E8b) or MFE-only (E8a).
input group "Invalidation exit (E10)"
input bool             inp_inv_exit_enable           = false;
input int              inp_inv_exit_bars            = 6;
input double           inp_inv_mfe_max_r             = 0.20;  // exit when MFE <= this (R)
input double           inp_inv_mae_min_r             = 0.50;  // and MAE >= this (R)

//=== Trade log C1 (Step C — CSV per closed trade) ===================
// File: MQL5/Files/VEM_trades_<SYMBOL>_<TF>.csv — enable on D7 backtests for E10 tuning.
input group "Trade log (C1)"
input bool             inp_trade_log_enable          = false;
input int              inp_trade_log_snap_bar        = 6;      // snapshot MAE/MFE at this bar count (also bar 5)

#endif // VEM_CONFIG_MQH
