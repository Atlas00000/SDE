//+------------------------------------------------------------------+
//| VEM_Execution.mqh                                                |
//| Exit precedence per Phase 1: (1) BB midline touch (2) opposite   |
//| signal (3) broker SL/TP. Entries run after exits on same bar.    |
//+------------------------------------------------------------------+
#ifndef VEM_EXECUTION_MQH
#define VEM_EXECUTION_MQH

#include <Trade/Trade.mqh>
#include <VEM/VEM_Config.mqh>
#include <VEM/VEM_Log.mqh>
#include <VEM/VEM_Indicators.mqh>
#include <VEM/VEM_Risk.mqh>
#include <VEM/VEM_State.mqh>

static CTrade g_vem_trade;

inline void VEM_Execution_Init(const string sym)
  {
   g_vem_trade.SetExpertMagicNumber(inp_magic);
   const int dev = (int)MathMax(inp_slippage_pts, inp_deviation_pts);
   g_vem_trade.SetDeviationInPoints(dev);

   ENUM_ORDER_TYPE_FILLING fill = ORDER_FILLING_RETURN;
   const long fm = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
   if((fm & SYMBOL_FILLING_IOC) != 0)
      fill = ORDER_FILLING_IOC;
   else if((fm & SYMBOL_FILLING_FOK) != 0)
      fill = ORDER_FILLING_FOK;
   else
      fill = ORDER_FILLING_RETURN;
   g_vem_trade.SetTypeFilling(fill);
  }

inline bool VEM_Exec_ValidateStopsBuy(const string sym, const double bid,
                                      const double sl, const double tp, string &reason)
  {
   const long lvl = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double min = (double)lvl * pt;

   if(sl > 0.0 && (bid - sl) < min)
     {
      reason = StringFormat("buy SL too close (bid-sl=%.5g min=%.5g)", bid - sl, min);
      return false;
     }
   if(tp > 0.0 && (tp - bid) < min)
     {
      reason = StringFormat("buy TP too close (tp-bid=%.5g min=%.5g)", tp - bid, min);
      return false;
     }
   reason = "";
   return true;
  }

inline bool VEM_Exec_ValidateStopsSell(const string sym, const double ask,
                                       const double sl, const double tp, string &reason)
  {
   const long lvl = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double min = (double)lvl * pt;

   if(sl > 0.0 && (sl - ask) < min)
     {
      reason = StringFormat("sell SL too close (sl-ask=%.5g min=%.5g)", sl - ask, min);
      return false;
     }
   if(tp > 0.0 && (ask - tp) < min)
     {
      reason = StringFormat("sell TP too close (ask-tp=%.5g min=%.5g)", ask - tp, min);
      return false;
     }
   reason = "";
   return true;
  }

inline bool VEM_Execution_CloseType(const string sym, const long magic,
                                    const ENUM_POSITION_TYPE ptype)
  {
   bool any = false;
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != ptype)
         continue;

      if(!g_vem_trade.PositionClose(ticket))
        {
         VEM_Log_TradeFail("PositionClose", g_vem_trade.ResultRetcode());
        }
      else
        {
         any = true;
         VEM_Log_Info("Closed ticket " + (string)ticket + " (" +
                      (ptype == POSITION_TYPE_BUY ? "buy" : "sell") + ")");
        }
     }
   return any;
  }

inline void VEM_Execution_ManageExits(const string sym, const VEMIndicatorSnap &s,
                                      const bool want_long, const bool want_short)
  {
   if(!s.valid)
      return;

   // (1) Mean-reversion: touch Bollinger middle on signal bar
   if(inp_exit_bb_midline)
     {
      if(VEM_State_HasBuy(sym, inp_magic) && s.high >= s.bb_middle)
        {
         VEM_Log_Verbose("Exit: BB midline (buy)");
         VEM_Execution_CloseType(sym, inp_magic, POSITION_TYPE_BUY);
        }
      if(VEM_State_HasSell(sym, inp_magic) && s.low <= s.bb_middle)
        {
         VEM_Log_Verbose("Exit: BB midline (sell)");
         VEM_Execution_CloseType(sym, inp_magic, POSITION_TYPE_SELL);
        }
     }

   // (2) Emergency / regime flip
   if(inp_exit_opposite_signal)
     {
      if(VEM_State_HasBuy(sym, inp_magic) && want_short)
        {
         VEM_Log_Verbose("Exit: opposite signal (close buy)");
         VEM_Execution_CloseType(sym, inp_magic, POSITION_TYPE_BUY);
        }
      if(VEM_State_HasSell(sym, inp_magic) && want_long)
        {
         VEM_Log_Verbose("Exit: opposite signal (close sell)");
         VEM_Execution_CloseType(sym, inp_magic, POSITION_TYPE_SELL);
        }
     }
  }

