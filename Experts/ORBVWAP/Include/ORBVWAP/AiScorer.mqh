//+------------------------------------------------------------------+
//| AiScorer.mqh — AI-1 L1 logistic scorer (auto-generated)          |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AISCORER_MQH__
#define __ORBVWAP_AISCORER_MQH__

#include "Inputs.mqh"
#include "Types.mqh"
#include "AiFeatures.mqh"

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
      double feats[];
      CAiFeatures::FillAi1(symbol, session, signal, opening_range, session_vwap, indicators,
                           setup.risk_reward, feats);

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
