//+------------------------------------------------------------------+
//| ExecutionEngine.mqh                                              |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_EXECUTIONENGINE_MQH__
#define __ORBVWAP_EXECUTIONENGINE_MQH__

#include <Trade/Trade.mqh>
#include "Inputs.mqh"
#include "Constants.mqh"
#include "Types.mqh"
#include "RiskEngine.mqh"
#include "Logger.mqh"
#include "PathTracker.mqh"
#include "AiRuntime.mqh"

class CExecutionEngine
  {
   CTrade  m_trade;
   long    m_magic;
   ulong   m_last_position_id;
   ulong   m_partial_done[];

   bool IsPartialDone(const ulong ticket) const
     {
      for(int i = 0; i < ArraySize(m_partial_done); i++)
        {
         if(m_partial_done[i] == ticket)
            return(true);
        }
      return(false);
     }

   void MarkPartialDone(const ulong ticket)
     {
      if(IsPartialDone(ticket))
         return;
      const int n = ArraySize(m_partial_done);
      ArrayResize(m_partial_done, n + 1);
      m_partial_done[n] = ticket;
     }

   void PrunePartialDone()
     {
      for(int i = ArraySize(m_partial_done) - 1; i >= 0; i--)
        {
         if(!PositionSelectByTicket(m_partial_done[i]))
           {
            const int last = ArraySize(m_partial_done) - 1;
            if(i != last)
               m_partial_done[i] = m_partial_done[last];
            ArrayResize(m_partial_done, last);
           }
        }
     }

   static double CalcPartialCloseVolume(const string symbol, const double pos_volume, const double pct)
     {
      if(pct <= 0.0 || pct >= 100.0 || pos_volume <= 0.0)
         return(0.0);

      const double vmin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double close_vol = CRiskEngine::NormalizeVolumePublic(symbol, pos_volume * pct / 100.0);
      const double remain = pos_volume - close_vol;

      if(close_vol < vmin || remain < vmin)
         return(0.0);
      return(close_vol);
     }

   static double NormalizePrice(const string symbol, const double price)
     {
      const double tick = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tick <= 0.0)
         return(price);
      return(MathRound(price / tick) * tick);
     }

   static string BuildTradeComment(const double range_width)
     {
      if(range_width <= 0.0)
         return(ORBVWAP_TRADE_COMMENT);
      return(StringFormat("%s|w=%.5f", ORBVWAP_TRADE_COMMENT, range_width));
     }

   static double ParseRangeWidthFromComment(const string comment)
     {
      const int pos = StringFind(comment, "w=");
      if(pos < 0)
         return(0.0);
      return(StringToDouble(StringSubstr(comment, pos + 2)));
     }

   static double ResolveRangeWidth(const string symbol,
                                   const double entry,
                                   const double tp,
                                   const string comment)
     {
      double range_width = ParseRangeWidthFromComment(comment);
      if(range_width > 0.0)
         return(range_width);

      if(InpTpRangeMult > 0.0 && tp > 0.0)
         return(MathAbs(tp - entry) / InpTpRangeMult);

      return(0.0);
     }

   static bool IsSlAtOrBetterThanEntry(const ENUM_POSITION_TYPE pos_type,
                                       const double entry,
                                       const double sl,
                                       const double point)
     {
      const double eps = (point > 0.0) ? point * 0.5 : 1e-8;
      if(pos_type == POSITION_TYPE_BUY)
         return(sl >= entry - eps);
      return(sl <= entry + eps);
     }

   static ENUM_ORDER_TYPE_FILLING SelectFilling(const string symbol)
     {
      const int mode = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
      if((mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
         return(ORDER_FILLING_IOC);
      if((mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
         return(ORDER_FILLING_FOK);
      return(ORDER_FILLING_RETURN);
     }

   bool ValidateStops(const string symbol, const STradeSetup &setup, string &reject_reason) const
     {
      reject_reason = "";
      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const int stops_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      const double min_dist = stops_level * point;

      if(min_dist <= 0.0)
         return(true);

      const double sl_dist = MathAbs(setup.entry_price - setup.sl);
      const double tp_dist = MathAbs(setup.entry_price - setup.tp);

      if(sl_dist < min_dist)
        {
         reject_reason = ORBVWAP_REJECT_STOPS_INVALID + " min=" +
                         DoubleToString(min_dist, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
         return(false);
        }

      if(setup.tp > 0.0 && tp_dist < min_dist)
        {
         reject_reason = ORBVWAP_REJECT_STOPS_INVALID + " min=" +
                         DoubleToString(min_dist, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
         return(false);
        }
      return(true);
     }

   bool ValidateMargin(const string symbol, const STradeSetup &setup, string &reject_reason) const
     {
      reject_reason = "";
      const ENUM_ORDER_TYPE order_type = (setup.signal == ORBVWAP_SIGNAL_BUY) ?
                                         ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      double margin = 0.0;
      if(!OrderCalcMargin(order_type, symbol, setup.lot, setup.entry_price, margin))
        {
         reject_reason = ORBVWAP_REJECT_MARGIN;
         return(false);
        }

      const double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(margin > free_margin)
        {
         reject_reason = ORBVWAP_REJECT_MARGIN;
         return(false);
        }
      return(true);
     }

public:
   void Configure(const string symbol, const long magic)
     {
      m_magic = magic;
      m_trade.SetExpertMagicNumber((ulong)magic);
      m_trade.SetDeviationInPoints(InpSlippagePoints);
      m_trade.SetTypeFilling(SelectFilling(symbol));
      m_trade.SetAsyncMode(false);
      m_last_position_id = 0;
     }

   ulong LastPositionId() const
     {
      return(m_last_position_id);
     }

   bool OpenMarket(const string symbol, STradeSetup &setup)
     {
      if(setup.signal == ORBVWAP_SIGNAL_NONE)
        {
         setup.reject_reason = "no_signal";
         return(false);
        }

      setup.lot = CRiskEngine::NormalizeVolumePublic(symbol, setup.lot);
      if(setup.lot <= 0.0)
        {
         setup.reject_reason = ORBVWAP_REJECT_LOT_INVALID;
         COrbVwapLogger::Journal(ORBVWAP_REJECT_LOT_INVALID, "",
                                 OrbVwapSignalDirection(setup.signal));
         return(false);
        }

      string reject_reason = "";
      if(!ValidateStops(symbol, setup, reject_reason))
        {
         setup.reject_reason = reject_reason;
         COrbVwapLogger::Journal(ORBVWAP_REJECT_STOPS_INVALID, reject_reason,
                                 OrbVwapSignalDirection(setup.signal));
         return(false);
        }

      if(!ValidateMargin(symbol, setup, reject_reason))
        {
         setup.reject_reason = reject_reason;
         COrbVwapLogger::Journal(ORBVWAP_REJECT_MARGIN, reject_reason,
                                 OrbVwapSignalDirection(setup.signal));
         return(false);
        }

      const string comment = BuildTradeComment(setup.range_width);

      ResetLastError();
      bool ok = false;
      if(setup.signal == ORBVWAP_SIGNAL_BUY)
         ok = m_trade.Buy(setup.lot, symbol, 0.0, setup.sl, setup.tp, comment);
      else
         ok = m_trade.Sell(setup.lot, symbol, 0.0, setup.sl, setup.tp, comment);

      if(ok)
        {
         m_last_position_id = 0;
         const ulong deal_ticket = m_trade.ResultDeal();
         if(deal_ticket > 0 && HistoryDealSelect(deal_ticket))
            m_last_position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
         COrbVwapLogger::Info("Order placed position=" + (string)m_last_position_id);
         if(m_last_position_id > 0)
           {
            ulong pos_ticket = 0;
            for(int p = PositionsTotal() - 1; p >= 0; p--)
              {
               const ulong t = PositionGetTicket(p);
               if(t == 0)
                  continue;
               if(PositionGetString(POSITION_SYMBOL) != symbol)
                  continue;
               if((long)PositionGetInteger(POSITION_MAGIC) != m_magic)
                  continue;
               if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == m_last_position_id)
                 {
                  pos_ticket = t;
                  break;
                 }
              }
            if(pos_ticket > 0)
               CPathTracker::Register(pos_ticket, m_last_position_id, setup.range_width);
           }
         return(true);
        }

      setup.reject_reason = "retcode=" + IntegerToString((int)m_trade.ResultRetcode()) +
                            " " + m_trade.ResultRetcodeDescription();
      COrbVwapLogger::Error(setup.reject_reason);
      return(false);
     }

   void ManagePartialTakeProfit(const string symbol, const long magic)
     {
      if(InpPartialClosePct <= 0.0 || InpPartialAtRangeMult <= 0.0)
         return;

      PrunePartialDone();

      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      const double bid   = SymbolInfoDouble(symbol, SYMBOL_BID);
      const double ask   = SymbolInfoDouble(symbol, SYMBOL_ASK);

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(IsPartialDone(ticket))
            continue;

         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         const double sl    = PositionGetDouble(POSITION_SL);
         const double tp    = PositionGetDouble(POSITION_TP);
         const double volume = PositionGetDouble(POSITION_VOLUME);
         const string comment = PositionGetString(POSITION_COMMENT);

         const double range_width = ResolveRangeWidth(symbol, entry, tp, comment);
         if(range_width <= 0.0)
            continue;

         const double trigger_dist = range_width * InpPartialAtRangeMult;
         bool trigger_hit = false;
         if(pos_type == POSITION_TYPE_BUY)
            trigger_hit = (bid - entry) >= trigger_dist;
         else
            trigger_hit = (entry - ask) >= trigger_dist;

         if(!trigger_hit)
            continue;

         const double close_vol = CalcPartialCloseVolume(symbol, volume, InpPartialClosePct);
         if(close_vol <= 0.0)
           {
            COrbVwapLogger::Warn(StringFormat("Partial skip ticket=%I64u vol=%.2f pct=%.0f (lot step)",
                                               ticket, volume, InpPartialClosePct));
            continue;
           }

         ResetLastError();
         if(!m_trade.PositionClosePartial(ticket, close_vol))
           {
            COrbVwapLogger::Error(StringFormat("Partial close failed ticket=%I64u retcode=%d %s",
                                               ticket,
                                               (int)m_trade.ResultRetcode(),
                                               m_trade.ResultRetcodeDescription()));
            continue;
           }

         MarkPartialDone(ticket);

         double runner_tp = tp;
         if(InpRunnerTpRangeMult > 0.0)
           {
            if(pos_type == POSITION_TYPE_BUY)
               runner_tp = NormalizeDouble(NormalizePrice(symbol, entry + range_width * InpRunnerTpRangeMult), digits);
            else
               runner_tp = NormalizeDouble(NormalizePrice(symbol, entry - range_width * InpRunnerTpRangeMult), digits);

            if(!m_trade.PositionModify(ticket, sl, runner_tp))
              {
               COrbVwapLogger::Error(StringFormat("Runner TP modify failed ticket=%I64u retcode=%d %s",
                                                  ticket,
                                                  (int)m_trade.ResultRetcode(),
                                                  m_trade.ResultRetcodeDescription()));
              }

            COrbVwapLogger::Info(StringFormat("Partial close ticket=%I64u vol=%.2f at=%.2fx range runner_tp=%.5f",
                                               ticket, close_vol, InpPartialAtRangeMult, runner_tp));
           }
         else if(InpTrailAtr > 0.0)
           {
            if(!m_trade.PositionModify(ticket, sl, 0.0))
              {
               COrbVwapLogger::Error(StringFormat("Runner trail init failed ticket=%I64u retcode=%d %s",
                                                  ticket,
                                                  (int)m_trade.ResultRetcode(),
                                                  m_trade.ResultRetcodeDescription()));
              }
            else
              {
               COrbVwapLogger::Info(StringFormat("Partial close ticket=%I64u vol=%.2f at=%.2fx range runner=trail %.2f ATR",
                                                  ticket, close_vol, InpPartialAtRangeMult, InpTrailAtr));
              }
           }
         else
           {
            if(!m_trade.PositionModify(ticket, sl, 0.0))
              {
               COrbVwapLogger::Error(StringFormat("Runner time-stop init failed ticket=%I64u retcode=%d %s",
                                                  ticket,
                                                  (int)m_trade.ResultRetcode(),
                                                  m_trade.ResultRetcodeDescription()));
              }
            else
              {
               COrbVwapLogger::Info(StringFormat("Partial close ticket=%I64u vol=%.2f at=%.2fx range runner=time_stop %d min",
                                                  ticket, close_vol, InpPartialAtRangeMult, InpMaxHoldMinutes));
              }
           }
        }
     }

   void ManageRunnerTrail(const string symbol, const long magic, const double atr)
     {
      if(InpTrailAtr <= 0.0 || InpPartialClosePct <= 0.0 || InpRunnerTpRangeMult > 0.0)
         return;
      if(atr <= 0.0)
         return;

      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      const double bid   = SymbolInfoDouble(symbol, SYMBOL_BID);
      const double ask   = SymbolInfoDouble(symbol, SYMBOL_ASK);
      const double trail_dist = atr * InpTrailAtr;
      const double eps = (point > 0.0) ? point * 0.5 : 1e-8;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(!IsPartialDone(ticket))
            continue;

         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double sl = PositionGetDouble(POSITION_SL);
         const double tp = PositionGetDouble(POSITION_TP);

         double new_sl = 0.0;
         if(pos_type == POSITION_TYPE_BUY)
           {
            new_sl = NormalizeDouble(NormalizePrice(symbol, bid - trail_dist), digits);
            if(new_sl <= sl + eps || new_sl >= bid - eps)
               continue;
           }
         else
           {
            new_sl = NormalizeDouble(NormalizePrice(symbol, ask + trail_dist), digits);
            if(new_sl >= sl - eps && sl > 0.0)
               continue;
            if(new_sl <= ask + eps)
               continue;
           }

         ResetLastError();
         if(m_trade.PositionModify(ticket, new_sl, tp))
           {
            COrbVwapLogger::Info(StringFormat("Runner trail ticket=%I64u sl=%.5f trail=%.2f ATR",
                                               ticket, new_sl, InpTrailAtr));
           }
         else
           {
            COrbVwapLogger::Error(StringFormat("Runner trail failed ticket=%I64u retcode=%d %s",
                                               ticket,
                                               (int)m_trade.ResultRetcode(),
                                               m_trade.ResultRetcodeDescription()));
           }
        }
     }

   void ManageBreakEven(const string symbol, const long magic)
     {
      if(InpBeTrigger <= 0.0)
         return;

      const double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const int digits    = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      const double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
      const double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         const double sl    = PositionGetDouble(POSITION_SL);
         const double tp    = PositionGetDouble(POSITION_TP);
         const string comment = PositionGetString(POSITION_COMMENT);

         if(IsSlAtOrBetterThanEntry(pos_type, entry, sl, point))
            continue;

         const double range_width = ResolveRangeWidth(symbol, entry, tp, comment);
         if(range_width <= 0.0)
            continue;

         const double trigger_dist = range_width * InpBeTrigger;
         bool trigger_hit = false;
         if(pos_type == POSITION_TYPE_BUY)
            trigger_hit = (bid - entry) >= trigger_dist;
         else
            trigger_hit = (entry - ask) >= trigger_dist;

         if(!trigger_hit)
            continue;

         const double new_sl = NormalizeDouble(NormalizePrice(symbol, entry), digits);
         ResetLastError();
         if(m_trade.PositionModify(ticket, new_sl, tp))
           {
            COrbVwapLogger::Info(StringFormat("Break-even ticket=%I64u sl=%.5f trigger=%.2fx range",
                                               ticket, new_sl, InpBeTrigger));
           }
         else
           {
            COrbVwapLogger::Error(StringFormat("Break-even failed ticket=%I64u retcode=%d %s",
                                               ticket,
                                               (int)m_trade.ResultRetcode(),
                                               m_trade.ResultRetcodeDescription()));
           }
        }
     }

   void ManageTimeStops(const string symbol, const long magic)
     {
      if(InpMaxHoldMinutes <= 0)
         return;

      const int max_seconds = InpMaxHoldMinutes * 60;
      const datetime now = TimeCurrent();

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(open_time <= 0)
            continue;

         const int hold_seconds = (int)(now - open_time);
         if(hold_seconds < max_seconds)
            continue;

         ResetLastError();
         if(m_trade.PositionClose(ticket))
           {
            COrbVwapLogger::Info(StringFormat("Time stop closed ticket=%I64u hold_min=%d max=%d",
                                               ticket, hold_seconds / 60, InpMaxHoldMinutes));
           }
         else
           {
            COrbVwapLogger::Error(StringFormat("Time stop failed ticket=%I64u retcode=%d %s",
                                               ticket,
                                               (int)m_trade.ResultRetcode(),
                                               m_trade.ResultRetcodeDescription()));
           }
        }
     }

   void ManageAiStallScratch(const string symbol, const long magic)
     {
      if(InpAiExitMode == ORBVWAP_AI_EXIT_OFF)
         return;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         const int hold_min = CPathTracker::HoldMinutes(ticket);
         const double mfe_frac = CPathTracker::MfeFrac(ticket);
         const bool scratch = CAiRuntime::ShouldStallScratch(hold_min, mfe_frac);

         if(InpAiExitMode == ORBVWAP_AI_EXIT_SHADOW)
           {
            if(scratch)
               COrbVwapLogger::Info(StringFormat("AI4 shadow STALL ticket=%I64u hold=%d mfe_frac=%.2f",
                                                   ticket, hold_min, mfe_frac));
            continue;
           }

         if(!scratch)
            continue;

         ResetLastError();
         if(m_trade.PositionClose(ticket))
           {
            COrbVwapLogger::Info(StringFormat("AI4 stall scratch ticket=%I64u hold=%d mfe_frac=%.2f",
                                               ticket, hold_min, mfe_frac));
           }
         else
           {
            COrbVwapLogger::Error(StringFormat("AI4 stall failed ticket=%I64u retcode=%d %s",
                                               ticket,
                                               (int)m_trade.ResultRetcode(),
                                               m_trade.ResultRetcodeDescription()));
           }
        }
     }

   void ManageOpenPositions(const string symbol, const long magic, const double atr)
     {
      CPathTracker::Update(symbol, magic);
      ManageAiStallScratch(symbol, magic);
      ManagePartialTakeProfit(symbol, magic);
      ManageRunnerTrail(symbol, magic, atr);
      ManageBreakEven(symbol, magic);
      ManageTimeStops(symbol, magic);
     }
  };

#endif // __ORBVWAP_EXECUTIONENGINE_MQH__
