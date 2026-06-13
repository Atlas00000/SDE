//+------------------------------------------------------------------+
//| AiScorer.mqh — AI-1 L1 logistic scorer (auto-generated)          |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AISCORER_MQH__
#define __ORBVWAP_AISCORER_MQH__

#include "Inputs.mqh"
#include "Types.mqh"
#include "SessionUtils.mqh"
#include "OpeningRange.mqh"
#include "SessionVwap.mqh"
#include "IndicatorManager.mqh"

const string ORBVWAP_AI1_MODEL_ID = "ai1_v1";
const double ORBVWAP_AI1_MIN_SCORE = 0.300000;

class CAiScorer
  {
   static double Sigmoid(const double x)
     {
      if(x >= 0.0)
         return(1.0 / (1.0 + MathExp(-x)));
      const double ex = MathExp(x);
      return(ex / (1.0 + ex));
     }

public:
   static double MinScore() { return(ORBVWAP_AI1_MIN_SCORE); }

   static double Score(const string               symbol,
                       const SSessionContext       &session,
                       const ENUM_ORBVWAP_SIGNAL    signal,
                       COpeningRange               &opening_range,
                       CSessionVwap                &session_vwap,
                       CIndicatorManager           &indicators,
                       const STradeSetup           &setup)
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

      int ny_min_since_open = 0;
      if(session.session == ORBVWAP_SESSION_NY && session.session_open_gmt > 0)
         ny_min_since_open = (int)((bar_gmt - session.session_open_gmt) / 60);

      const double session_ny = (session.session == ORBVWAP_SESSION_NY) ? 1.0 : 0.0;
      const double direction_sell = (signal == ORBVWAP_SIGNAL_SELL) ? 1.0 : 0.0;

      const double feats[10] =
        {
         range_width_atr, vol_ratio, vwap_dist_atr, spread_pct_range, setup.risk_reward,
         (double)dt.hour, (double)dt.day_of_week, (double)ny_min_since_open,
         session_ny, direction_sell
        };

      const double means[10] = {
         4.42041600, 1.78227200, 2.59586560, 3.54380000, 0.94228800, 10.36000000, 2.20800000, 35.61600000, 0.34800000, 0.60800000
        };
      const double scales[10] = {
         3.30744598, 0.27992550, 2.11074993, 3.56718662, 0.02834506, 2.92684130, 1.21521027, 56.76129442, 0.47633602, 0.48819668
        };
      const double weights[10] = {
         -0.06770106, -0.21154343, 0.15789739, -0.23251841, 0.15283198, 0.30298682, -0.15022310, -0.25253887, -0.11519225, -0.20588397
        };
      const double bias = 0.16557048;

      double z = bias;
      for(int i = 0; i < 10; i++)
        {
         if(scales[i] > 0.0)
            z += weights[i] * ((feats[i] - means[i]) / scales[i]);
        }
      return(Sigmoid(z));
     }

   static bool Pass(const double score)
     {
      return(score >= ORBVWAP_AI1_MIN_SCORE);
     }
  };

#endif // __ORBVWAP_AISCORER_MQH__
