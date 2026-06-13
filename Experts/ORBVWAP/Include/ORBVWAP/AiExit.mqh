//+------------------------------------------------------------------+
//| AiExit.mqh — AI-4 stall-scratch exit overlay (auto-generated)    |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AIEXIT_MQH__
#define __ORBVWAP_AIEXIT_MQH__

#include "Inputs.mqh"

const int    ORBVWAP_AI4_STALL_MINUTES = 45;
const double ORBVWAP_AI4_STALL_MFE_FRAC = 0.250000;

class CAiExit
  {
public:
   static int StallMinutes() { return(ORBVWAP_AI4_STALL_MINUTES); }

   static double StallMfeFrac() { return(ORBVWAP_AI4_STALL_MFE_FRAC); }

   static bool ShouldStallScratch(const int hold_minutes, const double mfe_frac)
     {
      if(hold_minutes < ORBVWAP_AI4_STALL_MINUTES)
         return(false);
      return(mfe_frac < ORBVWAP_AI4_STALL_MFE_FRAC);
     }
  };

#endif // __ORBVWAP_AIEXIT_MQH__
