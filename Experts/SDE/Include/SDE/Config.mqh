#ifndef __SDE_CONFIG_MQH__
#define __SDE_CONFIG_MQH__

enum SdeTradePermission
  {
   TRADE_DISABLED = 0,
   TRADE_BUY_ONLY = 1,
   TRADE_SELL_ONLY = 2,
   TRADE_BOTH = 3
  };

enum SdeLotMode
  {
   LOT_FIXED = 0,
   LOT_RISK_PERCENT = 1
  };

enum SdeLogLevel
  {
   LOG_ERROR = 0,
   LOG_WARN = 1,
   LOG_INFO = 2,
   LOG_DEBUG = 3
  };

struct SdeConfig
  {
   int               bb_period;
   double            bb_deviation;
   int               kc_period;
   double            kc_multiplier;
   int               adx_period;
   double            adx_threshold;
   int               adx_rising_bars;
   int               setup_expiration_bars;
   int               min_squeeze_bars;

   SdeLotMode        lot_mode;
   double            fixed_lot;
   double            risk_percent;
   int               stop_loss_points;
   int               take_profit_points;

   int               max_spread_points;
   int               max_slippage_points;
   int               cooldown_bars;
   int               max_open_positions;
   long              magic_number;
   double            min_equity;
   SdeTradePermission trade_permission;
   SdeLogLevel       log_level;
  };

#endif
