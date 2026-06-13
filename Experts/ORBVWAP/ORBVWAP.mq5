//+------------------------------------------------------------------+
//|                                                      ORBVWAP.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.22"

#include "Include/ORBVWAP/Types.mqh"
#include "Include/ORBVWAP/Constants.mqh"
#include "Include/ORBVWAP/Inputs.mqh"
#include "Include/ORBVWAP/Logger.mqh"
#include "Include/ORBVWAP/SessionUtils.mqh"
#include "Include/ORBVWAP/OpeningRange.mqh"
#include "Include/ORBVWAP/SessionVwap.mqh"
#include "Include/ORBVWAP/IndicatorManager.mqh"
#include "Include/ORBVWAP/SignalEngine.mqh"
#include "Include/ORBVWAP/RiskEngine.mqh"
#include "Include/ORBVWAP/StateTracker.mqh"
#include "Include/ORBVWAP/CircuitBreakers.mqh"
#include "Include/ORBVWAP/ExecutionEngine.mqh"
#include "Include/ORBVWAP/DecisionExport.mqh"
#include "Include/ORBVWAP/AiScorer.mqh"
#include "Include/ORBVWAP/AiSizer.mqh"
#include "Include/ORBVWAP/AiRegime.mqh"
#include "Include/ORBVWAP/PathTracker.mqh"
#include "Include/ORBVWAP/AiExit.mqh"

CIndicatorManager g_indicators;
COpeningRange     g_opening_range;
CSessionVwap      g_session_vwap;
CStateTracker     g_state;
CCircuitBreakers  g_breakers;
CExecutionEngine  g_executor;

SSessionContext g_session;
datetime        g_last_bar_time   = 0;
bool            g_test_order_sent = false;

//+------------------------------------------------------------------+
bool IsNewBar()
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(bar_time == 0)
      return(false);
   if(bar_time == g_last_bar_time)
      return(false);
   g_last_bar_time = bar_time;
   return(true);
  }

//+------------------------------------------------------------------+
void UpdateMarketContext()
  {
   const datetime signal_bar_time = iTime(_Symbol, PERIOD_CURRENT, 1);
   CSessionUtils::ResolveSession(signal_bar_time, g_session);
   g_opening_range.Update(g_session, _Symbol, PERIOD_CURRENT);
   g_session_vwap.Update(g_session, _Symbol, PERIOD_CURRENT);
   g_state.SyncSession(g_session.session_open_broker);
  }

//+------------------------------------------------------------------+
SSignalResult ResolveSignal()
  {
   if(InpTestExecution && !g_test_order_sent)
     {
      COrbVwapLogger::Warn("Test execution: forcing BUY on first new bar");
      SSignalResult test_signal;
      test_signal.Clear();
      test_signal.signal          = ORBVWAP_SIGNAL_BUY;
      test_signal.signal_bar      = 1;
      test_signal.reference_price = iClose(_Symbol, PERIOD_CURRENT, 1);
      return(test_signal);
     }

   return(CSignalEngine::Evaluate(_Symbol, g_session, g_opening_range, g_session_vwap,
                                  g_indicators, g_state));
  }

