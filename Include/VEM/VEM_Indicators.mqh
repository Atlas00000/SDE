//+------------------------------------------------------------------+
//| VEM_Indicators.mqh                                               |
//+------------------------------------------------------------------+
#ifndef VEM_INDICATORS_MQH
#define VEM_INDICATORS_MQH

#include <VEM/VEM_Config.mqh>

struct VEMIndicatorSnap
  {
   datetime bar_time;
   double   open;
   double   high;
   double   low;
   double   close;
   double   bb_upper;
   double   bb_middle;
   double   bb_lower;
   double   rsi;
   double   volume;
   double   volume_ma;
   double   atr;
   bool     valid;
  };

static int g_bb_handle     = INVALID_HANDLE;
static int g_rsi_handle    = INVALID_HANDLE;
static int g_atr_handle    = INVALID_HANDLE;
static int g_ema_handle    = INVALID_HANDLE;
static int g_htf_ema_handle = INVALID_HANDLE;

// Volume MA: MQL5 iMA has no applied "volume" price; SMA is computed from tick volume.

inline bool VEM_Indicators_Init(const string sym, const ENUM_TIMEFRAMES tf)
  {
   IndicatorRelease(g_bb_handle);
   IndicatorRelease(g_rsi_handle);
   IndicatorRelease(g_atr_handle);
   IndicatorRelease(g_ema_handle);

   IndicatorRelease(g_htf_ema_handle);
   g_htf_ema_handle = INVALID_HANDLE;

   g_bb_handle = iBands(sym, tf, inp_bb_period, 0, inp_bb_dev, PRICE_CLOSE);
   g_rsi_handle = iRSI(sym, tf, inp_rsi_period, PRICE_CLOSE);
   g_atr_handle = iATR(sym, tf, inp_bb_period);
   const int ema_period = MathMax(2, inp_ema_period);
   g_ema_handle = iMA(sym, tf, ema_period, 0, MODE_EMA, PRICE_CLOSE);

   if(inp_htf_regime_enable)
     {
      const int htf_ema = MathMax(2, inp_htf_ema_period);
      g_htf_ema_handle = iMA(sym, inp_htf_timeframe, htf_ema, 0, MODE_EMA, PRICE_CLOSE);
     }

   if(g_bb_handle == INVALID_HANDLE || g_rsi_handle == INVALID_HANDLE ||
      g_atr_handle == INVALID_HANDLE || g_ema_handle == INVALID_HANDLE)
      return false;
   if(inp_htf_regime_enable && g_htf_ema_handle == INVALID_HANDLE)
      return false;

   return true;
  }

inline bool VEM_Indicators_WaitReady(const int min_calculated_bars)
  {
   if(g_bb_handle == INVALID_HANDLE)
      return false;
   for(int k = 0; k < 80; k++)
     {
      const int n = BarsCalculated(g_bb_handle);
      if(n >= min_calculated_bars && n != -1)
         return true;
      Sleep(25);
     }
   const int n = BarsCalculated(g_bb_handle);
   return (n >= min_calculated_bars && n != -1);
  }

inline void VEM_Indicators_Deinit()
  {
   IndicatorRelease(g_bb_handle);
   IndicatorRelease(g_rsi_handle);
   IndicatorRelease(g_atr_handle);
   IndicatorRelease(g_ema_handle);
   IndicatorRelease(g_htf_ema_handle);
   g_bb_handle = g_rsi_handle = g_atr_handle = g_ema_handle = INVALID_HANDLE;
   g_htf_ema_handle = INVALID_HANDLE;
  }

inline bool VEM_Indicators_WaitHtfReady()
  {
   if(!inp_htf_regime_enable || g_htf_ema_handle == INVALID_HANDLE)
      return true;

   const int need = inp_htf_ema_period + inp_htf_slope_lookback_bars + 5;
   for(int k = 0; k < 80; k++)
     {
      const int n = BarsCalculated(g_htf_ema_handle);
      if(n >= need && n != -1)
         return true;
      Sleep(25);
     }
   const int n = BarsCalculated(g_htf_ema_handle);
   return (n >= need && n != -1);
  }

