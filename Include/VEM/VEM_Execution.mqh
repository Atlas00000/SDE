//+------------------------------------------------------------------+
//| VEM_Execution.mqh                                                |
//| Exit precedence: (1) E7 BE (2) E14 soft SL (3) midline (4) E10 |
//| (5) E8c (6) E13 (7) E8a/E8b (8) opposite (9) broker SL/TP.     |
//+------------------------------------------------------------------+
#ifndef VEM_EXECUTION_MQH
#define VEM_EXECUTION_MQH

#include <Trade/Trade.mqh>
#include <VEM/VEM_Config.mqh>
#include <VEM/VEM_AI.mqh>
#include <VEM/VEM_AIShadow.mqh>
#include <VEM/VEM_Log.mqh>
#include <VEM/VEM_Indicators.mqh>
#include <VEM/VEM_Risk.mqh>
#include <VEM/VEM_State.mqh>
#include <VEM/VEM_TradeLog.mqh>

static CTrade g_vem_trade;

#define VEM_PARTIAL_MAX 32
static ulong g_vem_partial_tickets[VEM_PARTIAL_MAX];
static int   g_vem_partial_n = 0;

#define VEM_STRUCT_PEN_MAX 32
struct VEMStructPenRec
  {
   ulong  ticket;
   double entry_pen;
  };
static VEMStructPenRec g_vem_struct_pen[VEM_STRUCT_PEN_MAX];
static int             g_vem_struct_pen_n = 0;

inline void VEM_Exec_PartialPrune()
  {
   for(int j = g_vem_partial_n - 1; j >= 0; --j)
     {
      if(!PositionSelectByTicket(g_vem_partial_tickets[j]))
        {
         g_vem_partial_tickets[j] = g_vem_partial_tickets[g_vem_partial_n - 1];
         g_vem_partial_n--;
        }
     }
  }

inline bool VEM_Exec_PartialDone(const ulong ticket)
  {
   for(int j = 0; j < g_vem_partial_n; ++j)
      if(g_vem_partial_tickets[j] == ticket)
         return true;
   return false;
  }

inline void VEM_Exec_PartialMark(const ulong ticket)
  {
   if(VEM_Exec_PartialDone(ticket) || g_vem_partial_n >= VEM_PARTIAL_MAX)
      return;
   g_vem_partial_tickets[g_vem_partial_n++] = ticket;
  }

inline double VEM_Exec_BbPenLong(const double close, const double bb_lower)
  {
   return MathMax(0.0, bb_lower - close);
  }

inline double VEM_Exec_BbPenShort(const double close, const double bb_upper)
  {
   return MathMax(0.0, close - bb_upper);
  }

inline void VEM_Exec_StructPenPrune()
  {
   for(int j = g_vem_struct_pen_n - 1; j >= 0; --j)
     {
      if(!PositionSelectByTicket(g_vem_struct_pen[j].ticket))
        {
         g_vem_struct_pen[j] = g_vem_struct_pen[g_vem_struct_pen_n - 1];
         g_vem_struct_pen_n--;
        }
     }
  }

inline void VEM_Exec_StructPenRegister(const ulong ticket, const double entry_pen)
  {
   if(ticket == 0)
      return;
   VEM_Exec_StructPenPrune();
   for(int j = 0; j < g_vem_struct_pen_n; ++j)
     {
      if(g_vem_struct_pen[j].ticket == ticket)
        {
         g_vem_struct_pen[j].entry_pen = entry_pen;
         return;
        }
     }
   if(g_vem_struct_pen_n >= VEM_STRUCT_PEN_MAX)
      return;
   g_vem_struct_pen[g_vem_struct_pen_n].ticket = ticket;
   g_vem_struct_pen[g_vem_struct_pen_n].entry_pen = entry_pen;
   g_vem_struct_pen_n++;
  }

inline bool VEM_Exec_StructPenLookup(const ulong ticket, double &entry_pen)
  {
   for(int j = 0; j < g_vem_struct_pen_n; ++j)
     {
      if(g_vem_struct_pen[j].ticket == ticket)
        {
         entry_pen = g_vem_struct_pen[j].entry_pen;
         return true;
        }
     }
   return false;
  }

inline ulong VEM_Exec_NewestPositionTicket(const string sym, const ENUM_POSITION_TYPE ptype)
  {
   ulong best = 0;
   datetime best_t = 0;
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != inp_magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != ptype)
         continue;
      const datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(ot >= best_t)
        {
         best_t = ot;
         best = ticket;
        }
     }
   return best;
  }