//+------------------------------------------------------------------+
void ProcessPipeline()
  {
   UpdateMarketContext();

   if(!g_indicators.IsReady())
     {
      COrbVwapLogger::Warn("Indicators not ready");
      return;
     }

   const SSignalResult signal_result = ResolveSignal();
   if(signal_result.signal == ORBVWAP_SIGNAL_NONE)
      return;

   if(InpAiRegimeMode != ORBVWAP_AI_REGIME_OFF)
     {
      const bool regime_ok = CAiRegime::AllowFromPipeline(_Symbol, g_session, g_opening_range,
                                                          g_session_vwap, g_indicators,
                                                          g_state.PriorSessionLoss());
      if(InpAiRegimeMode == ORBVWAP_AI_REGIME_SHADOW)
        {
         COrbVwapLogger::Info(StringFormat("AI3 shadow regime %s",
                                           regime_ok ? "ALLOW" : "SKIP_SESSION"));
        }
      else if(!regime_ok)
        {
         COrbVwapLogger::Journal("AI3_REGIME", "skip_session",
                                 OrbVwapSignalDirection(signal_result.signal));
         return;
        }
     }

   const int open_count = g_state.CountOpenPositions(_Symbol, InpMagicNumber);
   string reject_reason = "";

   const bool can_trade = CRiskEngine::CanTrade(_Symbol, signal_result.signal, open_count,
                                                g_state.LastEntryTime(), g_breakers, reject_reason);
   if(!can_trade)
      COrbVwapLogger::Info("Trade blocked: " + reject_reason);

   STradeSetup setup;
   const bool allow_test_fallback = (InpTestExecution && !g_test_order_sent);
   const bool setup_ok = can_trade && CRiskEngine::BuildSetup(_Symbol, signal_result, g_indicators,
                                                              g_opening_range, allow_test_fallback,
                                                              setup);
   if(can_trade && !setup_ok)
      COrbVwapLogger::Warn("Setup failed: " + setup.reject_reason);

   bool executed   = false;
   bool ai_blocked = false;
   double ai_score   = -1.0;
   ulong ticket    = 0;

   const bool ai_active = (InpAiGateMode != ORBVWAP_AI_OFF || InpAiSizeMode != ORBVWAP_AI_SIZE_OFF);
   if(setup_ok && ai_active)
     {
      ai_score = CAiScorer::Score(_Symbol, g_session, signal_result.signal,
                                  g_opening_range, g_session_vwap, g_indicators, setup);
      const double min_score = (InpAiMinScore > 0.0) ? InpAiMinScore : CAiScorer::MinScore();
      const bool   ai_pass   = (ai_score >= min_score);

      if(InpAiGateMode == ORBVWAP_AI_SHADOW)
        {
         COrbVwapLogger::Info(StringFormat("AI1 shadow %s score=%.3f tau=%.2f %s",
                                           ORBVWAP_AI1_MODEL_ID,
                                           ai_score,
                                           min_score,
                                           ai_pass ? "PASS" : "SKIP"));
        }
      else if(InpAiGateMode == ORBVWAP_AI_LIVE && !ai_pass)
        {
         ai_blocked = true;
         COrbVwapLogger::Journal("AI1_SCORE",
                                 StringFormat("score=%.3f tau=%.2f", ai_score, min_score),
                                 OrbVwapSignalDirection(signal_result.signal));
        }

      if(!ai_blocked && ai_pass && InpAiSizeMode != ORBVWAP_AI_SIZE_OFF)
        {
         const double size_mult = CAiSizer::Multiplier(ai_score);
         if(InpAiSizeMode == ORBVWAP_AI_SIZE_SHADOW)
           {
            COrbVwapLogger::Info(StringFormat("AI2 shadow mult=%.2f score=%.3f lot=%.2f",
                                              size_mult,
                                              ai_score,
                                              setup.lot));
           }
         else
           {
            setup.lot = CRiskEngine::ScaleLots(_Symbol, setup.lot, size_mult);
           }
        }
     }

   if(setup_ok && !ai_blocked)
     {
      if(g_executor.OpenMarket(_Symbol, setup))
        {
         executed = true;
         ticket   = g_executor.LastPositionId();
         g_state.RecordEntry();
         g_state.MarkBreakoutConsumed();
         g_opening_range.MarkTraded();
         if(InpTestExecution)
            g_test_order_sent = true;
        }
      else
        {
         COrbVwapLogger::Error("Execution failed: " + setup.reject_reason);
        }
     }

   CDecisionExport::LogPipeline(_Symbol, g_session, signal_result, g_opening_range,
                                  g_session_vwap, g_indicators, can_trade, reject_reason,
                                  setup, setup_ok, executed, ticket);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(Period() != PERIOD_M1)
      COrbVwapLogger::Warn("Attach to M1 chart for ORB strategy");

   if(!g_indicators.Init(_Symbol, PERIOD_CURRENT))
     {
      COrbVwapLogger::Error("Indicator init failed");
      return(INIT_FAILED);
     }

   g_executor.Configure(_Symbol, InpMagicNumber);
   g_breakers.Init();
   CDecisionExport::Reset();
   CPathTracker::Reset();
   g_last_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_session.Clear();

   COrbVwapLogger::Info(StringFormat("Initialised on %s %s magic=%d gmt_offset=%d",
                                     _Symbol,
                                     EnumToString(PERIOD_CURRENT),
                                     (int)InpMagicNumber,
                                     InpGmtOffsetHours));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_indicators.Release();
   COrbVwapLogger::Info("Deinitialised reason=" + IntegerToString(reason));
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   g_breakers.Update(_Symbol, InpMagicNumber);

   double atr = 0.0;
   if(g_indicators.IsReady())
      g_indicators.GetATR(1, atr);
   g_executor.ManageOpenPositions(_Symbol, InpMagicNumber, atr);

   if(!IsNewBar())
      return;

   ProcessPipeline();
  }

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   CDecisionExport::OnTradeTransaction(trans);

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   const ulong deal_ticket = trans.deal;
   if(deal_ticket == 0 || !HistoryDealSelect(deal_ticket))
      return;
   if((long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != InpMagicNumber)
      return;
   const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
      return;
   const double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT)
                         + HistoryDealGetDouble(deal_ticket, DEAL_SWAP)
                         + HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
   const int label_win = (profit > 0.0) ? 1 : 0;
   const datetime close_gmt = CSessionUtils::BarTimeToGmt((datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME));
   const ulong position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   CPathTracker::OnClose(position_id, profit, label_win, close_gmt);
   g_state.RecordSessionOutcome(profit);
  }
//+------------------------------------------------------------------+
