//+------------------------------------------------------------------+
//| RiskEngine.mqh                                                   |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_RISKENGINE_MQH__
#define __ORBVWAP_RISKENGINE_MQH__

#include "Inputs.mqh"
#include "Types.mqh"
#include "Constants.mqh"
#include "IndicatorManager.mqh"
#include "OpeningRange.mqh"
#include "CircuitBreakers.mqh"
#include "Logger.mqh"

class CRiskEngine
  {
   static double NormalizePrice(const string symbol, const double price)
     {
      const double tick = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tick <= 0.0)
         return(price);
      return(MathRound(price / tick) * tick);
     }

   static int CurrentSpreadPoints(const string symbol)
     {
      const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return(0);
      return((int)MathRound((ask - bid) / point));
     }

   static double NormalizeVolume(const string symbol, double lots)
     {
      const double vmin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      const double vmax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      const double vstep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(vstep <= 0.0)
         return(vmin);

      lots = MathMax(vmin, MathMin(vmax, lots));
      const int steps = (int)MathFloor((lots + 1e-12) / vstep);
      lots = (double)steps * vstep;
      if(lots < vmin)
         lots = vmin;
      if(lots > vmax)
         lots = vmax;
      return(lots);
     }

public:
   static double ScaleLots(const string symbol, const double lots, const double multiplier)
     {
      if(multiplier <= 0.0)
         return(NormalizeVolume(symbol, lots));
      return(NormalizeVolume(symbol, lots * multiplier));
     }

private:

   static double CalculateLots(const string               symbol,
                                 const ENUM_ORBVWAP_SIGNAL  signal,
                                 const double               entry_price,
                                 const double               sl_price,
                                 string                    &reject_reason)
     {
      reject_reason = "";

      if(InpSizingMode == ORBVWAP_SIZING_FIXED_LOT)
         return(NormalizeVolume(symbol, InpFixedLot));

      const double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
      const double risk_money = equity * InpRiskPercent / 100.0;
      if(risk_money <= 0.0)
        {
         reject_reason = ORBVWAP_REJECT_LOT_INVALID;
         return(NormalizeVolume(symbol, InpFixedLot));
        }

      const ENUM_ORDER_TYPE order_type = (signal == ORBVWAP_SIGNAL_BUY) ?
                                         ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      double profit = 0.0;
      if(!OrderCalcProfit(order_type, symbol, 1.0, entry_price, sl_price, profit))
        {
         reject_reason = ORBVWAP_REJECT_LOT_INVALID;
         return(NormalizeVolume(symbol, InpFixedLot));
        }

      const double loss_per_lot = MathAbs(profit);
      if(loss_per_lot < 1e-8)
        {
         reject_reason = ORBVWAP_REJECT_LOT_INVALID;
         return(NormalizeVolume(symbol, InpFixedLot));
        }

      return(NormalizeVolume(symbol, risk_money / loss_per_lot));
     }

   static bool BuildStrategyNative(const string               symbol,
                                   const ENUM_ORBVWAP_SIGNAL    signal,
                                   const int                    signal_bar,
                                   COpeningRange               &opening_range,
                                   STradeSetup                 &setup)
     {
      if(!opening_range.IsLocked() && !opening_range.IsTraded())
        {
         setup.reject_reason = ORBVWAP_REJECT_RANGE_FORMING;
         return(false);
        }

      const double range_width = opening_range.Width();
      if(range_width <= 0.0)
        {
         setup.reject_reason = ORBVWAP_REJECT_RANGE_TOO_NARROW;
         return(false);
        }

      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      const double tp_mult = (InpTpRangeMult > 0.0) ? InpTpRangeMult : 1.0;
      const bool use_runner_tp = (InpPartialClosePct > 0.0 && InpRunnerTpRangeMult > 0.0);
      const bool use_no_entry_tp = (InpPartialClosePct > 0.0 && InpRunnerTpRangeMult <= 0.0);
      const double order_tp_mult = use_runner_tp ? InpRunnerTpRangeMult : tp_mult;
      const double tp_distance = range_width * order_tp_mult;
      const double range_mid = NormalizePrice(symbol,
                                              (opening_range.High() + opening_range.Low()) * 0.5);

      if(signal == ORBVWAP_SIGNAL_BUY)
        {
         setup.entry_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
         setup.sl          = (InpSlMode == ORBVWAP_SL_MID_RANGE) ?
                             range_mid : NormalizePrice(symbol, opening_range.Low());
         setup.tp          = use_no_entry_tp ? 0.0 :
                             NormalizePrice(symbol, setup.entry_price + tp_distance);
        }
      else
        {
         setup.entry_price = SymbolInfoDouble(symbol, SYMBOL_BID);
         setup.sl          = (InpSlMode == ORBVWAP_SL_MID_RANGE) ?
                             range_mid : NormalizePrice(symbol, opening_range.High());
         setup.tp          = use_no_entry_tp ? 0.0 :
                             NormalizePrice(symbol, setup.entry_price - tp_distance);
        }

      setup.sl          = NormalizeDouble(setup.sl, digits);
      setup.tp          = NormalizeDouble(setup.tp, digits);
      setup.entry_price = NormalizeDouble(setup.entry_price, digits);
      setup.range_width = range_width;
      setup.signal_bar  = signal_bar;
      return(true);
     }

   static bool BuildFallbackSltp(const string               symbol,
                                 const ENUM_ORBVWAP_SIGNAL  signal,
                                 CIndicatorManager         &indicators,
                                 STradeSetup               &setup)
     {
      double atr = 0.0;
      if(!indicators.GetATR(1, atr) || atr <= 0.0)
        {
         setup.reject_reason = "atr_unavailable";
         return(false);
        }

      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      double sl_distance = 0.0;
      double tp_distance = 0.0;

      if(InpSltpMode == ORBVWAP_SLTP_ATR_BASED)
        {
         sl_distance = atr * InpSlAtrMult;
         tp_distance = atr * InpTpAtrMult;
        }
      else
        {
         sl_distance = InpStopLossPoints * point;
         tp_distance = InpTakeProfitPoints * point;
        }

      if(sl_distance <= 0.0 || tp_distance <= 0.0)
        {
         setup.reject_reason = ORBVWAP_REJECT_STOPS_INVALID;
         return(false);
        }

      if(signal == ORBVWAP_SIGNAL_BUY)
         setup.entry_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      else
         setup.entry_price = SymbolInfoDouble(symbol, SYMBOL_BID);

      if(signal == ORBVWAP_SIGNAL_BUY)
        {
         setup.sl = NormalizePrice(symbol, setup.entry_price - sl_distance);
         setup.tp = NormalizePrice(symbol, setup.entry_price + tp_distance);
        }
      else
        {
         setup.sl = NormalizePrice(symbol, setup.entry_price + sl_distance);
         setup.tp = NormalizePrice(symbol, setup.entry_price - tp_distance);
        }

      setup.sl          = NormalizeDouble(setup.sl, digits);
      setup.tp          = NormalizeDouble(setup.tp, digits);
      setup.entry_price = NormalizeDouble(setup.entry_price, digits);
      setup.signal_bar  = 1;
      return(true);
     }

   static bool ValidateTpDistance(const string symbol, STradeSetup &setup)
     {
      if(setup.tp <= 0.0)
         return(true);

      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return(true);

      const int spread = CurrentSpreadPoints(symbol);
      const int stops_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      const double min_tp_dist = (spread + stops_level) * point;
      const double tp_dist = MathAbs(setup.entry_price - setup.tp);

      if(tp_dist < min_tp_dist)
        {
         setup.reject_reason = StringFormat("tp_too_close dist=%.5f min=%.5f",
                                            tp_dist, min_tp_dist);
         COrbVwapLogger::Warn(setup.reject_reason);
         return(false);
        }
      return(true);
     }

   static double CalcRiskReward(const STradeSetup &setup)
     {
      const double risk = MathAbs(setup.entry_price - setup.sl);
      if(risk < 1e-8)
         return(0.0);

      double reward = 0.0;
      if(InpPartialClosePct > 0.0 && InpPartialAtRangeMult > 0.0 && setup.range_width > 0.0)
         reward = setup.range_width * InpPartialAtRangeMult;
      else
         reward = MathAbs(setup.tp - setup.entry_price);

      return(reward / risk);
     }