inline double VEM_Exec_EntryBbPen(const string sym, const ENUM_TIMEFRAMES tf,
                                  const datetime open_time, const ENUM_POSITION_TYPE ptype)
  {
   const int entry_shift = iBarShift(sym, tf, open_time, true);
   if(entry_shift < 0)
      return 0.0;

   VEMIndicatorSnap es;
   if(!VEM_Indicators_Refresh(sym, tf, entry_shift, es) || !es.valid)
      return 0.0;

   if(ptype == POSITION_TYPE_BUY)
      return VEM_Exec_BbPenLong(es.close, es.bb_lower);
   return VEM_Exec_BbPenShort(es.close, es.bb_upper);
  }

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

// Bars completed since position open (new-bar model; 0 on entry bar).
inline int VEM_Exec_BarsInTrade(const string sym, const ENUM_TIMEFRAMES tf, const datetime open_time)
  {
   const int entry_shift = iBarShift(sym, tf, open_time, true);
   if(entry_shift < 0)
      return 0;
   return MathMax(0, entry_shift - 1);
  }

// Max favorable / adverse excursion in R (closed bars from entry through last closed bar).
inline void VEM_Exec_ExcursionsInR(const string sym, const ENUM_TIMEFRAMES tf, const int entry_shift,
                                     const ENUM_POSITION_TYPE ptype, const double entry,
                                     const double sl_dist, double &mae_r, double &mfe_r)
  {
   mae_r = 0.0;
   mfe_r = 0.0;
   if(sl_dist <= 0.0 || entry_shift < 1)
      return;

   if(ptype == POSITION_TYPE_BUY)
     {
      double hi_max = entry;
      double lo_min = entry;
      for(int sh = entry_shift; sh >= 1; sh--)
        {
         hi_max = MathMax(hi_max, iHigh(sym, tf, sh));
         lo_min = MathMin(lo_min, iLow(sym, tf, sh));
        }
      mfe_r = (hi_max - entry) / sl_dist;
      mae_r = (entry - lo_min) / sl_dist;
      return;
     }

   double hi_max = entry;
   double lo_min = entry;
   for(int sh = entry_shift; sh >= 1; sh--)
     {
      hi_max = MathMax(hi_max, iHigh(sym, tf, sh));
      lo_min = MathMin(lo_min, iLow(sym, tf, sh));
     }
   mfe_r = (entry - lo_min) / sl_dist;
   mae_r = (hi_max - entry) / sl_dist;
  }

inline double VEM_Exec_MfeInR(const string sym, const ENUM_TIMEFRAMES tf, const int entry_shift,
                              const ENUM_POSITION_TYPE ptype, const double entry,
                              const double sl_dist)
  {
   double mae = 0.0, mfe = 0.0;
   VEM_Exec_ExcursionsInR(sym, tf, entry_shift, ptype, entry, sl_dist, mae, mfe);
   return mfe;
  }

inline bool VEM_Exec_IsAtBreakeven(const ENUM_POSITION_TYPE ptype, const double entry,
                                   const double sl, const string sym)
  {
   if(sl <= 0.0)
      return false;
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double tol = MathMax(pt, pt * 3.0);
   if(ptype == POSITION_TYPE_BUY)
      return (sl >= entry - tol);
   return (sl <= entry + tol);
  }

