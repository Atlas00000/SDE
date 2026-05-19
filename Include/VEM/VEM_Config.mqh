//+------------------------------------------------------------------+
//| VEM_Config.mqh                                                   |
//| Inputs — defaults = production EURUSD M5 (vem5m_d7_session_bb_rsi.set) |
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

//=== Indicators (EURUSD M5 production) ==============================
input group "Bollinger Bands"
input int              inp_bb_period             = 20;
input double           inp_bb_dev                = 2.0;

input group "RSI"
input int              inp_rsi_period            = 14;
input double           inp_rsi_ob                = 70.0;
input double           inp_rsi_os                = 30.0;

input group "Volume spike"
input int              inp_vol_ma_period         = 20;
input double           inp_vol_spike_mult        = 1.5;

input group "BB touch / pierce"
input double           inp_bb_penetration_pts    = 0.0;    // long: Low <= Lower - pts*point

//=== Risk gates =====================================================
input group "Risk gates"
input int              inp_max_spread_pts        = 50;
input int              inp_max_positions_total   = 1;
input int              inp_cooldown_bars         = 1;
input double           inp_max_dd_pct            = 0.0;     // 0 = off; block if (Bal-Equity)/Bal*100 exceeds

//=== Session filter (Step D1 — habitat) ===========================
// Production ON: block server hours 13–15. Disable for Step A baseline (vem5m.set).
input group "Session filter"
input bool             inp_session_filter_enable = true;
input int              inp_block_hour_start       = 13;      // inclusive, server time (D1)
input int              inp_block_hour_end         = 15;      // inclusive, server time
input bool             inp_session_block2_enable  = false;   // D1b: second window (e.g. hour 7)
input int              inp_block2_hour_start      = 7;
input int              inp_block2_hour_end        = 7;

//=== BB width filter (Step D6 — habitat) ==========================
// Ratio = (BB upper - lower) / middle on signal bar. Production max ~0.00165.
input group "BB width filter"
input bool             inp_bb_width_filter_enable = true;
input double           inp_bb_max_width_ratio     = 0.00165; // block if ratio > this; 0 with filter off

//=== RSI depth filter (Step D7 — habitat) =========================
// Long RSI <= 25; short RSI >= 75 on signal bar.
input group "RSI depth filter"
input bool             inp_rsi_depth_filter_enable = true;
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
input int              inp_sl_points             = 200;
input double           inp_sl_atr_mult           = 1.5;
input ENUM_VEM_TP_MODE inp_tp_mode               = VEM_TP_FIXED_RR;
input double           inp_tp_rr                 = 1.5;
input int              inp_tp_points             = 300;

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
// Production ON @ bar 4. Habitat-only: vem5m_d7_habitat_only.set (enable=false).
input group "Worse structure exit (E8c)"
input bool             inp_worse_struct_exit_enable  = true;
input int              inp_worse_struct_exit_bars    = 4;     // E8c-bar: test 3 or 5 via tester .set
input int              inp_worse_struct_min_pen_pts  = 0;     // E8c-v2: min deepen vs entry (points); 0 = any deepen

//=== Invalidation exit E10 (Step E10 / E10-v2 — MAE/MFE state scratch) =======
// Stack on production (E8c on): vem5m_e10v2_prod_mae045.set — bar 6, MFE<=0.20, MAE>=0.45.
// Legacy habitat-only: vem5m_e10_d7_invalidation.set (MAE 0.50, no E8c). Prod default: OFF.
input group "Invalidation exit (E10)"
input bool             inp_inv_exit_enable           = false;
input int              inp_inv_exit_bars            = 6;
input double           inp_inv_mfe_max_r             = 0.20;  // exit when MFE <= this (R)
input double           inp_inv_mae_min_r             = 0.50;  // E10-v2 v1 test: 0.45

//=== Trade log C1 (Step C — CSV per closed trade) ===================
// File: MQL5/Files/VEM_trades_<SYMBOL>_<TF>.csv — enable on D7 backtests for E10 tuning.
input group "Trade log (C1)"
input bool             inp_trade_log_enable          = false;
input int              inp_trade_log_snap_bar        = 6;      // snapshot MAE/MFE at this bar count (also bar 5)

//=== AI v0.1 (tester only until live gate) ===========================
input group "AI v0.1 (tester)"
input bool             inp_ai_shadow_enable           = false;  // AI-4: log score, no order change
input bool             inp_ai_skip_enable             = false;  // AI-5: block entry when would_skip
input double           inp_ai_skip_prob_threshold     = 0.874305088039118;  // P(bad) >= skip (~2%)

#endif // VEM_CONFIG_MQH
