//+------------------------------------------------------------------+
//| VEM_TradeLog.mqh — C1/C2 closed-trade CSV (MAE/MFE + entry)       |
//+------------------------------------------------------------------+
#ifndef VEM_TRADELOG_MQH
#define VEM_TRADELOG_MQH

#include <VEM/VEM_Config.mqh>
#include <VEM/VEM_Log.mqh>
#include <VEM/VEM_Indicators.mqh>

inline int VEM_TLog_BarsInTrade(const string sym, const ENUM_TIMEFRAMES tf, const datetime open_time)
  {
   const int entry_shift = iBarShift(sym, tf, open_time, true);
   if(entry_shift < 0)
      return 0;
   return MathMax(0, entry_shift - 1);
  }

inline void VEM_TLog_ExcursionsInR(const string sym, const ENUM_TIMEFRAMES tf, const int entry_shift,
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

#define VEM_TLOG_MAX 32

struct VEMTradeLogTrack
  {
   ulong    position_id;
   datetime entry_time;
   double   entry_px;
   int      side;           // +1 buy, -1 sell
   double   sl_dist;
   double   rsi;
   double   bb_width_ratio;
   double   vol_ratio;
   int      spread_pts;
   int      entry_hour;
   int      entry_dow;
   // C2 entry structure
   double   rsi_depth;
   int      bb_walk_count;
   double   wick_pct;
   double   ema_slope_bp;
   double   atr_ratio;
   double   bb_pen_pts;
   double   htf_slope_bp;
   double   mae_r;
   double   mfe_r;
   double   mae_r_b4;
   double   mfe_r_b4;
   double   mae_r_b5;
   double   mfe_r_b5;
   double   mae_r_b6;
   double   mfe_r_b6;
   int      bars_max;
   bool     snap4;
   bool     snap5;
   bool     snap6;
   double   profit_acc;
   string   exit_type_last;
  };

static VEMTradeLogTrack g_vem_tlog[VEM_TLOG_MAX];
static int              g_vem_tlog_n = 0;
static int              g_vem_tlog_handle = INVALID_HANDLE;
static bool             g_vem_tlog_header_ok = false;
static ulong            g_vem_tlog_pending_pos = 0;
static string           g_vem_tlog_pending_exit = "";
static int              g_vem_tlog_htf_ema = INVALID_HANDLE;

inline bool VEM_TLog_IsV2()
  {
   return (inp_trade_log_schema >= 2);
  }

inline double VEM_TLog_WickPct(const bool is_long, const VEMIndicatorSnap &s)
  {
   const double rng = s.high - s.low;
   if(rng <= 0.0)
      return 0.0;
   if(is_long)
      return 100.0 * (MathMin(s.open, s.close) - s.low) / rng;
   return 100.0 * (s.high - MathMax(s.open, s.close)) / rng;
  }

inline double VEM_TLog_BbPenPts(const string sym, const bool is_long, const VEMIndicatorSnap &s)
  {
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(pt <= 0.0)
      return 0.0;
   if(is_long)
      return MathMax(0.0, (s.bb_lower - s.close) / pt);
   return MathMax(0.0, (s.close - s.bb_upper) / pt);
  }

inline double VEM_TLog_RsiDepth(const bool is_long, const double rsi)
  {
   if(is_long)
      return MathMax(0.0, inp_rsi_long_max_depth - rsi);
   return MathMax(0.0, rsi - inp_rsi_short_min_depth);
  }

inline double VEM_TLog_AtrRatio(const VEMIndicatorSnap &s)
  {
   if(s.close <= 0.0)
      return 0.0;
   return s.atr / s.close;
  }

inline bool VEM_TLog_HtfSlopeBp(const string sym, const datetime bar_time, double &slope_bp_out)
  {
   slope_bp_out = 0.0;
   if(g_vem_tlog_htf_ema == INVALID_HANDLE || bar_time <= 0)
      return false;

   const int shift = iBarShift(sym, inp_htf_timeframe, bar_time, true);
   if(shift < 0)
      return false;

   const int lookback = MathMax(1, inp_htf_slope_lookback_bars);
   double ema_now[], ema_prev[];
   ArraySetAsSeries(ema_now, true);
   ArraySetAsSeries(ema_prev, true);

   if(CopyBuffer(g_vem_tlog_htf_ema, 0, shift, 1, ema_now) <= 0)
      return false;
   if(CopyBuffer(g_vem_tlog_htf_ema, 0, shift + lookback, 1, ema_prev) <= 0)
      return false;
   if(ema_prev[0] <= 0.0)
      return false;

   slope_bp_out = (ema_now[0] - ema_prev[0]) / ema_prev[0] * 10000.0;
   return true;
  }

inline void VEM_TLog_StageExit(const ulong position_id, const string exit_type)
  {
   g_vem_tlog_pending_pos = position_id;
   g_vem_tlog_pending_exit = exit_type;
  }

inline void VEM_TLog_ClearPendingExit()
  {
   g_vem_tlog_pending_pos = 0;
   g_vem_tlog_pending_exit = "";
  }

inline string VEM_TLog_FileName(const string sym, const ENUM_TIMEFRAMES tf)
  {
   string tf_s = EnumToString(tf);
   StringReplace(tf_s, "PERIOD_", "");
   if(VEM_TLog_IsV2())
      return StringFormat("VEM_trades_v2_%s_%s.csv", sym, tf_s);
   return StringFormat("VEM_trades_%s_%s.csv", sym, tf_s);
  }

inline bool VEM_TLog_OpenFile(const string sym, const ENUM_TIMEFRAMES tf)
  {
   if(g_vem_tlog_handle != INVALID_HANDLE)
      return true;

   const string path = VEM_TLog_FileName(sym, tf);
   const bool exists = FileIsExist(path, FILE_COMMON);
   g_vem_tlog_handle = FileOpen(path, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(g_vem_tlog_handle == INVALID_HANDLE)
     {
      VEM_Log_Info(StringFormat("TradeLog: FileOpen failed %s err=%d", path, GetLastError()));
      return false;
     }

   if(!exists || FileSize(g_vem_tlog_handle) == 0)
     {
      if(VEM_TLog_IsV2())
        {
         FileWrite(g_vem_tlog_handle,
                   "log_schema", "trade_id", "entry_time", "exit_time", "symbol", "timeframe", "side",
                   "entry_px", "exit_px", "profit", "exit_type", "bars_held",
                   "rsi", "bb_width_ratio", "vol_ratio", "spread_pts", "entry_hour", "entry_dow",
                   "rsi_depth", "bb_walk_count", "wick_pct", "ema_slope_bp", "atr_ratio", "bb_pen_pts",
                   "htf_slope_bp",
                   "mae_r", "mfe_r", "mae_r_b4", "mfe_r_b4", "mae_r_b5", "mfe_r_b5", "mae_r_b6", "mfe_r_b6",
                   "sl_pts");
        }
      else
        {
         FileWrite(g_vem_tlog_handle,
                   "entry_time", "exit_time", "symbol", "timeframe", "side",
                   "entry_px", "exit_px", "profit", "exit_type", "bars_held",
                   "rsi", "bb_width_ratio", "vol_ratio", "spread_pts", "entry_hour", "entry_dow",
                   "mae_r", "mfe_r", "mae_r_b5", "mfe_r_b5", "mae_r_b6", "mfe_r_b6", "sl_pts");
        }
      g_vem_tlog_header_ok = true;
     }
   else
     {
      FileSeek(g_vem_tlog_handle, 0, SEEK_END);
      g_vem_tlog_header_ok = true;
     }
   return true;
  }

inline void VEM_TLog_CloseFile()
  {
   if(g_vem_tlog_handle != INVALID_HANDLE)
     {
      FileClose(g_vem_tlog_handle);
      g_vem_tlog_handle = INVALID_HANDLE;
     }
  }

inline int VEM_TLog_FindPos(const ulong position_id)
  {
   for(int i = 0; i < g_vem_tlog_n; ++i)
      if(g_vem_tlog[i].position_id == position_id)
         return i;
   return -1;
  }

inline void VEM_TLog_RemoveAt(const int idx)
  {
   if(idx < 0 || idx >= g_vem_tlog_n)
      return;
   g_vem_tlog[idx] = g_vem_tlog[g_vem_tlog_n - 1];
   g_vem_tlog_n--;
  }

inline string VEM_TLog_ExitTypeFromDeal(const ulong deal_ticket)
  {
   if(!HistoryDealSelect(deal_ticket))
      return "other";
   string c = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
   StringToLower(c);
   const string cl = c;
   if(StringFind(cl, "sl") >= 0 || StringFind(cl, "stop loss") >= 0)
      return "sl";
   if(StringFind(cl, "tp") >= 0 || StringFind(cl, "take profit") >= 0)
      return "tp";
   if(StringFind(cl, "fail") >= 0 || StringFind(cl, "e8") >= 0)
      return "fail_exit";
   if(StringFind(cl, "e8c") >= 0 || StringFind(cl, "worse") >= 0)
      return "e8c";
   if(StringFind(cl, "inv") >= 0 || StringFind(cl, "e10") >= 0)
      return "e10";
   if(StringFind(cl, "e13") >= 0 || StringFind(cl, "bleed") >= 0)
      return "e13";
   if(StringFind(cl, "e14") >= 0 || StringFind(cl, "soft") >= 0)
      return "e14";
   return "midline";
  }

inline string VEM_TLog_FmtR(const double v)
  {
   if(v < 0.0)
      return "";
   return DoubleToString(v, 4);
  }

inline void VEM_TLog_WriteRow(const string sym, const ENUM_TIMEFRAMES tf,
                              const VEMTradeLogTrack &tr, const datetime exit_time,
                              const double exit_px)
  {
   if(!VEM_TLog_OpenFile(sym, tf))
      return;

   const double sl_pts = (tr.sl_dist > 0.0) ?
                         tr.sl_dist / SymbolInfoDouble(sym, SYMBOL_POINT) : 0.0;
   const string side_s = (tr.side > 0) ? "buy" : "sell";
   string tf_s = EnumToString(tf);
   StringReplace(tf_s, "PERIOD_", "");
   const int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   if(VEM_TLog_IsV2())
     {
      FileWrite(g_vem_tlog_handle,
                "2",
                (string)tr.position_id,
                TimeToString(tr.entry_time, TIME_DATE | TIME_SECONDS),
                TimeToString(exit_time, TIME_DATE | TIME_SECONDS),
                sym, tf_s, side_s,
                DoubleToString(tr.entry_px, digits),
                DoubleToString(exit_px, digits),
                DoubleToString(tr.profit_acc, 2),
                tr.exit_type_last,
                (string)tr.bars_max,
                DoubleToString(tr.rsi, 2),
                DoubleToString(tr.bb_width_ratio, 6),
                DoubleToString(tr.vol_ratio, 3),
                (string)tr.spread_pts,
                (string)tr.entry_hour,
                (string)tr.entry_dow,
                DoubleToString(tr.rsi_depth, 2),
                (string)tr.bb_walk_count,
                DoubleToString(tr.wick_pct, 2),
                DoubleToString(tr.ema_slope_bp, 2),
                DoubleToString(tr.atr_ratio, 6),
                DoubleToString(tr.bb_pen_pts, 1),
                DoubleToString(tr.htf_slope_bp, 2),
                VEM_TLog_FmtR(tr.mae_r),
                VEM_TLog_FmtR(tr.mfe_r),
                VEM_TLog_FmtR(tr.mae_r_b4),
                VEM_TLog_FmtR(tr.mfe_r_b4),
                VEM_TLog_FmtR(tr.mae_r_b5),
                VEM_TLog_FmtR(tr.mfe_r_b5),
                VEM_TLog_FmtR(tr.mae_r_b6),
                VEM_TLog_FmtR(tr.mfe_r_b6),
                DoubleToString(sl_pts, 1));
     }
   else
     {
      FileWrite(g_vem_tlog_handle,
                TimeToString(tr.entry_time, TIME_DATE | TIME_SECONDS),
                TimeToString(exit_time, TIME_DATE | TIME_SECONDS),
                sym, tf_s, side_s,
                DoubleToString(tr.entry_px, digits),
                DoubleToString(exit_px, digits),
                DoubleToString(tr.profit_acc, 2),
                tr.exit_type_last,
                (string)tr.bars_max,
                DoubleToString(tr.rsi, 2),
                DoubleToString(tr.bb_width_ratio, 6),
                DoubleToString(tr.vol_ratio, 3),
                (string)tr.spread_pts,
                (string)tr.entry_hour,
                (string)tr.entry_dow,
                DoubleToString(tr.mae_r, 4),
                DoubleToString(tr.mfe_r, 4),
                DoubleToString(tr.mae_r_b5, 4),
                DoubleToString(tr.mfe_r_b5, 4),
                DoubleToString(tr.mae_r_b6, 4),
                DoubleToString(tr.mfe_r_b6, 4),
                DoubleToString(sl_pts, 1));
     }
   FileFlush(g_vem_tlog_handle);
  }

inline void VEM_TradeLog_OnInit(const string sym, const ENUM_TIMEFRAMES tf)
  {
   g_vem_tlog_n = 0;
   g_vem_tlog_header_ok = false;

   if(g_vem_tlog_htf_ema != INVALID_HANDLE)
     {
      IndicatorRelease(g_vem_tlog_htf_ema);
      g_vem_tlog_htf_ema = INVALID_HANDLE;
     }

   if(inp_trade_log_enable && VEM_TLog_IsV2())
     {
      const int htf_ema = MathMax(2, inp_htf_ema_period);
      g_vem_tlog_htf_ema = iMA(sym, inp_htf_timeframe, htf_ema, 0, MODE_EMA, PRICE_CLOSE);
      if(g_vem_tlog_htf_ema == INVALID_HANDLE)
         VEM_Log_Info("TradeLog C2: HTF EMA handle failed (htf_slope_bp will be 0)");
     }

   if(inp_trade_log_enable)
      VEM_TLog_OpenFile(sym, tf);
  }

inline void VEM_TradeLog_OnDeinit()
  {
   VEM_TLog_CloseFile();
   if(g_vem_tlog_htf_ema != INVALID_HANDLE)
     {
      IndicatorRelease(g_vem_tlog_htf_ema);
      g_vem_tlog_htf_ema = INVALID_HANDLE;
     }
   g_vem_tlog_n = 0;
  }

inline void VEM_TradeLog_RegisterEntry(const string sym, const ENUM_TIMEFRAMES tf,
                                       const int signal_shift,
                                       const VEMIndicatorSnap &s,
                                       const ENUM_ORDER_TYPE otype, const double entry_px,
                                       const double sl_dist, const ulong deal_ticket)
  {
   if(!inp_trade_log_enable || sl_dist <= 0.0)
      return;
   if(!HistoryDealSelect(deal_ticket))
      return;

   const ulong pos_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   if(pos_id == 0 || VEM_TLog_FindPos(pos_id) >= 0)
      return;
   if(g_vem_tlog_n >= VEM_TLOG_MAX)
     {
      VEM_Log_Info("TradeLog: track buffer full");
      return;
     }

   const bool is_long = (otype == ORDER_TYPE_BUY);

   VEMTradeLogTrack tr;
   ZeroMemory(tr);
   tr.position_id = pos_id;
   tr.entry_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   tr.entry_px = entry_px;
   tr.side = is_long ? 1 : -1;
   tr.sl_dist = sl_dist;
   tr.rsi = s.rsi;
   tr.bb_width_ratio = VEM_Indicators_BBWidthRatio(s);
   tr.vol_ratio = (s.volume_ma > 0.0) ? s.volume / s.volume_ma : 0.0;
   tr.spread_pts = (int)SymbolInfoInteger(sym, SYMBOL_SPREAD);
   MqlDateTime dt;
   TimeToStruct(s.bar_time, dt);
   tr.entry_hour = dt.hour;
   tr.entry_dow = dt.day_of_week;
   tr.mae_r_b4 = tr.mfe_r_b4 = tr.mae_r_b5 = tr.mfe_r_b5 = tr.mae_r_b6 = tr.mfe_r_b6 = -1.0;
   tr.exit_type_last = "open";

   if(VEM_TLog_IsV2())
     {
      tr.rsi_depth = VEM_TLog_RsiDepth(is_long, s.rsi);
      tr.bb_walk_count = VEM_Indicators_BBWalkCount(sym, tf, signal_shift, is_long);
      tr.wick_pct = VEM_TLog_WickPct(is_long, s);
      tr.bb_pen_pts = VEM_TLog_BbPenPts(sym, is_long, s);
      tr.atr_ratio = VEM_TLog_AtrRatio(s);
      if(!VEM_Indicators_EMASlopeBp(sym, tf, signal_shift, tr.ema_slope_bp))
         tr.ema_slope_bp = 0.0;
      if(!VEM_TLog_HtfSlopeBp(sym, s.bar_time, tr.htf_slope_bp))
         tr.htf_slope_bp = 0.0;
     }

   g_vem_tlog[g_vem_tlog_n++] = tr;
  }

inline bool VEM_TLog_SelectByPosId(const string sym, const ulong position_id)
  {
   const int total = PositionsTotal();
   for(int p = total - 1; p >= 0; --p)
     {
      const ulong tk = PositionGetTicket(p);
      if(tk == 0 || !PositionSelectByTicket(tk))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != inp_magic)
         continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == position_id)
         return true;
     }
   return false;
  }

