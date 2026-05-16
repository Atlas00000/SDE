//+------------------------------------------------------------------+
//| VEM_Signal.mqh                                                   |
//| Definitions: long — Low pierces lower band by penetration pts; |
//| volume >= vol_ma * mult on signal bar. Mirror for short.         |
//+------------------------------------------------------------------+
#ifndef VEM_SIGNAL_MQH
#define VEM_SIGNAL_MQH

#include <VEM/VEM_Config.mqh>
#include <VEM/VEM_Indicators.mqh>

inline bool VEM_Signal_VolumeSpike(const VEMIndicatorSnap &s)
  {
   if(s.volume_ma <= 0.0)
      return false;
   return (s.volume >= s.volume_ma * inp_vol_spike_mult);
  }

inline bool VEM_Signal_LongRaw(const VEMIndicatorSnap &s, const string sym)
  {
   if(!s.valid)
      return false;
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double pierce = inp_bb_penetration_pts * pt;
   const bool bb_ok = (s.low <= s.bb_lower - pierce);
   const bool rsi_ok = (s.rsi < inp_rsi_os);
   const bool vol_ok = VEM_Signal_VolumeSpike(s);
   return bb_ok && rsi_ok && vol_ok;
  }

inline bool VEM_Signal_ShortRaw(const VEMIndicatorSnap &s, const string sym)
  {
   if(!s.valid)
      return false;
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double pierce = inp_bb_penetration_pts * pt;
   const bool bb_ok = (s.high >= s.bb_upper + pierce);
   const bool rsi_ok = (s.rsi > inp_rsi_ob);
   const bool vol_ok = VEM_Signal_VolumeSpike(s);
   return bb_ok && rsi_ok && vol_ok;
  }

inline void VEM_Signal_Evaluate(const string sym, const VEMIndicatorSnap &s,
                              bool &want_long, bool &want_short)
  {
   want_long = VEM_Signal_LongRaw(s, sym);
   want_short = VEM_Signal_ShortRaw(s, sym);
  }

#endif // VEM_SIGNAL_MQH
