//+------------------------------------------------------------------+
//| AiFeatures.mqh — INF-4 shared AI-1 feature vector (Py parity)    |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AIFEATURES_MQH__
#define __ORBVWAP_AIFEATURES_MQH__

#include "Types.mqh"
#include "SessionUtils.mqh"
#include "OpeningRange.mqh"
#include "SessionVwap.mqh"
#include "IndicatorManager.mqh"

const int ORBVWAP_AI1_FEATURE_COUNT = 10;
const int ORBVWAP_AI3_FEATURE_COUNT = 7;

class CAiFeatures
  {
   static int SpreadPoints(const string symbol)
     {
      const double ask   = SymbolInfoDouble(symbol, SYMBOL_ASK);
      const double bid   = SymbolInfoDouble(symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return(0);
      return((int)MathRound((ask - bid) / point));
     }

public:
   static void FillAi1(const string               symbol,
                       const SSessionContext       &session,
                       const ENUM_ORBVWAP_SIGNAL    signal,
                       COpeningRange               &opening_range,
                       CSessionVwap                &session_vwap,
                       CIndicatorManager           &indicators,
                       const double                 min_rr,
                       double                      &feats[])
     {
      ArrayResize(feats, ORBVWAP_AI1_FEATURE_COUNT);

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
      const double close_1 = iClose(symbol, PERIOD_CURRENT, 1);
      double vwap_dist_atr = 0.0;
      if(atr > 0.0 && vwap > 0.0)
         vwap_dist_atr = MathAbs(close_1 - vwap) / atr;

      double spread_pct_range = 0.0;
      if(range_width > 0.0)
        {
         const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         const int spread_pts = SpreadPoints(symbol);
         if(point > 0.0)
            spread_pct_range = 100.0 * (spread_pts * point) / range_width;
        }

      const datetime signal_bar_time = iTime(symbol, PERIOD_CURRENT, 1);
      const datetime bar_gmt = CSessionUtils::BarTimeToGmt(signal_bar_time);
      MqlDateTime dt;
      TimeToStruct(bar_gmt, dt);

      int ny_min_since_open = 0;
      if(session.session == ORBVWAP_SESSION_NY && session.session_open_gmt > 0)
         ny_min_since_open = (int)((bar_gmt - session.session_open_gmt) / 60);

      const double session_ny = (session.session == ORBVWAP_SESSION_NY) ? 1.0 : 0.0;
      const double direction_sell = (signal == ORBVWAP_SIGNAL_SELL) ? 1.0 : 0.0;

      feats[0] = range_width_atr;
      feats[1] = vol_ratio;
      feats[2] = vwap_dist_atr;
      feats[3] = spread_pct_range;
      feats[4] = min_rr;
      feats[5] = (double)dt.hour;
      feats[6] = (double)dt.day_of_week;
      feats[7] = (double)ny_min_since_open;
      feats[8] = session_ny;
      feats[9] = direction_sell;
     }

   static void FillRegime(const string               symbol,
                          const SSessionContext       &session,
                          COpeningRange               &opening_range,
                          CSessionVwap                &session_vwap,
                          CIndicatorManager           &indicators,
                          const double                 prior_session_loss,
                          double                      &feats[])
     {
      ArrayResize(feats, ORBVWAP_AI3_FEATURE_COUNT);

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
      const double close_1 = iClose(symbol, PERIOD_CURRENT, 1);
      double vwap_dist_atr = 0.0;
      if(atr > 0.0 && vwap > 0.0)
         vwap_dist_atr = MathAbs(close_1 - vwap) / atr;

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

      feats[0] = range_width_atr;
      feats[1] = vol_ratio;
      feats[2] = spread_pct_range;
      feats[3] = vwap_dist_atr;
      feats[4] = (double)dt.day_of_week;
      feats[5] = (session.session == ORBVWAP_SESSION_NY) ? 1.0 : 0.0;
      feats[6] = prior_session_loss;
     }

   static string FeatureNamesCsv()
     {
      return("feat_range_width_atr,feat_vol_ratio,feat_vwap_dist_atr,feat_spread_pct_range,"
             "feat_min_rr,feat_hour_gmt,feat_weekday,feat_ny_min_since_open,"
             "feat_session_ny,feat_direction_sell");
     }

   static string FeatureValuesCsv(const double &feats[])
     {
      if(ArraySize(feats) < ORBVWAP_AI1_FEATURE_COUNT)
         return("");
      return(StringFormat(
         "%.4f,%.4f,%.4f,%.2f,%.4f,%d,%d,%d,%.0f,%.0f",
         feats[0], feats[1], feats[2], feats[3], feats[4],
         (int)feats[5], (int)feats[6], (int)feats[7], feats[8], feats[9]));
     }
  };

#endif // __ORBVWAP_AIFEATURES_MQH__