inline void VEM_Execution_ManageBreakeven(const string sym, const ENUM_TIMEFRAMES tf,
                                          const VEMIndicatorSnap &s)
  {
   if(!inp_be_enable || !s.valid)
      return;

   const double trigger_r = inp_be_trigger_r;
   if(trigger_r <= 0.0 && !inp_be_on_midline)
      return;

   const int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);

   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != inp_magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);

      if(VEM_Exec_IsAtBreakeven(ptype, entry, sl, sym))
         continue;

      double sl_dist = 0.0;
      if(sl > 0.0)
         sl_dist = MathAbs(entry - sl);
      if(sl_dist <= 0.0)
         sl_dist = VEM_Risk_SlDistancePrice(sym, s);

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int entry_shift = iBarShift(sym, tf, open_time, true);
      const double mfe_r = VEM_Exec_MfeInR(sym, tf, entry_shift, ptype, entry, sl_dist);

      bool trigger = (trigger_r > 0.0 && mfe_r >= trigger_r);
      if(inp_be_on_midline)
        {
         if(ptype == POSITION_TYPE_BUY && s.high >= s.bb_middle)
            trigger = true;
         else if(ptype == POSITION_TYPE_SELL && s.low <= s.bb_middle)
            trigger = true;
        }

      if(!trigger)
         continue;

      double new_sl = NormalizeDouble(entry, dg);
      string vr;
      if(ptype == POSITION_TYPE_BUY)
        {
         if(!VEM_Exec_ValidateStopsBuy(sym, bid, new_sl, tp, vr))
           {
            const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
            new_sl = NormalizeDouble(entry - pt, dg);
            if(!VEM_Exec_ValidateStopsBuy(sym, bid, new_sl, tp, vr))
               continue;
           }
        }
      else
        {
         if(!VEM_Exec_ValidateStopsSell(sym, ask, new_sl, tp, vr))
           {
            const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
            new_sl = NormalizeDouble(entry + pt, dg);
            if(!VEM_Exec_ValidateStopsSell(sym, ask, new_sl, tp, vr))
               continue;
           }
        }

      if(!g_vem_trade.PositionModify(ticket, new_sl, tp))
        {
         VEM_Log_TradeFail("Breakeven", g_vem_trade.ResultRetcode());
         continue;
        }

      VEM_Log_Info(StringFormat("E7 BE #%s %s mfe=%.2fR sl=%.5f",
                                (string)ticket,
                                ptype == POSITION_TYPE_BUY ? "buy" : "sell",
                                mfe_r, new_sl));
     }
  }

inline double VEM_Exec_SlPriceAtLossR(const ENUM_POSITION_TYPE ptype, const double entry,
                                      const double sl_dist, const double loss_r)
  {
   if(sl_dist <= 0.0 || loss_r <= 0.0)
      return 0.0;
   if(ptype == POSITION_TYPE_BUY)
      return entry - loss_r * sl_dist;
   return entry + loss_r * sl_dist;
  }

inline bool VEM_Exec_SlNeedsTightenToLossR(const ENUM_POSITION_TYPE ptype, const double sl,
                                          const double target_sl, const string sym)
  {
   if(sl <= 0.0 || target_sl <= 0.0)
      return true;
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double tol = MathMax(pt, pt * 3.0);
   if(ptype == POSITION_TYPE_BUY)
      return (sl < target_sl - tol);
   return (sl > target_sl + tol);
  }

inline void VEM_Execution_ManageSoftSlTighten(const string sym, const ENUM_TIMEFRAMES tf,
                                              const VEMIndicatorSnap &s)
  {
   if(!inp_e14_soft_sl_enable || !s.valid)
      return;

   const int min_bars = MathMax(1, inp_e14_min_bars);
   const double mfe_max = inp_e14_mfe_max_r;
   const double mae_min = inp_e14_mae_min_r;
   const double loss_r = inp_e14_sl_loss_r;
   if(mfe_max <= 0.0 || mae_min <= 0.0 || loss_r <= 0.0 || loss_r >= 1.0)
      return;

   const int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);

   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != inp_magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = VEM_Exec_BarsInTrade(sym, tf, open_time);
      if(bars_held < min_bars)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);

      double sl_dist = 0.0;
      if(sl > 0.0)
         sl_dist = MathAbs(entry - sl);
      if(sl_dist <= 0.0)
         sl_dist = VEM_Risk_SlDistancePrice(sym, s);
      if(sl_dist <= 0.0)
         continue;

      const int entry_shift = iBarShift(sym, tf, open_time, true);
      double mae_r = 0.0, mfe_r = 0.0;
      VEM_Exec_ExcursionsInR(sym, tf, entry_shift, ptype, entry, sl_dist, mae_r, mfe_r);

      if(mfe_r > mfe_max || mae_r < mae_min)
         continue;

      const double target_sl = VEM_Exec_SlPriceAtLossR(ptype, entry, sl_dist, loss_r);
      if(target_sl <= 0.0)
         continue;
      if(!VEM_Exec_SlNeedsTightenToLossR(ptype, sl, target_sl, sym))
         continue;

      double new_sl = NormalizeDouble(target_sl, dg);
      string vr;
      if(ptype == POSITION_TYPE_BUY)
        {
         if(!VEM_Exec_ValidateStopsBuy(sym, bid, new_sl, tp, vr))
            continue;
        }
      else
        {
         if(!VEM_Exec_ValidateStopsSell(sym, ask, new_sl, tp, vr))
            continue;
        }

      if(!g_vem_trade.PositionModify(ticket, new_sl, tp))
        {
         VEM_Log_TradeFail("E14SoftSL", g_vem_trade.ResultRetcode());
         continue;
        }

      VEM_Log_Info(StringFormat("E14 soft SL #%s %s bars=%d mfe=%.2fR mae=%.2fR sl=%.5f",
                                (string)ticket,
                                ptype == POSITION_TYPE_BUY ? "buy" : "sell",
                                bars_held, mfe_r, mae_r, new_sl));
     }
  }

