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

#endif // VEM_CONFIG_MQH
