//+------------------------------------------------------------------+
//| SignalEngine.mqh                                                 |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_SIGNALENGINE_MQH__
#define __ORBVWAP_SIGNALENGINE_MQH__

#include "Types.mqh"
#include "Inputs.mqh"
#include "Constants.mqh"
#include "IndicatorManager.mqh"
#include "OpeningRange.mqh"
#include "SessionVwap.mqh"
#include "SessionUtils.mqh"
#include "StateTracker.mqh"
#include "EntryFilters.mqh"
#include "Logger.mqh"

class CSignalEngine
  {
   static void Reject(SSignalResult          &result,
                      const string            reason_code,
                      const string            detail    = "",
                      const ENUM_ORBVWAP_SIGNAL direction = ORBVWAP_SIGNAL_NONE)
     {
      result.signal        = ORBVWAP_SIGNAL_NONE;
      result.reject_reason = reason_code;
      COrbVwapLogger::Journal(reason_code, detail, OrbVwapSignalDirection(direction));
     }

public:
   static SSignalResult Evaluate(const string            symbol,
                                 const SSessionContext  &session,
                                 COpeningRange          &opening_range,
                                 CSessionVwap           &session_vwap,
                                 CIndicatorManager      &indicators,
                                 CStateTracker          &state)
     {
      SSignalResult result;
      result.Clear();

      if(!indicators.IsReady())
        {
         result.reject_reason = "indicators_not_ready";
         return(result);
        }

      if(!session.active)
        {
         Reject(result, ORBVWAP_REJECT_OUTSIDE_SESSION);
         return(result);
        }

      const datetime signal_bar_time = iTime(symbol, PERIOD_CURRENT, 1);
      if(!CSessionUtils::IsEntryTimeAllowed(signal_bar_time))
        {
         Reject(result, ORBVWAP_REJECT_ENTRY_CUTOFF,
                StringFormat("gmt_hour=%d cutoff=%d",
                             CSessionUtils::GmtHour(signal_bar_time),
                             InpNoEntryAfterHour));
         return(result);
        }

      if(!CSessionUtils::IsWeekdayAllowed(signal_bar_time))
        {
         MqlDateTime dt;
         TimeToStruct(CSessionUtils::BarTimeToGmt(signal_bar_time), dt);
         Reject(result, ORBVWAP_REJECT_WEEKDAY_SKIP,
                StringFormat("day_of_week=%d mask=%d", dt.day_of_week, InpSkipWeekdays));
         return(result);
        }

      if(!CSessionUtils::IsNyEntryDelaySatisfied(signal_bar_time, session))
        {
         const int elapsed_min = (int)((CSessionUtils::BarTimeToGmt(signal_bar_time) -
                                        session.session_open_gmt) / 60);
         Reject(result, ORBVWAP_REJECT_NY_ENTRY_DELAY,
                StringFormat("elapsed_min=%d need=%d", elapsed_min, InpNyEntryDelayMin));
         return(result);
        }

      if(!CSessionUtils::IsLondonEntryDelaySatisfied(signal_bar_time, session))
        {
         const int elapsed_min = (int)((CSessionUtils::BarTimeToGmt(signal_bar_time) -
                                        session.session_open_gmt) / 60);
         Reject(result, ORBVWAP_REJECT_LONDON_ENTRY_DELAY,
                StringFormat("elapsed_min=%d need=%d", elapsed_min, InpLondonEntryDelayMin));
         return(result);
        }

      state.SyncSession(session.session_open_broker);

      if(state.IsBreakoutConsumed() || opening_range.IsTraded())
        {
         Reject(result, ORBVWAP_REJECT_ALREADY_TRADED);
         return(result);
        }

      if(opening_range.IsForming())
        {
         Reject(result, ORBVWAP_REJECT_RANGE_FORMING);
         return(result);
        }

      if(!opening_range.IsLocked())
        {
         Reject(result, ORBVWAP_REJECT_RANGE_FORMING, "not_locked");
         return(result);
        }

      double atr = 0.0;
      if(!indicators.GetATR(1, atr) || atr <= 0.0)
        {
         result.reject_reason = "atr_unavailable";
         return(result);
        }

      const double range_width = opening_range.Width();
      if(range_width < InpMinRangeAtrFactor * atr)
        {
         Reject(result, ORBVWAP_REJECT_RANGE_TOO_NARROW,
                StringFormat("width=%.5f min=%.5f", range_width, InpMinRangeAtrFactor * atr));
         return(result);
        }

      double vwap = 0.0;
      if(!session_vwap.Value(vwap))
        {
         result.reject_reason = "vwap_unavailable";
         return(result);
        }

      const double close_1 = iClose(symbol, PERIOD_CURRENT, 1);
      if(close_1 <= 0.0)
         return(result);

      long tick_vol = 0;
      double vol_ma = 0.0;
      if(!indicators.GetTickVolume(1, tick_vol) || !indicators.GetVolumeMA(1, vol_ma))
        {
         result.reject_reason = "volume_unavailable";
         return(result);
        }

      const double vol_threshold = vol_ma * InpVolumeMultiplier;
      const bool volume_ok = ((double)tick_vol >= vol_threshold);

      const double range_high = opening_range.High();
      const double range_low  = opening_range.Low();

      if(close_1 > range_high)
        {
         if(!opening_range.IsBreakoutFresh(symbol, PERIOD_CURRENT, signal_bar_time))
           {
            Reject(result, ORBVWAP_REJECT_STALE_BREAKOUT,
                   StringFormat("max_bars=%d", InpMaxBarsAfterLock), ORBVWAP_SIGNAL_BUY);
            return(result);
           }
         if(close_1 <= vwap)
           {
            Reject(result, ORBVWAP_REJECT_WRONG_SIDE_VWAP,
                   StringFormat("close=%.5f vwap=%.5f", close_1, vwap), ORBVWAP_SIGNAL_BUY);
            return(result);
           }
         if(!volume_ok)
           {
            Reject(result, ORBVWAP_REJECT_VOL_INSUFFICIENT,
                   StringFormat("vol=%d need=%.1f", tick_vol, vol_threshold), ORBVWAP_SIGNAL_BUY);
            return(result);
           }

         string filter_code = "";
         string filter_detail = "";
         if(!CEntryFilters::AllowSignal(symbol, ORBVWAP_SIGNAL_BUY, indicators,
                                         range_width, close_1, vwap, atr,
                                         tick_vol, vol_ma, filter_code, filter_detail))
           {
            Reject(result, filter_code, filter_detail, ORBVWAP_SIGNAL_BUY);
            return(result);
           }

         result.signal          = ORBVWAP_SIGNAL_BUY;
         result.signal_bar      = 1;
         result.reference_price = close_1;
         COrbVwapLogger::Info(StringFormat("Signal BUY close=%.5f range_high=%.5f vwap=%.5f vol=%d",
                                            close_1, range_high, vwap, tick_vol));
         return(result);
        }

      if(close_1 < range_low)
        {
         if(!opening_range.IsBreakoutFresh(symbol, PERIOD_CURRENT, signal_bar_time))
           {
            Reject(result, ORBVWAP_REJECT_STALE_BREAKOUT,
                   StringFormat("max_bars=%d", InpMaxBarsAfterLock), ORBVWAP_SIGNAL_SELL);
            return(result);
           }
         if(close_1 >= vwap)
           {
            Reject(result, ORBVWAP_REJECT_WRONG_SIDE_VWAP,
                   StringFormat("close=%.5f vwap=%.5f", close_1, vwap), ORBVWAP_SIGNAL_SELL);
            return(result);
           }
         if(!volume_ok)
           {
            Reject(result, ORBVWAP_REJECT_VOL_INSUFFICIENT,
                   StringFormat("vol=%d need=%.1f", tick_vol, vol_threshold), ORBVWAP_SIGNAL_SELL);
            return(result);
           }

         string filter_code = "";
         string filter_detail = "";
         if(!CEntryFilters::AllowSignal(symbol, ORBVWAP_SIGNAL_SELL, indicators,
                                         range_width, close_1, vwap, atr,
                                         tick_vol, vol_ma, filter_code, filter_detail))
           {
            Reject(result, filter_code, filter_detail, ORBVWAP_SIGNAL_SELL);
            return(result);
           }

         result.signal          = ORBVWAP_SIGNAL_SELL;
         result.signal_bar      = 1;
         result.reference_price = close_1;
         COrbVwapLogger::Info(StringFormat("Signal SELL close=%.5f range_low=%.5f vwap=%.5f vol=%d",
                                            close_1, range_low, vwap, tick_vol));
         return(result);
        }

      Reject(result, ORBVWAP_REJECT_NO_BREAKOUT,
             StringFormat("close=%.5f range=[%.5f, %.5f]", close_1, range_low, range_high));
      return(result);
     }
  };

#endif // __ORBVWAP_SIGNALENGINE_MQH__