inline bool VEM_Indicators_Refresh(const string sym, const ENUM_TIMEFRAMES tf,
                                   const int shift, VEMIndicatorSnap &out)
  {
   ZeroMemory(out);
   out.valid = false;

   if(shift < 0)
      return false;

   double bb_mid[], bb_up[], bb_lo[], rsi[], atr[];
   ArraySetAsSeries(bb_mid, true);
   ArraySetAsSeries(bb_up, true);
   ArraySetAsSeries(bb_lo, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);

   // iBands buffers: 0 = middle, 1 = upper, 2 = lower (standard MT5)
   if(CopyBuffer(g_bb_handle, 0, shift, 3, bb_mid) <= 0)
      return false;
   if(CopyBuffer(g_bb_handle, 1, shift, 3, bb_up) <= 0)
      return false;
   if(CopyBuffer(g_bb_handle, 2, shift, 3, bb_lo) <= 0)
      return false;
   if(CopyBuffer(g_rsi_handle, 0, shift, 3, rsi) <= 0)
      return false;
   if(CopyBuffer(g_atr_handle, 0, shift, 3, atr) <= 0)
      return false;

   const int vol_period = MathMax(1, inp_vol_ma_period);
   double vol_sum = 0.0;
   for(int i = 0; i < vol_period; i++)
     {
      const int sh = shift + i;
      if(sh < 0)
         return false;
      vol_sum += (double)iVolume(sym, tf, sh);
     }
   const double volume_ma = vol_sum / (double)vol_period;

   out.bar_time = iTime(sym, tf, shift);
   out.open     = iOpen(sym, tf, shift);
   out.high     = iHigh(sym, tf, shift);
   out.low      = iLow(sym, tf, shift);
   out.close    = iClose(sym, tf, shift);

   out.bb_upper = bb_up[0];
   out.bb_middle = bb_mid[0];
   out.bb_lower = bb_lo[0];
   out.rsi = rsi[0];
   long tick_vol = iVolume(sym, tf, shift);
   out.volume = (double)tick_vol;
   out.volume_ma = volume_ma;
   out.atr = atr[0];
   out.valid = true;
   return true;
  }

// Relative band width on signal bar: (upper - lower) / middle.
inline double VEM_Indicators_BBWidthRatio(const VEMIndicatorSnap &s)
  {
   if(!s.valid || s.bb_middle <= 0.0)
      return 0.0;
   return (s.bb_upper - s.bb_lower) / s.bb_middle;
  }

// EMA slope in basis points over lookback bars on closed bars (Step B1 proxy).
inline bool VEM_Indicators_EMASlopeBp(const string sym, const ENUM_TIMEFRAMES tf,
                                      const int shift, double &slope_bp_out)
  {
   slope_bp_out = 0.0;
   if(g_ema_handle == INVALID_HANDLE)
      return false;

   const int lookback = MathMax(1, inp_ema_slope_lookback_bars);
   if(shift < 0)
      return false;

   double ema_now[], ema_prev[];
   ArraySetAsSeries(ema_now, true);
   ArraySetAsSeries(ema_prev, true);

   if(CopyBuffer(g_ema_handle, 0, shift, 1, ema_now) <= 0)
      return false;
   if(CopyBuffer(g_ema_handle, 0, shift + lookback, 1, ema_prev) <= 0)
      return false;
   if(ema_prev[0] <= 0.0)
      return false;

   slope_bp_out = (ema_now[0] - ema_prev[0]) / ema_prev[0] * 10000.0;
   return true;
  }

// Consecutive closed bars outside same band, counting from signal_shift backward (Step B9 / D9).
inline int VEM_Indicators_BBWalkCount(const string sym, const ENUM_TIMEFRAMES tf,
                                      const int signal_shift, const bool is_long)
  {
   int cnt = 0;
   const int max_look = 10;
   for(int j = 0; j < max_look; j++)
     {
      const int sh = signal_shift + j;
      VEMIndicatorSnap bar;
      if(!VEM_Indicators_Refresh(sym, tf, sh, bar) || !bar.valid)
         break;

      if(is_long)
        {
         if(bar.close < bar.bb_lower)
            cnt++;
         else
            break;
        }
      else
        {
         if(bar.close > bar.bb_upper)
            cnt++;
         else
            break;
        }
     }
   return cnt;
  }

// HTF EMA slope at signal bar time (Step D11 — block fade against HTF drift).
inline bool VEM_Indicators_HtfSlopeBp(const string sym, const datetime signal_bar_time,
                                      double &slope_bp_out)
  {
   slope_bp_out = 0.0;
   if(!inp_htf_regime_enable || g_htf_ema_handle == INVALID_HANDLE)
      return false;
   if(signal_bar_time <= 0)
      return false;

   const int shift = iBarShift(sym, inp_htf_timeframe, signal_bar_time, true);
   if(shift < 0)
      return false;

   const int lookback = MathMax(1, inp_htf_slope_lookback_bars);
   double ema_now[], ema_prev[];
   ArraySetAsSeries(ema_now, true);
   ArraySetAsSeries(ema_prev, true);

   if(CopyBuffer(g_htf_ema_handle, 0, shift, 1, ema_now) <= 0)
      return false;
   if(CopyBuffer(g_htf_ema_handle, 0, shift + lookback, 1, ema_prev) <= 0)
      return false;
   if(ema_prev[0] <= 0.0)
      return false;

   slope_bp_out = (ema_now[0] - ema_prev[0]) / ema_prev[0] * 10000.0;
   return true;
  }

#endif // VEM_INDICATORS_MQH
