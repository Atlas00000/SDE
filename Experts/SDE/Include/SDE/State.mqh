#ifndef __SDE_STATE_MQH__
#define __SDE_STATE_MQH__

enum SdeState
  {
   STATE_FLAT = 0,
   STATE_SQUEEZE_ON = 1,
   STATE_SQUEEZE_FIRED = 2,
   STATE_ADX_CONFIRM = 3,
   STATE_IN_TRADE = 4,
   STATE_COOLDOWN = 5
  };

enum SdeDirection
  {
   DIR_NONE = 0,
   DIR_BUY = 1,
   DIR_SELL = -1
  };

struct SdeRuntimeState
  {
   SdeState     state;
   SdeDirection direction;
   int          squeeze_bars;
   int          setup_bars_since_fire;
   datetime     setup_time;
   datetime     last_trade_time;
   int          cooldown_remaining;
   bool         had_position_on_prev_bar;

   void ResetSetup()
     {
      direction=DIR_NONE;
      squeeze_bars=0;
      setup_bars_since_fire=0;
      setup_time=0;
     }

   void Init()
     {
      state=STATE_FLAT;
      ResetSetup();
      last_trade_time=0;
      cooldown_remaining=0;
      had_position_on_prev_bar=false;
     }
  };

#endif