inline ENUM_VEM_FAIL_EXIT_MODE VEM_Exec_ActiveFailExitMode()
  {
   if(inp_fail_exit_mode != VEM_FAIL_EXIT_OFF)
      return inp_fail_exit_mode;
   if(inp_fail_exit_enable)
      return VEM_FAIL_EXIT_E8A;
   return VEM_FAIL_EXIT_OFF;
  }

inline void VEM_Execution_CheckFailureExits(const string sym, const ENUM_TIMEFRAMES tf,
                                          const VEMIndicatorSnap &s)
  {
   const ENUM_VEM_FAIL_EXIT_MODE mode = VEM_Exec_ActiveFailExitMode();
   if(mode == VEM_FAIL_EXIT_OFF || !s.valid)
      return;

   const int min_bars = MathMax(1, inp_fail_exit_bars);

   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != inp_magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = VEM_Exec_BarsInTrade(sym, tf, open_time);
      if(bars_held < min_bars)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool fail = false;
      double mfe_r = 0.0;

      if(mode == VEM_FAIL_EXIT_E8B)
        {
         const double profit = PositionGetDouble(POSITION_PROFIT);
         fail = (profit < 0.0);
        }
      else
        {
         const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl_dist = 0.0;
         const double sl = PositionGetDouble(POSITION_SL);
         if(sl > 0.0)
            sl_dist = MathAbs(entry - sl);
         if(sl_dist <= 0.0)
            sl_dist = VEM_Risk_SlDistancePrice(sym, s);

         const int entry_shift = iBarShift(sym, tf, open_time, true);
         mfe_r = VEM_Exec_MfeInR(sym, tf, entry_shift, ptype, entry, sl_dist);

         fail = (mfe_r < inp_fail_exit_min_mfe_r);
         if(inp_fail_exit_outside_bb)
           {
            if(ptype == POSITION_TYPE_BUY && s.close < s.bb_lower)
               fail = true;
            else if(ptype == POSITION_TYPE_SELL && s.close > s.bb_upper)
               fail = true;
           }
        }

      if(!fail)
         continue;

      if(!g_vem_trade.PositionClose(ticket))
        {
         VEM_Log_TradeFail("FailExit", g_vem_trade.ResultRetcode());
         continue;
        }

      if(mode == VEM_FAIL_EXIT_E8B)
         VEM_Log_Info(StringFormat("E8b time-loss exit #%s %s bars=%d profit=%.2f",
                                   (string)ticket,
                                   ptype == POSITION_TYPE_BUY ? "buy" : "sell",
                                   bars_held, PositionGetDouble(POSITION_PROFIT)));
      else
         VEM_Log_Info(StringFormat("E8a fail exit #%s %s bars=%d mfe=%.2fR",
                                   (string)ticket,
                                   ptype == POSITION_TYPE_BUY ? "buy" : "sell",
                                   bars_held, mfe_r));
     }
  }

