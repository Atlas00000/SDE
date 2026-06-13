//+------------------------------------------------------------------+
//| Types.mqh                                                        |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_TYPES_MQH__
#define __ORBVWAP_TYPES_MQH__

enum ENUM_ORBVWAP_SIGNAL
  {
   ORBVWAP_SIGNAL_NONE = 0,
   ORBVWAP_SIGNAL_BUY,
   ORBVWAP_SIGNAL_SELL
  };

inline string OrbVwapSignalDirection(const ENUM_ORBVWAP_SIGNAL signal)
  {
   if(signal == ORBVWAP_SIGNAL_BUY)
      return("BUY");
   if(signal == ORBVWAP_SIGNAL_SELL)
      return("SELL");
   return("");
  }

enum ENUM_ORBVWAP_SIZING_MODE
  {
   ORBVWAP_SIZING_FIXED_LOT = 0,
   ORBVWAP_SIZING_PERCENT_RISK
  };

enum ENUM_ORBVWAP_SLTP_MODE
  {
   ORBVWAP_SLTP_STRATEGY_NATIVE = 0,
   ORBVWAP_SLTP_FIXED_POINTS,
   ORBVWAP_SLTP_ATR_BASED
  };

enum ENUM_ORBVWAP_SL_MODE
  {
   ORBVWAP_SL_OPPOSITE = 0,   // long SL at range low, short SL at range high
   ORBVWAP_SL_MID_RANGE       // P2-001: SL at range midpoint
  };

enum ENUM_ORBVWAP_TRADE_PERMISSION
  {
   ORBVWAP_TRADE_BOTH = 0,
   ORBVWAP_TRADE_BUY_ONLY,
   ORBVWAP_TRADE_SELL_ONLY
  };

enum ENUM_ORBVWAP_SESSION
  {
   ORBVWAP_SESSION_NONE = 0,
   ORBVWAP_SESSION_LONDON,
   ORBVWAP_SESSION_NY
  };

enum ENUM_ORBVWAP_ACTIVE_SESSION
  {
   ORBVWAP_ACTIVE_LONDON = 0,
   ORBVWAP_ACTIVE_NY,
   ORBVWAP_ACTIVE_BOTH
  };

enum ENUM_ORBVWAP_AI_GATE_MODE
  {
   ORBVWAP_AI_OFF = 0,
   ORBVWAP_AI_SHADOW,
   ORBVWAP_AI_LIVE
  };

enum ENUM_ORBVWAP_AI_SIZE_MODE
  {
   ORBVWAP_AI_SIZE_OFF = 0,
   ORBVWAP_AI_SIZE_SHADOW,
   ORBVWAP_AI_SIZE_LIVE
  };

enum ENUM_ORBVWAP_AI_REGIME_MODE
  {
   ORBVWAP_AI_REGIME_OFF = 0,
   ORBVWAP_AI_REGIME_SHADOW,
   ORBVWAP_AI_REGIME_LIVE
  };

enum ENUM_ORBVWAP_AI_EXIT_MODE
  {
   ORBVWAP_AI_EXIT_OFF = 0,
   ORBVWAP_AI_EXIT_SHADOW,
   ORBVWAP_AI_EXIT_LIVE
  };

enum ENUM_ORBVWAP_RANGE_STATE
  {
   ORBVWAP_RANGE_IDLE = 0,
   ORBVWAP_RANGE_FORMING,
   ORBVWAP_RANGE_LOCKED,
   ORBVWAP_RANGE_TRADED,
   ORBVWAP_RANGE_EXPIRED
  };

struct SSessionContext
  {
   bool                  active;
   ENUM_ORBVWAP_SESSION  session;
   datetime              session_open_gmt;
   datetime              session_open_broker;
   datetime              session_end_gmt;

   void Clear()
     {
      active               = false;
      session              = ORBVWAP_SESSION_NONE;
      session_open_gmt     = 0;
      session_open_broker  = 0;
      session_end_gmt      = 0;
     }
  };

struct SOpeningRangeState
  {
   ENUM_ORBVWAP_RANGE_STATE state;
   double                   high;
   double                   low;
   double                   width;
   datetime                 lock_time;
   datetime                 session_open_broker;
   int                      bars_collected;

   void Clear()
     {
      state                = ORBVWAP_RANGE_IDLE;
      high                 = 0.0;
      low                  = 0.0;
      width                = 0.0;
      lock_time            = 0;
      session_open_broker  = 0;
      bars_collected       = 0;
     }
  };

struct SSignalResult
  {
   ENUM_ORBVWAP_SIGNAL signal;
   int                 signal_bar;
   double              reference_price;
   string              reject_reason;

   void Clear()
     {
      signal           = ORBVWAP_SIGNAL_NONE;
      signal_bar       = 0;
      reference_price  = 0.0;
      reject_reason    = "";
     }
  };

struct STradeSetup
  {
   ENUM_ORBVWAP_SIGNAL signal;
   double              lot;
   double              sl;
   double              tp;
   double              entry_price;
   double              range_width;
   int                 signal_bar;
   double              risk_reward;
   string              reject_reason;

   void Clear()
     {
      signal        = ORBVWAP_SIGNAL_NONE;
      lot           = 0.0;
      sl            = 0.0;
      tp            = 0.0;
      entry_price   = 0.0;
      range_width   = 0.0;
      signal_bar    = 0;
      risk_reward   = 0.0;
      reject_reason = "";
     }
  };

#endif // __ORBVWAP_TYPES_MQH__
