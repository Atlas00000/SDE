//+------------------------------------------------------------------+
//|                                                      ORBVWAP.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.17"

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

   const int open_count = g_state.CountOpenPositions(_Symbol, InpMagicNumber);
   string reject_reason = "";

   if(!CRiskEngine::CanTrade(_Symbol, signal_result.signal, open_count,
                             g_state.LastEntryTime(), g_breakers, reject_reason))
     {
      COrbVwapLogger::Info("Trade blocked: " + reject_reason);
      return;
     }

   STradeSetup setup;
   const bool allow_test_fallback = (InpTestExecution && !g_test_order_sent);
   if(!CRiskEngine::BuildSetup(_Symbol, signal_result, g_indicators, g_opening_range,
                               allow_test_fallback, setup))
     {
      COrbVwapLogger::Warn("Setup failed: " + setup.reject_reason);
      return;
     }

   if(g_executor.OpenMarket(_Symbol, setup))
     {
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
