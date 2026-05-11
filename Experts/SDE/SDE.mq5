//+------------------------------------------------------------------+
//|                                                          SDE.mq5 |
//+------------------------------------------------------------------+
#property strict

#include "Include/SDE/Config.mqh"
#include "Include/SDE/State.mqh"
#include "Include/SDE/Logger.mqh"
#include "Include/SDE/Indicators.mqh"
#include "Include/SDE/SignalEngine.mqh"
#include "Include/SDE/RiskEngine.mqh"
#include "Include/SDE/ExecutionEngine.mqh"

input group "Signal"
input int      InpBBPeriod = 14;
input double   InpBBDeviation = 1.8;
input int      InpKCPeriod = 14;
input double   InpKCMultiplier = 1.2;
input int      InpADXPeriod = 10;
input double   InpADXThreshold = 16.0;
input int      InpADXRisingBars = 0;
input int      InpSetupExpirationBars = 10;
input int      InpMinSqueezeBars = 1;

input group "Risk"
input SdeLotMode InpLotMode = LOT_FIXED;
input double   InpFixedLot = 0.01;
input double   InpRiskPercent = 1.0;
input int      InpStopLossPoints = 300;
input int      InpTakeProfitPoints = 600;
input double   InpMinEquity = 0.0;
input int      InpMaxOpenPositions = 1;
input int      InpCooldownBars = 0;

input group "Execution"
input int      InpMaxSpreadPoints = 30;
input int      InpMaxSlippagePoints = 20;
input long     InpMagicNumber = 26051101;
input SdeTradePermission InpTradePermission = TRADE_BOTH;

input group "Debug"
input SdeLogLevel InpLogLevel = LOG_INFO;

SdeConfig          g_cfg;
SdeRuntimeState    g_state;
SdeLogger          g_log;
SdeIndicators      g_indicators;
SdeSignalEngine    g_signal;
SdeRiskEngine      g_risk;
SdeExecutionEngine g_exec;
datetime           g_last_bar_time = 0;

void LoadConfig()
  {
   g_cfg.bb_period = InpBBPeriod;
   g_cfg.bb_deviation = InpBBDeviation;
   g_cfg.kc_period = InpKCPeriod;
   g_cfg.kc_multiplier = InpKCMultiplier;
   g_cfg.adx_period = InpADXPeriod;
   g_cfg.adx_threshold = InpADXThreshold;
   g_cfg.adx_rising_bars = InpADXRisingBars;
   g_cfg.setup_expiration_bars = InpSetupExpirationBars;
   g_cfg.min_squeeze_bars = InpMinSqueezeBars;
   g_cfg.lot_mode = InpLotMode;
   g_cfg.fixed_lot = InpFixedLot;
   g_cfg.risk_percent = InpRiskPercent;
   g_cfg.stop_loss_points = InpStopLossPoints;
   g_cfg.take_profit_points = InpTakeProfitPoints;
   g_cfg.max_spread_points = InpMaxSpreadPoints;
   g_cfg.max_slippage_points = InpMaxSlippagePoints;
   g_cfg.cooldown_bars = InpCooldownBars;
   g_cfg.max_open_positions = InpMaxOpenPositions;
   g_cfg.magic_number = InpMagicNumber;
   g_cfg.min_equity = InpMinEquity;
   g_cfg.trade_permission = InpTradePermission;
   g_cfg.log_level = InpLogLevel;
  }

bool IsNewBar()
  {
   datetime t=iTime(_Symbol,_Period,0);
   if(t==0)
      return false;
   if(g_last_bar_time==0)
     {
      g_last_bar_time=t;
      return false;
     }
   if(t==g_last_bar_time)
      return false;
   g_last_bar_time=t;
   return true;
  }

void SyncPositionState()
  {
   bool has_pos=(g_risk.CountOpenPositionsByMagic(g_cfg.magic_number)>0);
   if(has_pos)
      g_state.state=STATE_IN_TRADE;
   if(g_state.had_position_on_prev_bar && !has_pos)
     {
      g_state.state=STATE_COOLDOWN;
      g_state.cooldown_remaining=g_cfg.cooldown_bars;
      g_state.last_trade_time=TimeCurrent();
      g_state.ResetSetup();
     }
   g_state.had_position_on_prev_bar=has_pos;
  }

int OnInit()
  {
   LoadConfig();
   g_log.SetLevel(g_cfg.log_level);
   g_state.Init();
   g_signal.Init(g_cfg);
   g_risk.Init(_Symbol,g_cfg);
   g_exec.Init(_Symbol,g_cfg);

   if(!g_indicators.Init(_Symbol,_Period,g_cfg))
     {
      g_log.Log(LOG_ERROR,"Indicator init failed");
      return(INIT_FAILED);
     }
   SyncPositionState();
   g_log.Log(LOG_INFO,"SDE initialized");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   g_indicators.Release();
  }

void OnTick()
  {
   if(!IsNewBar())
      return;

   SyncPositionState();
   if(g_state.state==STATE_COOLDOWN)
     {
      g_state.cooldown_remaining--;
      if(g_state.cooldown_remaining<=0)
         g_state.state=STATE_FLAT;
      return;
     }

   if(!g_indicators.Ready())
      return;

   SdeIndicatorSnapshot curr,prev;
   if(!g_indicators.ReadSnapshot(1,curr))
      return;
   if(!g_indicators.ReadSnapshot(2,prev))
      return;

   SdeSignalResult sr=g_signal.Evaluate(curr,prev,g_state);
   if(sr.reason!="")
      g_log.Log(LOG_DEBUG,sr.reason);

   if(!sr.should_enter || sr.direction==DIR_NONE)
      return;

   if(!g_risk.AllowDirection(sr.direction)) return;
   if(!g_risk.EquityOk()) return;
   if(!g_risk.SpreadOk()) return;
   if(g_risk.CountOpenPositionsByMagic(g_cfg.magic_number)>=g_cfg.max_open_positions) return;

   double volume=g_risk.CalculateVolume();
   string err="";
   if(!g_exec.ExecuteMarket(sr.direction,volume,err))
     {
      g_log.Log(LOG_WARN,"Execution blocked/failed: "+err);
      g_state.state=STATE_FLAT;
      g_state.ResetSetup();
      return;
     }

   g_state.last_trade_time=TimeCurrent();
   g_log.Log(LOG_INFO,"Trade executed");
  }

