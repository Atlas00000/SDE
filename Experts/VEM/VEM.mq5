//+------------------------------------------------------------------+
//| VEM.mq5                                                          |
//| Phase 1 execution engine — see roadmap.md / concept.md         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <VEM/VEM_Config.mqh>
#include <VEM/VEM_Log.mqh>
#include <VEM/VEM_Indicators.mqh>
#include <VEM/VEM_State.mqh>
#include <VEM/VEM_Signal.mqh>
#include <VEM/VEM_Risk.mqh>
#include <VEM/VEM_Execution.mqh>
#include <VEM/VEM_TradeLog.mqh>
#include <VEM/VEM_AIShadow.mqh>

static datetime g_vem_last_bar_open = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   const string sym = _Symbol;
   const long trade_mode = SymbolInfoInteger(sym, SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
     {
      VEM_Log_Info("INIT_FAILED: symbol trading disabled");
      return INIT_FAILED;
     }

   if(!VEM_Indicators_Init(sym, Period()))
     {
      VEM_Log_Info("INIT_FAILED: indicator handles");
      return INIT_FAILED;
     }

   int need_bars = MathMax(inp_bb_period, inp_vol_ma_period);
   need_bars = MathMax(need_bars, inp_rsi_period);
   need_bars = MathMax(need_bars, inp_ema_period + inp_ema_slope_lookback_bars);
   if(inp_bb_walk_filter_enable)
      need_bars = MathMax(need_bars, inp_signal_shift + inp_bb_walk_min_closes + 5);
   if(inp_confirm_bar_enable)
      need_bars = MathMax(need_bars, inp_signal_shift + 3);
   need_bars += inp_signal_shift + 10;
   if(!VEM_Indicators_WaitReady(need_bars))
      VEM_Log_Info("Warning: indicator history still warming up");
   if(!VEM_Indicators_WaitHtfReady())
      VEM_Log_Info("Warning: HTF indicator history still warming up");

   VEM_State_OnInit();
   VEM_Execution_Init(sym);
   VEM_TradeLog_OnInit(sym, Period());
   VEM_AIShadow_OnInit(sym, Period());

   VEM_Log_Info("Init OK | magic=" + IntegerToString((long)inp_magic) +
                (inp_ai_shadow_enable || inp_ai_tail_shadow_enable ? " | AI shadow ON" : "") +
                (inp_ai_skip_enable ? " | AI skip ON" : "") +
                (inp_ai_tail_skip_enable ? " | AI tail-skip ON" : "") +
                (inp_ai_half_lot_enable ? " | AI half-lot ON" : "") +
                " | chart=" + sym + " " + EnumToString(Period()) +
                " | signal_shift=" + IntegerToString(inp_signal_shift));

   g_vem_last_bar_open = 0;
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   VEM_AIShadow_OnDeinit();
   VEM_TradeLog_OnDeinit();
   VEM_Indicators_Deinit();
   VEM_Log_Verbose("Deinit reason=" + (string)reason);
  }

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   VEM_TradeLog_OnTransaction(_Symbol, Period(), trans, request, result);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = Period();

   const datetime bar_open = iTime(sym, tf, 0);
   if(bar_open == g_vem_last_bar_open)
      return;
   g_vem_last_bar_open = bar_open;

   const int sh = inp_signal_shift;
   VEMIndicatorSnap bar_snap;
   if(!VEM_Indicators_Refresh(sym, tf, sh, bar_snap))
     {
      VEM_Log_Verbose("Skip bar: indicator refresh failed");
      return;
     }

   VEMIndicatorSnap entry_snap;
   if(inp_confirm_bar_enable)
     {
      if(!VEM_Indicators_Refresh(sym, tf, sh + 1, entry_snap))
        {
         VEM_Log_Verbose("Skip bar: D10 setup bar refresh failed");
         return;
        }
     }
   else
      entry_snap = bar_snap;

   bool want_long = false, want_short = false;
   VEM_Signal_Evaluate(sym, tf, sh, want_long, want_short);

   VEM_Execution_ProcessBar(sym, tf, sh, bar_snap, entry_snap, want_long, want_short);
  }

//+------------------------------------------------------------------+