inline void VEM_TradeLog_Update(const string sym, const ENUM_TIMEFRAMES tf)
  {
   if(!inp_trade_log_enable || g_vem_tlog_n == 0)
      return;

   for(int i = g_vem_tlog_n - 1; i >= 0; --i)
     {
      const ulong pos_id = g_vem_tlog[i].position_id;
      if(!VEM_TLog_SelectByPosId(sym, pos_id))
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const int entry_shift = iBarShift(sym, tf, open_time, true);
      const int bars = VEM_TLog_BarsInTrade(sym, tf, open_time);

      double mae = 0.0, mfe = 0.0;
      VEM_TLog_ExcursionsInR(sym, tf, entry_shift, ptype, entry, g_vem_tlog[i].sl_dist, mae, mfe);
      g_vem_tlog[i].mae_r = mae;
      g_vem_tlog[i].mfe_r = mfe;
      g_vem_tlog[i].bars_max = MathMax(g_vem_tlog[i].bars_max, bars);

      if(bars >= 4 && !g_vem_tlog[i].snap4)
        {
         g_vem_tlog[i].mae_r_b4 = mae;
         g_vem_tlog[i].mfe_r_b4 = mfe;
         g_vem_tlog[i].snap4 = true;
        }
      if(bars >= 5 && !g_vem_tlog[i].snap5)
        {
         g_vem_tlog[i].mae_r_b5 = mae;
         g_vem_tlog[i].mfe_r_b5 = mfe;
         g_vem_tlog[i].snap5 = true;
        }
      const int snap_bar = MathMax(5, inp_trade_log_snap_bar);
      if(bars >= snap_bar && !g_vem_tlog[i].snap6)
        {
         g_vem_tlog[i].mae_r_b6 = mae;
         g_vem_tlog[i].mfe_r_b6 = mfe;
         g_vem_tlog[i].snap6 = true;
        }
     }
  }