public:
   static bool CanTrade(const string               symbol,
                        const ENUM_ORBVWAP_SIGNAL  signal,
                        const int                  open_count,
                        const datetime             last_entry_time,
                        const CCircuitBreakers    &breakers,
                        string                    &reject_reason)
     {
      reject_reason = "";

      if(!InpEnableTrading)
        {
         reject_reason = "trading_disabled";
         return(false);
        }

      if(signal == ORBVWAP_SIGNAL_NONE)
        {
         reject_reason = "no_signal";
         return(false);
        }

      string breaker_code = "";
      string breaker_detail = "";
      if(!breakers.AllowEntry(breaker_code, breaker_detail))
        {
         reject_reason = breaker_code;
         if(breaker_detail != "")
            reject_reason += " " + breaker_detail;
         COrbVwapLogger::Journal(breaker_code, breaker_detail);
         return(false);
        }

      if(InpMinEquityRatio > 0.0)
        {
         const double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
         const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         if(equity < balance * InpMinEquityRatio)
           {
            reject_reason = ORBVWAP_REJECT_EQUITY_FLOOR;
            COrbVwapLogger::Journal(ORBVWAP_REJECT_EQUITY_FLOOR);
            return(false);
           }
        }

      const int spread = CurrentSpreadPoints(symbol);
      if(spread > InpMaxSpreadPoints)
        {
         reject_reason = ORBVWAP_REJECT_SPREAD_TOO_HIGH + " spread=" + IntegerToString(spread);
         COrbVwapLogger::Journal(ORBVWAP_REJECT_SPREAD_TOO_HIGH,
                                 "spread=" + IntegerToString(spread),
                                 OrbVwapSignalDirection(signal));
         return(false);
        }

      if(open_count >= InpMaxOpenTrades)
        {
         reject_reason = ORBVWAP_REJECT_MAX_TRADES;
         COrbVwapLogger::Journal(ORBVWAP_REJECT_MAX_TRADES);
         return(false);
        }

      if(InpCooldownSeconds > 0 && last_entry_time > 0)
        {
         if((TimeCurrent() - last_entry_time) < InpCooldownSeconds)
           {
            reject_reason = ORBVWAP_REJECT_COOLDOWN;
            COrbVwapLogger::Journal(ORBVWAP_REJECT_COOLDOWN);
            return(false);
           }
        }

      if(signal == ORBVWAP_SIGNAL_BUY && InpTradePermission == ORBVWAP_TRADE_SELL_ONLY)
        {
         reject_reason = ORBVWAP_REJECT_PERMISSION;
         COrbVwapLogger::Journal(ORBVWAP_REJECT_PERMISSION, "buy_blocked");
         return(false);
        }

      if(signal == ORBVWAP_SIGNAL_SELL && InpTradePermission == ORBVWAP_TRADE_BUY_ONLY)
        {
         reject_reason = ORBVWAP_REJECT_PERMISSION;
         COrbVwapLogger::Journal(ORBVWAP_REJECT_PERMISSION, "sell_blocked");
         return(false);
        }

      return(true);
     }

   static bool BuildSetup(const string            symbol,
                          const SSignalResult    &signal_result,
                          CIndicatorManager      &indicators,
                          COpeningRange          &opening_range,
                          const bool              allow_test_fallback,
                          STradeSetup            &setup)
     {
      setup.Clear();
      setup.signal = signal_result.signal;

      if(signal_result.signal == ORBVWAP_SIGNAL_NONE)
        {
         setup.reject_reason = "no_signal";
         return(false);
        }

      bool built = false;
      if(InpSltpMode == ORBVWAP_SLTP_STRATEGY_NATIVE)
        {
         built = BuildStrategyNative(symbol, signal_result.signal, signal_result.signal_bar,
                                     opening_range, setup);
         if(!built && allow_test_fallback)
            built = BuildFallbackSltp(symbol, signal_result.signal, indicators, setup);
        }
      else
         built = BuildFallbackSltp(symbol, signal_result.signal, indicators, setup);

      if(!built)
         return(false);

      if(signal_result.signal == ORBVWAP_SIGNAL_BUY)
        {
         if(setup.sl >= setup.entry_price)
           {
            setup.reject_reason = ORBVWAP_REJECT_STOPS_INVALID;
            return(false);
           }
         if(setup.tp > 0.0 && setup.tp <= setup.entry_price)
           {
            setup.reject_reason = ORBVWAP_REJECT_STOPS_INVALID;
            return(false);
           }
        }
      else
        {
         if(setup.sl <= setup.entry_price)
           {
            setup.reject_reason = ORBVWAP_REJECT_STOPS_INVALID;
            return(false);
           }
         if(setup.tp > 0.0 && setup.tp >= setup.entry_price)
           {
            setup.reject_reason = ORBVWAP_REJECT_STOPS_INVALID;
            return(false);
           }
        }

      if(!ValidateTpDistance(symbol, setup))
         return(false);

      setup.lot = CalculateLots(symbol, signal_result.signal, setup.entry_price, setup.sl, setup.reject_reason);
      if(setup.lot <= 0.0)
        {
         if(setup.reject_reason == "")
            setup.reject_reason = ORBVWAP_REJECT_LOT_INVALID;
         COrbVwapLogger::Journal(ORBVWAP_REJECT_LOT_INVALID,
                                 setup.reject_reason,
                                 OrbVwapSignalDirection(signal_result.signal));
         return(false);
        }

      setup.risk_reward = CalcRiskReward(setup);
      if(InpMinRR > 0.0 && setup.risk_reward < InpMinRR)
        {
         setup.reject_reason = StringFormat("%s rr=%.2f min=%.2f",
                                            ORBVWAP_REJECT_MIN_RR,
                                            setup.risk_reward,
                                            InpMinRR);
         COrbVwapLogger::Journal(ORBVWAP_REJECT_MIN_RR,
                                 StringFormat("rr=%.2f min=%.2f", setup.risk_reward, InpMinRR),
                                 OrbVwapSignalDirection(signal_result.signal));
         return(false);
        }

      COrbVwapLogger::Info(StringFormat("Setup %s lot=%.2f entry=%.5f sl=%.5f tp=%.5f rr=%.2f",
                                        (signal_result.signal == ORBVWAP_SIGNAL_BUY ? "BUY" : "SELL"),
                                        setup.lot, setup.entry_price, setup.sl, setup.tp, setup.risk_reward));
      return(true);
     }

   static double NormalizeVolumePublic(const string symbol, const double lots)
     {
      return(NormalizeVolume(symbol, lots));
     }
  };

#endif // __ORBVWAP_RISKENGINE_MQH__
