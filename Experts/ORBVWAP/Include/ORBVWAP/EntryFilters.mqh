//+------------------------------------------------------------------+
//| EntryFilters.mqh — P2C regime & structure gates                  |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_ENTRYFILTERS_MQH__
#define __ORBVWAP_ENTRYFILTERS_MQH__

#include "Inputs.mqh"
#include "Constants.mqh"
#include "IndicatorManager.mqh"
#include "Logger.mqh"

class CEntryFilters
  {
   static bool IsPivotHigh(const string symbol, const ENUM_TIMEFRAMES tf,
                           const int shift, const int pivot_bars)
     {
      const double high = iHigh(symbol, tf, shift);
      if(high <= 0.0)
         return(false);

      for(int j = 1; j <= pivot_bars; j++)
        {
         if(iHigh(symbol, tf, shift - j) >= high)
            return(false);
         if(iHigh(symbol, tf, shift + j) >= high)
            return(false);
        }
      return(true);
     }

   static bool IsPivotLow(const string symbol, const ENUM_TIMEFRAMES tf,
                          const int shift, const int pivot_bars)
     {
      const double low = iLow(symbol, tf, shift);
      if(low <= 0.0)
         return(false);

      for(int j = 1; j <= pivot_bars; j++)
        {
         if(iLow(symbol, tf, shift - j) <= low)
            return(false);
         if(iLow(symbol, tf, shift + j) <= low)
            return(false);
        }
      return(true);
     }

   static bool H4StructureAllows(const string symbol, const ENUM_ORBVWAP_SIGNAL signal,
                                 string &reject_code, string &detail)
     {
      reject_code = "";
      detail      = "";
      if(InpH4SwingPivotBars <= 0)
         return(true);

      const int scan_bars = 50;
      int last_high_shift = -1;
      int last_low_shift  = -1;

      for(int shift = 1 + InpH4SwingPivotBars; shift < scan_bars; shift++)
        {
         if(last_high_shift < 0 && IsPivotHigh(symbol, PERIOD_H4, shift, InpH4SwingPivotBars))
            last_high_shift = shift;
         if(last_low_shift < 0 && IsPivotLow(symbol, PERIOD_H4, shift, InpH4SwingPivotBars))
            last_low_shift = shift;
         if(last_high_shift >= 0 && last_low_shift >= 0)
            break;
        }

      if(last_high_shift < 0 || last_low_shift < 0)
        {
         reject_code = ORBVWAP_REJECT_H4_STRUCTURE;
         detail      = "swings_not_found";
         return(false);
        }

      const bool bullish = (last_low_shift > last_high_shift);
      const bool bearish = (last_high_shift > last_low_shift);

      if(signal == ORBVWAP_SIGNAL_BUY && !bullish)
        {
         reject_code = ORBVWAP_REJECT_H4_STRUCTURE;
         detail      = StringFormat("need_bullish high_shift=%d low_shift=%d",
                                    last_high_shift, last_low_shift);
         return(false);
        }

      if(signal == ORBVWAP_SIGNAL_SELL && !bearish)
        {
         reject_code = ORBVWAP_REJECT_H4_STRUCTURE;
         detail      = StringFormat("need_bearish high_shift=%d low_shift=%d",
                                    last_high_shift, last_low_shift);
         return(false);
        }

      return(true);
     }

   static bool CheckCommon(const string               symbol,
                           CIndicatorManager         &indicators,
                           const double               range_width,
                           const double               close_1,
                           const double               vwap,
                           const double               atr,
                           const long                 tick_vol,
                           const double               vol_ma,
                           string                    &reject_code,
                           string                    &detail)
     {
      reject_code = "";
      detail      = "";

      if(InpAdxMax > 0.0)
        {
         double adx = 0.0;
         if(!indicators.GetM15Adx(1, adx))
           {
            reject_code = ORBVWAP_REJECT_ADX_FILTER;
            detail      = "adx_unavailable";
            return(false);
           }
         if(adx >= InpAdxMax)
           {
            reject_code = ORBVWAP_REJECT_ADX_FILTER;
            detail      = StringFormat("adx=%.1f max=%.1f", adx, InpAdxMax);
            return(false);
           }
        }

      if(InpAtrExpMax > 0.0)
        {
         double atr_slow = 0.0;
         if(!indicators.GetATRSlow(1, atr_slow) || atr_slow <= 0.0)
           {
            reject_code = ORBVWAP_REJECT_ATR_EXPANSION;
            detail      = "atr_slow_unavailable";
            return(false);
           }
         const double ratio = atr / atr_slow;
         if(ratio > InpAtrExpMax)
           {
            reject_code = ORBVWAP_REJECT_ATR_EXPANSION;
            detail      = StringFormat("ratio=%.2f max=%.2f", ratio, InpAtrExpMax);
            return(false);
           }
        }

      if(InpMaxSpreadPctRange > 0.0 && range_width > 0.0)
        {
         const double ask   = SymbolInfoDouble(symbol, SYMBOL_ASK);
         const double bid   = SymbolInfoDouble(symbol, SYMBOL_BID);
         const double spread = ask - bid;
         const double max_spread = range_width * InpMaxSpreadPctRange / 100.0;
         if(spread > max_spread)
           {
            reject_code = ORBVWAP_REJECT_SPREAD_RANGE;
            detail      = StringFormat("spread=%.5f max=%.5f", spread, max_spread);
            return(false);
           }
        }

      if(InpVolMaxMult > 0.0 && vol_ma > 0.0)
        {
         if((double)tick_vol > vol_ma * InpVolMaxMult)
           {
            reject_code = ORBVWAP_REJECT_VOL_SPIKE;
            detail      = StringFormat("vol=%d cap=%.1f", tick_vol, vol_ma * InpVolMaxMult);
            return(false);
           }
        }

      if(InpMaxVwapDistAtr > 0.0 && atr > 0.0)
        {
         const double dist = MathAbs(close_1 - vwap);
         const double max_dist = atr * InpMaxVwapDistAtr;
         if(dist > max_dist)
           {
            reject_code = ORBVWAP_REJECT_VWAP_DISTANCE;
            detail      = StringFormat("dist=%.5f max=%.5f", dist, max_dist);
            return(false);
           }
        }

      return(true);
     }

   static bool CheckD1Bias(const string symbol, CIndicatorManager &indicators,
                           const ENUM_ORBVWAP_SIGNAL signal,
                           string &reject_code, string &detail)
     {
      reject_code = "";
      detail      = "";
      if(InpD1EmaPeriod <= 0)
         return(true);

      double ema = 0.0;
      double close_d1 = iClose(symbol, PERIOD_D1, 1);
      if(close_d1 <= 0.0 || !indicators.GetD1Ema(1, ema))
        {
         reject_code = ORBVWAP_REJECT_D1_BIAS;
         detail      = "d1_unavailable";
         return(false);
        }

      if(signal == ORBVWAP_SIGNAL_BUY && close_d1 <= ema)
        {
         reject_code = ORBVWAP_REJECT_D1_BIAS;
         detail      = StringFormat("close=%.5f ema=%.5f", close_d1, ema);
         return(false);
        }

      if(signal == ORBVWAP_SIGNAL_SELL && close_d1 >= ema)
        {
         reject_code = ORBVWAP_REJECT_D1_BIAS;
         detail      = StringFormat("close=%.5f ema=%.5f", close_d1, ema);
         return(false);
        }

      return(true);
     }

public:
   static bool AllowSignal(const string               symbol,
                           const ENUM_ORBVWAP_SIGNAL  signal,
                           CIndicatorManager         &indicators,
                           const double               range_width,
                           const double               close_1,
                           const double               vwap,
                           const double               atr,
                           const long                 tick_vol,
                           const double               vol_ma,
                           string                    &reject_code,
                           string                    &detail)
     {
      if(!CheckCommon(symbol, indicators, range_width, close_1, vwap, atr,
                      tick_vol, vol_ma, reject_code, detail))
         return(false);

      if(!CheckD1Bias(symbol, indicators, signal, reject_code, detail))
         return(false);

      if(!H4StructureAllows(symbol, signal, reject_code, detail))
         return(false);

      return(true);
     }
  };

#endif // __ORBVWAP_ENTRYFILTERS_MQH__