inline void VEM_Execution_CheckInvalidationExits(const string sym, const ENUM_TIMEFRAMES tf,
                                                 const VEMIndicatorSnap &s)
  {
   if(!inp_inv_exit_enable || !s.valid)
      return;

   const int min_bars = MathMax(1, inp_inv_exit_bars);
   const double mfe_max = inp_inv_mfe_max_r;
   const double mae_min = inp_inv_mae_min_r;
   if(mfe_max <= 0.0 || mae_min <= 0.0)
      return;

   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != inp_magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = VEM_Exec_BarsInTrade(sym, tf, open_time);
      if(bars_held < min_bars)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl_dist = 0.0;
      const double sl = PositionGetDouble(POSITION_SL);
      if(sl > 0.0)
         sl_dist = MathAbs(entry - sl);
      if(sl_dist <= 0.0)
         sl_dist = VEM_Risk_SlDistancePrice(sym, s);

      const int entry_shift = iBarShift(sym, tf, open_time, true);
      double mae_r = 0.0, mfe_r = 0.0;
      VEM_Exec_ExcursionsInR(sym, tf, entry_shift, ptype, entry, sl_dist, mae_r, mfe_r);

      if(mfe_r > mfe_max || mae_r < mae_min)
         continue;

      VEM_TLog_StageExit((ulong)PositionGetInteger(POSITION_IDENTIFIER), "e10");
      if(!g_vem_trade.PositionClose(ticket))
        {
         VEM_TLog_ClearPendingExit();
         VEM_Log_TradeFail("InvExit", g_vem_trade.ResultRetcode());
         continue;
        }

      VEM_Log_Info(StringFormat("E10 inv exit #%s %s bars=%d mfe=%.2fR mae=%.2fR",
                                (string)ticket,
                                ptype == POSITION_TYPE_BUY ? "buy" : "sell",
                                bars_held, mfe_r, mae_r));
     }
  }

inline void VEM_Execution_CheckBleedExits(const string sym, const ENUM_TIMEFRAMES tf,
                                          const VEMIndicatorSnap &s)
  {
   if(!inp_e13_bleed_exit_enable || !s.valid)
      return;

   const int min_bars = MathMax(1, inp_e13_bleed_min_bars);
   const double mfe_max = inp_e13_mfe_max_r;
   if(mfe_max <= 0.0)
      return;

   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != inp_magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = VEM_Exec_BarsInTrade(sym, tf, open_time);
      if(bars_held < min_bars)
         continue;

      if(inp_e13_require_loss && PositionGetDouble(POSITION_PROFIT) >= 0.0)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl_dist = 0.0;
      const double sl = PositionGetDouble(POSITION_SL);
      if(sl > 0.0)
         sl_dist = MathAbs(entry - sl);
      if(sl_dist <= 0.0)
         sl_dist = VEM_Risk_SlDistancePrice(sym, s);

      const int entry_shift = iBarShift(sym, tf, open_time, true);
      double mae_r = 0.0, mfe_r = 0.0;
      VEM_Exec_ExcursionsInR(sym, tf, entry_shift, ptype, entry, sl_dist, mae_r, mfe_r);

      if(mfe_r > mfe_max)
         continue;

      const double profit_now = PositionGetDouble(POSITION_PROFIT);
      VEM_TLog_StageExit((ulong)PositionGetInteger(POSITION_IDENTIFIER), "e13");
      if(!g_vem_trade.PositionClose(ticket))
        {
         VEM_TLog_ClearPendingExit();
         VEM_Log_TradeFail("BleedExit", g_vem_trade.ResultRetcode());
         continue;
        }

      VEM_Log_Info(StringFormat("E13 bleed exit #%s %s bars=%d mfe=%.2fR mae=%.2fR profit=%.2f",
                                (string)ticket,
                                ptype == POSITION_TYPE_BUY ? "buy" : "sell",
                                bars_held, mfe_r, mae_r, profit_now));
     }
  }

inline void VEM_Execution_CheckWorseStructureExits(const string sym, const ENUM_TIMEFRAMES tf,
                                                   const VEMIndicatorSnap &s)
  {
   if(!inp_worse_struct_exit_enable || !s.valid)
      return;

   const int min_bars = MathMax(1, inp_worse_struct_exit_bars);
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double min_delta = (double)inp_worse_struct_min_pen_pts * pt;

   VEM_Exec_StructPenPrune();

   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != inp_magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = VEM_Exec_BarsInTrade(sym, tf, open_time);
      if(bars_held < min_bars)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entry_pen = 0.0;
      if(!VEM_Exec_StructPenLookup(ticket, entry_pen))
         entry_pen = VEM_Exec_EntryBbPen(sym, tf, open_time, ptype);

      double pen_now = 0.0;
      if(ptype == POSITION_TYPE_BUY)
         pen_now = VEM_Exec_BbPenLong(s.close, s.bb_lower);
      else
         pen_now = VEM_Exec_BbPenShort(s.close, s.bb_upper);

      if(pen_now <= 0.0)
         continue;
      if(pen_now <= entry_pen + min_delta)
         continue;

      VEM_TLog_StageExit((ulong)PositionGetInteger(POSITION_IDENTIFIER), "e8c");
      if(!g_vem_trade.PositionClose(ticket))
        {
         VEM_TLog_ClearPendingExit();
         VEM_Log_TradeFail("WorseStruct", g_vem_trade.ResultRetcode());
         continue;
        }

      VEM_Log_Info(StringFormat("E8c worse-struct exit #%s %s bars=%d pen=%.5f entry_pen=%.5f delta_pts=%.1f min_pts=%d",
                                (string)ticket,
                                ptype == POSITION_TYPE_BUY ? "buy" : "sell",
                                bars_held, pen_now, entry_pen,
                                (pen_now - entry_pen) / pt, inp_worse_struct_min_pen_pts));
     }
  }

