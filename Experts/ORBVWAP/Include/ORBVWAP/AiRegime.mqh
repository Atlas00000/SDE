//+------------------------------------------------------------------+
//| AiRegime.mqh — AI-3 session gate (auto-generated)                |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AIREGIME_MQH__
#define __ORBVWAP_AIREGIME_MQH__

#include "Inputs.mqh"
#include "Types.mqh"
#include "SessionUtils.mqh"
#include "OpeningRange.mqh"
#include "SessionVwap.mqh"
#include "IndicatorManager.mqh"

const double ORBVWAP_AI3_SKIP_PROB = 0.60000000;

class CAiRegime
  {
   static double ChopProbability(const double range_width_atr,
                                 const double vol_ratio,
                                 const double spread_pct_range,
                                 const double vwap_dist_atr,
                                 const double weekday,
                                 const double session_ny,
                                 const double prior_session_loss)
     {
      if(spread_pct_range <= 1.70500004)
         if(vol_ratio <= 1.82270002)
            if(vol_ratio <= 1.52929997)
               return(0.60000000);
            else
               return(0.19642857);
         else
            if(vwap_dist_atr <= 1.50199997)
               return(0.87500000);
            else
               return(0.40000000);
      else
         if(vol_ratio <= 1.67304999)
            if(vol_ratio <= 1.65719998)
               return(0.50000000);
            else
               return(0.00000000);
         else
            if(range_width_atr <= 5.74655008)
               return(0.55555556);
            else
               return(1.00000000);
     }

public:
   static bool AllowSession(const double range_width_atr,
                            const double vol_ratio,
                            const double spread_pct_range,
                            const double vwap_dist_atr,
                            const int    weekday,
                            const bool   is_ny_session,
                            const double prior_session_loss)
     {
      const double session_ny = is_ny_session ? 1.0 : 0.0;
      const double chop = ChopProbability(range_width_atr, vol_ratio, spread_pct_range,
                                          vwap_dist_atr, (double)weekday, session_ny,
                                          prior_session_loss);
      return(chop < ORBVWAP_AI3_SKIP_PROB);
     }

   static bool AllowFromPipeline(const string               symbol,
                                 const SSessionContext       &session,
                                 COpeningRange               &opening_range,
                                 CSessionVwap                &session_vwap,
                                 CIndicatorManager           &indicators,
                                 const double                 prior_session_loss)
     {
      double atr = 0.0;
      indicators.GetATR(1, atr);
      const double range_width = opening_range.Width();
      double range_width_atr = 0.0;
      if(atr > 0.0)
         range_width_atr = range_width / atr;
      long tick_vol = 0;
      double vol_ma = 0.0;
      indicators.GetTickVolume(1, tick_vol);
      indicators.GetVolumeMA(1, vol_ma);
      double vol_ratio = 0.0;
      if(vol_ma > 0.0)
         vol_ratio = (double)tick_vol / vol_ma;
      double vwap = 0.0;
      session_vwap.Value(vwap);
      const double close = iClose(symbol, PERIOD_CURRENT, 1);
      double vwap_dist_atr = 0.0;
      if(atr > 0.0)
         vwap_dist_atr = MathAbs(close - vwap) / atr;
      double spread_pct_range = 0.0;
      if(range_width > 0.0)
        {
         const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         spread_pct_range = (ask - bid) / range_width * 100.0;
        }
      const datetime signal_bar_time = iTime(symbol, PERIOD_CURRENT, 1);
      const datetime bar_gmt = CSessionUtils::BarTimeToGmt(signal_bar_time);
      MqlDateTime dt;
      TimeToStruct(bar_gmt, dt);
      const bool is_ny = (session.session == ORBVWAP_SESSION_NY);
      return(AllowSession(range_width_atr, vol_ratio, spread_pct_range, vwap_dist_atr,
                          dt.day_of_week, is_ny, prior_session_loss));
     }
  };

#endif // __ORBVWAP_AIREGIME_MQH__
