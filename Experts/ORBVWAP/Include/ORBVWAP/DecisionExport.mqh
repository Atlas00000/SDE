//+------------------------------------------------------------------+
//| DecisionExport.mqh — AI-0 decision & outcome CSV export          |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_DECISIONEXPORT_MQH__
#define __ORBVWAP_DECISIONEXPORT_MQH__

#include "Inputs.mqh"
#include "Constants.mqh"
#include "Types.mqh"
#include "SessionUtils.mqh"
#include "OpeningRange.mqh"
#include "SessionVwap.mqh"
#include "IndicatorManager.mqh"
#include "AiFeatures.mqh"

class CDecisionExport
  {
   static int s_next_id;

   static string SessionTag(const SSessionContext &session)
     {
      if(session.session == ORBVWAP_SESSION_LONDON)
         return("LONDON");
      if(session.session == ORBVWAP_SESSION_NY)
         return("NY");
      return("NONE");
     }

   static int SpreadPoints(const string symbol)
     {
      const double ask   = SymbolInfoDouble(symbol, SYMBOL_ASK);
      const double bid   = SymbolInfoDouble(symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return(0);
      return((int)MathRound((ask - bid) / point));
     }

   static void WriteLine(const string filename, const string header, const string line)
     {
      const int handle = FileOpen(filename,
                                  FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
      if(handle == INVALID_HANDLE)
         return;

      const bool is_new = (FileSize(handle) == 0);
      FileSeek(handle, 0, SEEK_END);
      if(is_new)
         FileWriteString(handle, header + "\r\n");
      FileWriteString(handle, line + "\r\n");
      FileClose(handle);
     }

public:
   static void Reset()
     {
      s_next_id = 1;
     }

   static int AllocateDecisionId()
     {
      const int id = s_next_id;
      s_next_id++;
      return(id);
     }

   static void LogPipeline(const string               symbol,
                         const SSessionContext       &session,
                         const SSignalResult         &signal_result,
                         COpeningRange               &opening_range,
                         CSessionVwap                &session_vwap,
                         CIndicatorManager           &indicators,
                         const bool                   can_trade_ok,
                         const string                 can_trade_reject,
                         const STradeSetup           &setup,
                         const bool                   setup_ok,
                         const bool                   executed,
                         const ulong                  position_id,
                         const int                    decision_id)
     {
      if(!InpEnableDecisionExport)
         return;
      if(signal_result.signal == ORBVWAP_SIGNAL_NONE)
         return;

      const datetime signal_bar_time = iTime(symbol, PERIOD_CURRENT, 1);
      const datetime bar_gmt           = CSessionUtils::BarTimeToGmt(signal_bar_time);

      MqlDateTime dt;
      TimeToStruct(bar_gmt, dt);

      double atr = 0.0;
      indicators.GetATR(1, atr);

      const double range_width = opening_range.Width();
      const double min_rr = setup_ok ? setup.risk_reward : 0.0;

      double feats[];
      CAiFeatures::FillAi1(symbol, session, signal_result.signal, opening_range, session_vwap,
                           indicators, min_rr, feats);

      const double range_width_atr = feats[0];
      const double vol_ratio = feats[1];
      const double vwap_dist_atr = feats[2];
      const double spread_pct_range = feats[3];
      const int spread_pts = SpreadPoints(symbol);

      int ny_min_since_open = (int)feats[7];

      string reject_stage = "";
      string reject_code  = "";
      if(!can_trade_ok)
        {
         reject_stage = "CAN_TRADE";
         reject_code  = can_trade_reject;
        }
      else if(!setup_ok)
        {
         reject_stage = "SETUP";
         reject_code  = setup.reject_reason;
        }

      const string line = StringFormat(
         "%d,%s,%s,%s,%d,%d,%d,%.5f,%.4f,%.5f,%.4f,%.4f,%.2f,%d,%.4f,%.5f,%.5f,%.5f,%d,%d,%d,%s,%s,%I64u",
         decision_id,
         TimeToString(bar_gmt, TIME_DATE | TIME_SECONDS),
         OrbVwapSignalDirection(signal_result.signal),
         SessionTag(session),
         dt.hour,
         dt.day_of_week,
         ny_min_since_open,
         range_width,
         range_width_atr,
         atr,
         vol_ratio,
         vwap_dist_atr,
         spread_pct_range,
         spread_pts,
         min_rr,
         setup.entry_price,
         setup.sl,
         setup.tp,
         can_trade_ok ? 1 : 0,
         setup_ok ? 1 : 0,
         executed ? 1 : 0,
         reject_stage,
         reject_code,
         position_id);

      string header =
         "decision_id,bar_time_gmt,direction,session,hour_gmt,weekday,ny_min_since_open,"
         "range_width,range_width_atr,atr,vol_ratio,vwap_dist_atr,spread_pct_range,"
         "spread_points,min_rr,entry,sl,tp,can_trade_ok,setup_ok,prod_executed,"
         "reject_stage,reject_code,position_id";
      string out_line = line;

      if(InpEnableFeatureParityExport)
        {
         header += "," + CAiFeatures::FeatureNamesCsv();
         out_line += "," + CAiFeatures::FeatureValuesCsv(feats);
        }

      WriteLine(ORBVWAP_DECISIONS_FILE, header, out_line);
     }

   static void OnTradeTransaction(const MqlTradeTransaction &trans)
     {
      if(!InpEnableDecisionExport)
         return;
      if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
         return;

      const ulong deal_ticket = trans.deal;
      if(deal_ticket == 0)
         return;
      if(!HistoryDealSelect(deal_ticket))
         return;

      if((long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != InpMagicNumber)
         return;

      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         return;

      const ulong  position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      const double profit      = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT)
                                 + HistoryDealGetDouble(deal_ticket, DEAL_SWAP)
                                 + HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
      const int    label_win   = (profit > 0.0) ? 1 : 0;
      const datetime close_gmt = CSessionUtils::BarTimeToGmt((datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME));

      const string line = StringFormat("%I64u,%s,%.2f,%d",
                                       position_id,
                                       TimeToString(close_gmt, TIME_DATE | TIME_SECONDS),
                                       profit,
                                       label_win);

      WriteLine(ORBVWAP_OUTCOMES_FILE,
                "position_id,close_time_gmt,profit,label_win",
                line);
     }
  };

int CDecisionExport::s_next_id = 1;

#endif // __ORBVWAP_DECISIONEXPORT_MQH__
