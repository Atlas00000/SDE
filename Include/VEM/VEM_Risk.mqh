//+------------------------------------------------------------------+
//| VEM_Risk.mqh                                                     |
//+------------------------------------------------------------------+
#ifndef VEM_RISK_MQH
#define VEM_RISK_MQH

#include <VEM/VEM_Config.mqh>
#include <VEM/VEM_Log.mqh>
#include <VEM/VEM_State.mqh>
#include <VEM/VEM_Indicators.mqh>

inline bool VEM_Risk_CheckSpread(const string sym, string &reason)
  {
   const long spr = SymbolInfoInteger(sym, SYMBOL_SPREAD);
   if(spr > inp_max_spread_pts)
     {
      reason = StringFormat("spread %ld > max %d", spr, inp_max_spread_pts);
      return false;
     }
   reason = "";
   return true;
  }

inline bool VEM_Risk_CheckDrawdown(string &reason)
  {
   if(inp_max_dd_pct <= 0.0)
     {
      reason = "";
      return true;
     }
   const double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   const double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(bal <= 0.0)
     {
      reason = "balance<=0";
      return false;
     }
   const double dd_pct = (bal - eq) / bal * 100.0;
   if(dd_pct > inp_max_dd_pct)
     {
      reason = StringFormat("dd %.2f%% > max %.2f%%", dd_pct, inp_max_dd_pct);
      return false;
     }
   reason = "";
   return true;
  }

inline bool VEM_Risk_CheckDirection(const ENUM_ORDER_TYPE otype, string &reason)
  {
   if(inp_direction == VEM_TRADE_LONG_ONLY && otype != ORDER_TYPE_BUY)
     {
      reason = "long-only mode";
      return false;
     }
   if(inp_direction == VEM_TRADE_SHORT_ONLY && otype != ORDER_TYPE_SELL)
     {
      reason = "short-only mode";
      return false;
     }
   reason = "";
   return true;
  }

inline bool VEM_Risk_CheckMaxPositions(const string sym, const long magic, string &reason)
  {
   const int n = VEM_State_CountPositions(sym, magic, -1);
   if(n >= inp_max_positions_total)
     {
      reason = StringFormat("positions %d >= max %d", n, inp_max_positions_total);
      return false;
     }
   reason = "";
   return true;
  }

// Signal-bar hour in server time (matches Strategy Tester report / Step B6).
inline bool VEM_Risk_CheckSession(const datetime signal_bar_time, string &reason)
  {
   if(!inp_session_filter_enable)
     {
      reason = "";
      return true;
     }
   if(signal_bar_time <= 0)
     {
      reason = "session filter: invalid signal bar time";
      return false;
     }

   MqlDateTime dt;
   TimeToStruct(signal_bar_time, dt);
   const int hour = dt.hour;
   const int h_start = MathMin(inp_block_hour_start, inp_block_hour_end);
   const int h_end = MathMax(inp_block_hour_start, inp_block_hour_end);

   if(hour >= h_start && hour <= h_end)
     {
      reason = StringFormat("session block hour %d (blocked %d-%d)", hour, h_start, h_end);
      return false;
     }

   reason = "";
   return true;
  }

// Block wide Bollinger bands on signal bar (Step B4 / D6).
inline bool VEM_Risk_CheckBBWidth(const VEMIndicatorSnap &s, string &reason)
  {
   if(!inp_bb_width_filter_enable)
     {
      reason = "";
      return true;
     }
   if(!s.valid || s.bb_middle <= 0.0)
     {
      reason = "bb width filter: invalid indicator snap";
      return false;
     }
   if(inp_bb_max_width_ratio <= 0.0)
     {
      reason = "bb width filter: max ratio <= 0";
      return false;
     }

   const double ratio = VEM_Indicators_BBWidthRatio(s);
   if(ratio > inp_bb_max_width_ratio)
     {
      reason = StringFormat("bb width %.6f > max %.6f", ratio, inp_bb_max_width_ratio);
      return false;
     }

   reason = "";
   return true;
  }