inline bool VEM_Execution_OpenBuy(const string sym, const ENUM_TIMEFRAMES tf,
                                const int signal_shift, const VEMIndicatorSnap &s)
  {
   string r;
   if(!VEM_Risk_AllowNewTrade(sym, tf, ORDER_TYPE_BUY, signal_shift, s, r))
     {
      VEM_Log_Verbose(StringFormat("Skip buy: %s", r));
      return false;
     }

   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   const double sl_dist = VEM_Risk_SlDistancePrice(sym, s);
   double sl = NormalizeDouble(ask - sl_dist, dg);
   double tp = 0.0;

   if(inp_tp_mode == VEM_TP_FIXED_POINTS)
      tp = NormalizeDouble(ask + (double)inp_tp_points * pt, dg);
   else if(inp_tp_mode == VEM_TP_FIXED_RR)
      tp = NormalizeDouble(ask + sl_dist * inp_tp_rr, dg);
   else if(inp_tp_mode == VEM_TP_BB_MIDLINE_ONLY)
      tp = 0.0;

   if(!VEM_Exec_ValidateStopsBuy(sym, bid, sl, tp, r))
     {
      VEM_Log_Info(StringFormat("Skip buy stops: %s", r));
      return false;
     }

   double lots = VEM_Risk_CalculateLots(sym, ORDER_TYPE_BUY, ask, sl, r);
   if(StringLen(r))
      VEM_Log_Verbose(StringFormat("Lots note: %s", r));
   const double vmin = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   if(lots < vmin - 1e-12)
     {
      VEM_Log_Info("Skip buy: volume below minimum");
      return false;
     }

   if(!g_vem_trade.Buy(lots, sym, 0.0, sl, tp, inp_trade_comment))
     {
      VEM_Log_TradeFail("Buy", g_vem_trade.ResultRetcode());
      return false;
     }

   VEM_State_SetLastEntryBarTime(s.bar_time);
   VEM_Log_Info(StringFormat("Buy OK lots=%.4f SL=%.5f TP=%.5f", lots, sl, tp));
   return true;
  }

inline bool VEM_Execution_OpenSell(const string sym, const ENUM_TIMEFRAMES tf,
                                 const int signal_shift, const VEMIndicatorSnap &s)
  {
   string r;
   if(!VEM_Risk_AllowNewTrade(sym, tf, ORDER_TYPE_SELL, signal_shift, s, r))
     {
      VEM_Log_Verbose(StringFormat("Skip sell: %s", r));
      return false;
     }

   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   const double sl_dist = VEM_Risk_SlDistancePrice(sym, s);
   double sl = NormalizeDouble(bid + sl_dist, dg);
   double tp = 0.0;

   if(inp_tp_mode == VEM_TP_FIXED_POINTS)
      tp = NormalizeDouble(bid - (double)inp_tp_points * pt, dg);
   else if(inp_tp_mode == VEM_TP_FIXED_RR)
      tp = NormalizeDouble(bid - sl_dist * inp_tp_rr, dg);
   else if(inp_tp_mode == VEM_TP_BB_MIDLINE_ONLY)
      tp = 0.0;

   if(!VEM_Exec_ValidateStopsSell(sym, ask, sl, tp, r))
     {
      VEM_Log_Info(StringFormat("Skip sell stops: %s", r));
      return false;
     }

   double lots = VEM_Risk_CalculateLots(sym, ORDER_TYPE_SELL, bid, sl, r);
   if(StringLen(r))
      VEM_Log_Verbose(StringFormat("Lots note: %s", r));
   const double vmin = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   if(lots < vmin - 1e-12)
     {
      VEM_Log_Info("Skip sell: volume below minimum");
      return false;
     }

   if(!g_vem_trade.Sell(lots, sym, 0.0, sl, tp, inp_trade_comment))
     {
      VEM_Log_TradeFail("Sell", g_vem_trade.ResultRetcode());
      return false;
     }

   VEM_State_SetLastEntryBarTime(s.bar_time);
   VEM_Log_Info(StringFormat("Sell OK lots=%.4f SL=%.5f TP=%.5f", lots, sl, tp));
   return true;
  }

inline void VEM_Execution_ProcessBar(const string sym, const ENUM_TIMEFRAMES tf,
                                     const int signal_shift, const VEMIndicatorSnap &s,
                                     const bool want_long, const bool want_short)
  {
   VEM_Execution_ManageExits(sym, s, want_long, want_short);

   if(want_long && want_short)
     {
      VEM_Log_Verbose("Skip entries: long and short both true on bar");
      return;
     }

   if(want_long && inp_direction != VEM_TRADE_SHORT_ONLY)
      VEM_Execution_OpenBuy(sym, tf, signal_shift, s);

   if(want_short && inp_direction != VEM_TRADE_LONG_ONLY)
      VEM_Execution_OpenSell(sym, tf, signal_shift, s);

   if(inp_log_verbose && s.valid)
      VEM_Log_Verbose(StringFormat(
                         "Bar=%s L=%s S=%s rsi=%.2f bbL=%.5f hi=%.5f lo=%.5f vol=%.0f vma=%.0f",
                         TimeToString(s.bar_time, TIME_DATE | TIME_MINUTES),
                         want_long ? "Y" : "N",
                         want_short ? "Y" : "N",
                         s.rsi, s.bb_lower, s.high, s.low, s.volume, s.volume_ma));
  }

#endif // VEM_EXECUTION_MQH