inline bool VEM_TLog_PositionOpen(const string sym, const ulong position_id)
  {
   const int total = PositionsTotal();
   for(int p = total - 1; p >= 0; --p)
     {
      const ulong tk = PositionGetTicket(p);
      if(tk == 0 || !PositionSelectByTicket(tk))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != inp_magic)
         continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == position_id)
         return true;
     }
   return false;
  }

inline void VEM_TradeLog_Finalize(const string sym, const ENUM_TIMEFRAMES tf,
                                  const int idx, const datetime exit_time,
                                  const double exit_px)
  {
   if(idx < 0 || idx >= g_vem_tlog_n)
      return;
   VEM_TLog_WriteRow(sym, tf, g_vem_tlog[idx], exit_time, exit_px);
   VEM_TLog_RemoveAt(idx);
  }

inline void VEM_TradeLog_OnTransaction(const string sym, const ENUM_TIMEFRAMES tf,
                                       const MqlTradeTransaction &trans,
                                       const MqlTradeRequest &request,
                                       const MqlTradeResult &result)
  {
   if(!inp_trade_log_enable)
      return;
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != sym)
      return;
   if((long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != inp_magic)
      return;

   const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN)
      return;

   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
      return;

   const ulong pos_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   const int idx = VEM_TLog_FindPos(pos_id);
   if(idx < 0)
      return;

   const datetime exit_time = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   const double exit_px = HistoryDealGetDouble(trans.deal, DEAL_PRICE);

   g_vem_tlog[idx].profit_acc += HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                                HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                                HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   string exit_tag = VEM_TLog_ExitTypeFromDeal(trans.deal);
   if(g_vem_tlog_pending_pos == pos_id && g_vem_tlog_pending_exit != "")
     {
      exit_tag = g_vem_tlog_pending_exit;
      VEM_TLog_ClearPendingExit();
     }
   g_vem_tlog[idx].exit_type_last = exit_tag;

   if(!VEM_TLog_PositionOpen(sym, pos_id))
      VEM_TradeLog_Finalize(sym, tf, idx, exit_time, exit_px);
  }

#endif // VEM_TRADELOG_MQH