// Require deeper RSI extreme on signal bar (Step B5 / D7).
inline bool VEM_Risk_CheckRSIDepth(const ENUM_ORDER_TYPE otype, const VEMIndicatorSnap &s,
                                   string &reason)
  {
   if(!inp_rsi_depth_filter_enable)
     {
      reason = "";
      return true;
     }
   if(!s.valid)
     {
      reason = "rsi depth filter: invalid indicator snap";
      return false;
     }

   if(otype == ORDER_TYPE_BUY && inp_rsi_depth_long_enable)
     {
      if(s.rsi > inp_rsi_long_max_depth)
        {
         reason = StringFormat("long RSI %.2f > max depth %.2f", s.rsi, inp_rsi_long_max_depth);
         return false;
        }
     }
   else if(otype == ORDER_TYPE_SELL && inp_rsi_depth_short_enable)
     {
      if(s.rsi < inp_rsi_short_min_depth)
        {
         reason = StringFormat("short RSI %.2f < min depth %.2f", s.rsi, inp_rsi_short_min_depth);
         return false;
        }
     }

   reason = "";
   return true;
  }

// Block fades against strong EMA drift on signal bar (Step B1 "against" bucket / D8).
inline bool VEM_Risk_CheckEMASlope(const string sym, const ENUM_TIMEFRAMES tf,
                                   const int signal_shift, const ENUM_ORDER_TYPE otype,
                                   string &reason)
  {
   if(!inp_ema_slope_filter_enable)
     {
      reason = "";
      return true;
     }

   const double block_bp = inp_ema_slope_block_bp;
   if(block_bp <= 0.0)
     {
      reason = "ema slope filter: block_bp <= 0";
      return false;
     }

   double slope_bp = 0.0;
   if(!VEM_Indicators_EMASlopeBp(sym, tf, signal_shift, slope_bp))
     {
      reason = "ema slope filter: slope unavailable";
      return false;
     }

   if(otype == ORDER_TYPE_BUY && slope_bp < -block_bp)
     {
      reason = StringFormat("long blocked: ema slope %.2f bp < -%.2f", slope_bp, block_bp);
      return false;
     }
   if(otype == ORDER_TYPE_SELL && slope_bp > block_bp)
     {
      reason = StringFormat("short blocked: ema slope %.2f bp > +%.2f", slope_bp, block_bp);
      return false;
     }

   reason = "";
   return true;
  }

// Block entry during band walk (Step B9 / D9).
inline bool VEM_Risk_CheckBBWalk(const string sym, const ENUM_TIMEFRAMES tf,
                                 const int signal_shift, const ENUM_ORDER_TYPE otype,
                                 string &reason)
  {
   if(!inp_bb_walk_filter_enable)
     {
      reason = "";
      return true;
     }

   const int min_closes = MathMax(1, inp_bb_walk_min_closes);
   const bool is_long = (otype == ORDER_TYPE_BUY);
   const int walk = VEM_Indicators_BBWalkCount(sym, tf, signal_shift, is_long);

   if(walk >= min_closes)
     {
      reason = StringFormat("bb walk %d closes >= %d (%s)",
                            walk, min_closes, is_long ? "below lower" : "above upper");
      return false;
     }

   reason = "";
   return true;
  }

// Block fade against HTF EMA drift (Step D11 — H1 continuation gate).
inline bool VEM_Risk_CheckHtfRegime(const string sym, const datetime signal_bar_time,
                                    const ENUM_ORDER_TYPE otype, string &reason)
  {
   if(!inp_htf_regime_enable)
     {
      reason = "";
      return true;
     }

   const double block_bp = inp_htf_slope_block_bp;
   if(block_bp <= 0.0)
     {
      reason = "htf regime: block_bp <= 0";
      return false;
     }

   double slope_bp = 0.0;
   if(!VEM_Indicators_HtfSlopeBp(sym, signal_bar_time, slope_bp))
     {
      reason = "htf regime: slope unavailable";
      return false;
     }

   if(otype == ORDER_TYPE_BUY && slope_bp < -block_bp)
     {
      reason = StringFormat("long blocked: htf slope %.2f bp < -%.2f", slope_bp, block_bp);
      return false;
     }
   if(otype == ORDER_TYPE_SELL && slope_bp > block_bp)
     {
      reason = StringFormat("short blocked: htf slope %.2f bp > +%.2f", slope_bp, block_bp);
      return false;
     }

   reason = "";
   return true;
  }