inline double VEM_Exec_MidlinePartialPct(const string sym, const ENUM_TIMEFRAMES tf,
                                         const ulong ticket, const ENUM_POSITION_TYPE ptype,
                                         double &mfe_r_out)
  {
   mfe_r_out = 0.0;
   if(inp_e11_payoff_enable)
     {
      const double min_r = inp_e11_mfe_min_r;
      const double pct = inp_e11_partial_pct;
      if(min_r > 0.0 && pct > 0.0 && pct < 1.0)
        {
         const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl_dist = 0.0;
         const double sl = PositionGetDouble(POSITION_SL);
         if(sl > 0.0)
            sl_dist = MathAbs(entry - sl);
         if(sl_dist <= 0.0)
           {
            VEMIndicatorSnap snap;
            if(VEM_Indicators_Refresh(sym, tf, inp_signal_shift, snap) && snap.valid)
               sl_dist = VEM_Risk_SlDistancePrice(sym, snap);
           }
         const int entry_shift = iBarShift(sym, tf, open_time, true);
         mfe_r_out = VEM_Exec_MfeInR(sym, tf, entry_shift, ptype, entry, sl_dist);
         if(mfe_r_out >= min_r)
            return pct;
        }
      return 0.0;
     }

   if(inp_partial_midline_enable)
     {
      const double pct = inp_partial_midline_pct;
      if(pct > 0.0 && pct < 1.0)
         return pct;
     }
   return 0.0;
  }

inline void VEM_Execution_MidlineExits(const string sym, const ENUM_TIMEFRAMES tf,
                                       const VEMIndicatorSnap &s)
  {
   if(!inp_exit_bb_midline || !s.valid)
      return;

   VEM_Exec_PartialPrune();

   const double vmin = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   const double vstep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != inp_magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool midline_hit = (ptype == POSITION_TYPE_BUY && s.high >= s.bb_middle) ||
                               (ptype == POSITION_TYPE_SELL && s.low <= s.bb_middle);
      if(!midline_hit)
         continue;

      double mfe_r = 0.0;
      const double partial_pct = VEM_Exec_MidlinePartialPct(sym, tf, ticket, ptype, mfe_r);
      const bool use_partial = (partial_pct > 0.0 && partial_pct < 1.0);

      if(use_partial && VEM_Exec_PartialDone(ticket))
         continue;

      if(!use_partial)
        {
         VEM_Log_Verbose(StringFormat("Exit: BB midline full (%s)",
                                      ptype == POSITION_TYPE_BUY ? "buy" : "sell"));
         if(!g_vem_trade.PositionClose(ticket))
            VEM_Log_TradeFail("MidlineClose", g_vem_trade.ResultRetcode());
         continue;
        }

      double vol = PositionGetDouble(POSITION_VOLUME);
      double close_vol = VEM_Risk_NormalizeVolume(sym, vol * partial_pct);
      if(close_vol < vmin)
         close_vol = vmin;

      if(vol - close_vol < vmin - 1e-12)
        {
         VEM_Log_Verbose("Exit: BB midline full (partial remainder too small)");
         if(!g_vem_trade.PositionClose(ticket))
            VEM_Log_TradeFail("MidlineClose", g_vem_trade.ResultRetcode());
         continue;
        }

      if(vstep > 0.0)
         close_vol = MathFloor(close_vol / vstep + 1e-12) * vstep;

      if(!g_vem_trade.PositionClosePartial(ticket, close_vol))
        {
         VEM_Log_TradeFail("PartialMidline", g_vem_trade.ResultRetcode());
         continue;
        }

      VEM_Exec_PartialMark(ticket);
      if(inp_e11_payoff_enable)
         VEM_Log_Info(StringFormat("E11 partial midline #%s %s mfe=%.2fR closed %.4f of %.4f",
                                   (string)ticket,
                                   ptype == POSITION_TYPE_BUY ? "buy" : "sell",
                                   mfe_r, close_vol, vol));
      else
         VEM_Log_Info(StringFormat("E9 partial midline #%s %s closed %.4f of %.4f",
                                   (string)ticket,
                                   ptype == POSITION_TYPE_BUY ? "buy" : "sell",
                                   close_vol, vol));
     }
  }

