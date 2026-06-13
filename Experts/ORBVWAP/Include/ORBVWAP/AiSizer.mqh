//+------------------------------------------------------------------+
//| AiSizer.mqh — AI-2 dynamic sizing (auto-generated)               |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AISIZER_MQH__
#define __ORBVWAP_AISIZER_MQH__

#include "Inputs.mqh"

const double ORBVWAP_AI2_SCORE_P50 = 0.54938864;
const double ORBVWAP_AI2_SCORE_P80 = 0.63546474;
const double ORBVWAP_AI2_MULT_LOW  = 1.0000;
const double ORBVWAP_AI2_MULT_MID  = 1.1500;
const double ORBVWAP_AI2_MULT_HIGH = 1.2500;

class CAiSizer
  {
public:
   static double Multiplier(const double ai_score)
     {
      if(ai_score < ORBVWAP_AI2_SCORE_P50)
         return(ORBVWAP_AI2_MULT_LOW);
      if(ai_score < ORBVWAP_AI2_SCORE_P80)
         return(ORBVWAP_AI2_MULT_MID);
      return(ORBVWAP_AI2_MULT_HIGH);
     }
  };

#endif // __ORBVWAP_AISIZER_MQH__