inline bool VEM_Risk_AllowNewTrade(const string sym, const ENUM_TIMEFRAMES tf,
                                   const ENUM_ORDER_TYPE otype, const int signal_shift,
                                   const VEMIndicatorSnap &s, string &reason)
  {
   if(!VEM_Risk_CheckSpread(sym, reason))
      return false;
   if(!VEM_Risk_CheckDrawdown(reason))
      return false;
   if(!VEM_Risk_CheckDirection(otype, reason))
      return false;
   if(!VEM_Risk_CheckMaxPositions(sym, inp_magic, reason))
      return false;
   if(!VEM_Risk_CheckSession(s.bar_time, reason))
      return false;
   if(!VEM_Risk_CheckBBWidth(s, reason))
      return false;
   if(!VEM_Risk_CheckRSIDepth(otype, s, reason))
      return false;
   if(!VEM_Risk_CheckEMASlope(sym, tf, signal_shift, otype, reason))
      return false;
   if(!VEM_Risk_CheckBBWalk(sym, tf, signal_shift, otype, reason))
      return false;
   if(!VEM_Risk_CheckHtfRegime(sym, s.bar_time, otype, reason))
      return false;
   if(!VEM_State_CooldownOk(sym, tf, signal_shift, inp_cooldown_bars))
     {
      reason = StringFormat("cooldown (%d bars)", inp_cooldown_bars);
      return false;
     }
   reason = "";
   return true;
  }

inline double VEM_Risk_NormalizeVolume(const string sym, double lots)
  {
   double vmin = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   if(vstep <= 0.0)
      vstep = 0.01;
   if(vmin <= 0.0)
      vmin = vstep;
   lots = MathFloor(lots / vstep + 1e-12) * vstep;
   if(lots < vmin)
      lots = vmin;
   if(lots > vmax)
      lots = vmax;
   return lots;
  }

inline double VEM_Risk_CalculateLots(const string sym, const ENUM_ORDER_TYPE otype,
                                     const double entry_price, const double sl_price,
                                     string &reason)
  {
   reason = "";
   if(inp_risk_pct <= 0.0)
      return VEM_Risk_NormalizeVolume(sym, inp_fixed_lots);

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double risk_money = equity * inp_risk_pct / 100.0;
   if(risk_money <= 0.0)
     {
      reason = "risk_money<=0";
      return VEM_Risk_NormalizeVolume(sym, inp_fixed_lots);
     }

   double profit_to_sl = 0.0;
   if(!OrderCalcProfit(otype, sym, 1.0, entry_price, sl_price, profit_to_sl))
     {
      reason = "OrderCalcProfit failed";
      return VEM_Risk_NormalizeVolume(sym, inp_fixed_lots);
     }

   const double loss_abs = MathAbs(MathMin(0.0, profit_to_sl));
   if(loss_abs <= 0.0)
     {
      reason = "loss_abs<=0";
      return VEM_Risk_NormalizeVolume(sym, inp_fixed_lots);
     }

   double lots = risk_money / loss_abs;
   return VEM_Risk_NormalizeVolume(sym, lots);
  }

inline double VEM_Risk_SlDistancePrice(const string sym, const VEMIndicatorSnap &s)
  {
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(inp_sl_mode == VEM_SL_ATR)
      return MathMax(pt, s.atr * inp_sl_atr_mult);
   return MathMax(pt, (double)inp_sl_points * pt);
  }

#endif // VEM_RISK_MQH