inline void VEM_Execution_ManageExits(const string sym, const ENUM_TIMEFRAMES tf,
                                      const VEMIndicatorSnap &s,
                                      const bool want_long, const bool want_short)
  {
   if(!s.valid)
      return;

   // (1) Breakeven — lock SL before midline close / giveback
   VEM_Execution_ManageBreakeven(sym, tf, s);

   // (2) Soft SL tighten (E14) — cap loss before scratch exits
   VEM_Execution_ManageSoftSlTighten(sym, tf, s);

   // (3) Mean-reversion: BB midline (full, E9, or E11 conditional partial)
   VEM_Execution_MidlineExits(sym, tf, s);

   // (4) MAE/MFE invalidation (E10) — before structural / E8
   VEM_Execution_CheckInvalidationExits(sym, tf, s);

   // (5) BB penetration worsened (E8c) — before late bleed / E8a/E8b
   VEM_Execution_CheckWorseStructureExits(sym, tf, s);

   // (6) Late low-MFE bleed (E13) — Type C; after E8c window
   VEM_Execution_CheckBleedExits(sym, tf, s);

   // (7) Failure-to-revert (E8a/E8b) — before full SL
   VEM_Execution_CheckFailureExits(sym, tf, s);

   // (8) Emergency / regime flip
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

inline double VEM_Exec_AiEntryLotMult(const string sym, const ENUM_TIMEFRAMES tf,
                                      const int signal_shift,
                                      const VEMIndicatorSnap &entry_s,
                                      const ENUM_ORDER_TYPE otype,
                                      string &ai_reason)
  {
   ai_reason = "";
   if(!entry_s.valid)
      return 1.0;
   if(!inp_ai_skip_enable && !inp_ai_half_lot_enable)
      return 1.0;

   const bool is_sell = (otype == ORDER_TYPE_SELL);
   const double score = VEM_AI_ScoreBadTrade(sym, entry_s, is_sell);
   const double mult = VEM_AI_EntryLotMultiplier(score);

   if(mult <= 0.0)
     {
      ai_reason = "ai_skip";
      VEM_AIShadow_LogAttempt(sym, tf, signal_shift, entry_s, otype, false, ai_reason);
      VEM_Log_Verbose(StringFormat("Skip %s: ai_score=%.4f >= skip %.4f",
                                   is_sell ? "sell" : "buy", score, VEM_AI_SkipThreshold()));
      return 0.0;
     }
   if(mult < 1.0)
     {
      ai_reason = "ai_half_lot";
      VEM_Log_Verbose(StringFormat("Half lot %s: ai_score=%.4f [%.4f, %.4f)",
                                   is_sell ? "sell" : "buy", score,
                                   inp_ai_half_lot_prob_min, VEM_AI_SkipThreshold()));
     }
   return mult;
  }

inline bool VEM_Execution_OpenBuy(const string sym, const ENUM_TIMEFRAMES tf,
                                const int signal_shift, const VEMIndicatorSnap &entry_s,
                                const VEMIndicatorSnap &bar_s)
  {
   string r;
   if(!VEM_Risk_AllowNewTrade(sym, tf, ORDER_TYPE_BUY, signal_shift, entry_s, r))
     {
      VEM_Log_Verbose(StringFormat("Skip buy: %s", r));
      VEM_AIShadow_LogAttempt(sym, tf, signal_shift, entry_s, ORDER_TYPE_BUY, false, r);
      return false;
     }

   string ai_r;
   const double ai_mult = VEM_Exec_AiEntryLotMult(sym, tf, signal_shift, entry_s, ORDER_TYPE_BUY, ai_r);
   if(ai_mult <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   const double sl_dist = VEM_Risk_SlDistancePrice(sym, bar_s);
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
   lots = VEM_Risk_NormalizeVolume(sym, lots * ai_mult);
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
      VEM_AIShadow_LogAttempt(sym, tf, signal_shift, entry_s, ORDER_TYPE_BUY, false, "order_send_fail");
      return false;
     }

   VEM_AIShadow_LogAttempt(sym, tf, signal_shift, entry_s, ORDER_TYPE_BUY, true, ai_r);
   VEM_State_SetLastEntryBarTime(entry_s.bar_time);
   VEM_TradeLog_RegisterEntry(sym, tf, entry_s, ORDER_TYPE_BUY, ask, sl_dist, g_vem_trade.ResultDeal());
   if(inp_worse_struct_exit_enable)
     {
      const ulong nt = VEM_Exec_NewestPositionTicket(sym, POSITION_TYPE_BUY);
      VEM_Exec_StructPenRegister(nt, VEM_Exec_BbPenLong(entry_s.close, entry_s.bb_lower));
     }
   VEM_Log_Info(StringFormat("Buy OK lots=%.4f SL=%.5f TP=%.5f", lots, sl, tp));
   return true;
  }

inline bool VEM_Execution_OpenSell(const string sym, const ENUM_TIMEFRAMES tf,
                                 const int signal_shift, const VEMIndicatorSnap &entry_s,
                                 const VEMIndicatorSnap &bar_s)
  {
   string r;
   if(!VEM_Risk_AllowNewTrade(sym, tf, ORDER_TYPE_SELL, signal_shift, entry_s, r))
     {
      VEM_Log_Verbose(StringFormat("Skip sell: %s", r));
      VEM_AIShadow_LogAttempt(sym, tf, signal_shift, entry_s, ORDER_TYPE_SELL, false, r);
      return false;
     }

   string ai_r;
   const double ai_mult = VEM_Exec_AiEntryLotMult(sym, tf, signal_shift, entry_s, ORDER_TYPE_SELL, ai_r);
   if(ai_mult <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   const double sl_dist = VEM_Risk_SlDistancePrice(sym, bar_s);
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
   lots = VEM_Risk_NormalizeVolume(sym, lots * ai_mult);
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
      VEM_AIShadow_LogAttempt(sym, tf, signal_shift, entry_s, ORDER_TYPE_SELL, false, "order_send_fail");
      return false;
     }

   VEM_AIShadow_LogAttempt(sym, tf, signal_shift, entry_s, ORDER_TYPE_SELL, true, ai_r);
   VEM_State_SetLastEntryBarTime(entry_s.bar_time);
   VEM_TradeLog_RegisterEntry(sym, tf, entry_s, ORDER_TYPE_SELL, bid, sl_dist, g_vem_trade.ResultDeal());
   if(inp_worse_struct_exit_enable)
     {
      const ulong nt = VEM_Exec_NewestPositionTicket(sym, POSITION_TYPE_SELL);
      VEM_Exec_StructPenRegister(nt, VEM_Exec_BbPenShort(entry_s.close, entry_s.bb_upper));
     }
   VEM_Log_Info(StringFormat("Sell OK lots=%.4f SL=%.5f TP=%.5f", lots, sl, tp));
   return true;
  }

inline void VEM_Execution_ProcessBar(const string sym, const ENUM_TIMEFRAMES tf,
                                     const int signal_shift, const VEMIndicatorSnap &bar_s,
                                     const VEMIndicatorSnap &entry_s,
                                     const bool want_long, const bool want_short)
  {
   VEM_TradeLog_Update(sym, tf);
   VEM_Execution_ManageExits(sym, tf, bar_s, want_long, want_short);

   if(want_long && want_short)
     {
      VEM_Log_Verbose("Skip entries: long and short both true on bar");
      return;
     }

   if(want_long && inp_direction != VEM_TRADE_SHORT_ONLY)
      VEM_Execution_OpenBuy(sym, tf, signal_shift, entry_s, bar_s);

   if(want_short && inp_direction != VEM_TRADE_LONG_ONLY)
      VEM_Execution_OpenSell(sym, tf, signal_shift, entry_s, bar_s);

   if(inp_log_verbose && bar_s.valid)
      VEM_Log_Verbose(StringFormat(
                         "Bar=%s L=%s S=%s rsi=%.2f bbL=%.5f hi=%.5f lo=%.5f vol=%.0f vma=%.0f",
                         TimeToString(bar_s.bar_time, TIME_DATE | TIME_MINUTES),
                         want_long ? "Y" : "N",
                         want_short ? "Y" : "N",
                         bar_s.rsi, bar_s.bb_lower, bar_s.high, bar_s.low, bar_s.volume, bar_s.volume_ma));
  }

#endif // VEM_EXECUTION_MQH
