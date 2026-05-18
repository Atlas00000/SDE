//+------------------------------------------------------------------+
//| VEM_Signal.mqh                                                   |
//| Definitions: long — Low pierces lower band by penetration pts; |
//| volume >= vol_ma * mult on signal bar. Mirror for short.         |
//| D10: setup bar (shift+1) extreme + confirm bar (shift) path.     |
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

inline bool VEM_Signal_ConfirmLong(const VEMIndicatorSnap &confirm)
  {
   if(!confirm.valid)
      return false;

   const bool reenter = (confirm.close >= confirm.bb_lower);
   const bool reject = (confirm.close > confirm.open);

   if(inp_confirm_mode == VEM_CONFIRM_REENTER)
      return reenter;
   if(inp_confirm_mode == VEM_CONFIRM_REJECT)
      return reject;
   return (reenter || reject);
  }

inline bool VEM_Signal_ConfirmShort(const VEMIndicatorSnap &confirm)
  {
   if(!confirm.valid)
      return false;

   const bool reenter = (confirm.close <= confirm.bb_upper);
   const bool reject = (confirm.close < confirm.open);

   if(inp_confirm_mode == VEM_CONFIRM_REENTER)
      return reenter;
   if(inp_confirm_mode == VEM_CONFIRM_REJECT)
      return reject;
   return (reenter || reject);
  }

inline void VEM_Signal_Evaluate(const string sym, const ENUM_TIMEFRAMES tf,
                              const int signal_shift, bool &want_long, bool &want_short)
  {
   want_long = false;
   want_short = false;

   if(!inp_confirm_bar_enable)
     {
      VEMIndicatorSnap s;
      if(!VEM_Indicators_Refresh(sym, tf, signal_shift, s))
         return;
      want_long = VEM_Signal_LongRaw(s, sym);
      want_short = VEM_Signal_ShortRaw(s, sym);
      return;
     }

   const int setup_shift = signal_shift + 1;
   VEMIndicatorSnap setup, confirm;
   if(!VEM_Indicators_Refresh(sym, tf, setup_shift, setup))
      return;
   if(!VEM_Indicators_Refresh(sym, tf, signal_shift, confirm))
      return;

   if(VEM_Signal_LongRaw(setup, sym) && VEM_Signal_ConfirmLong(confirm))
      want_long = true;
   if(VEM_Signal_ShortRaw(setup, sym) && VEM_Signal_ConfirmShort(confirm))
      want_short = true;
  }

#endif // VEM_SIGNAL_MQH
