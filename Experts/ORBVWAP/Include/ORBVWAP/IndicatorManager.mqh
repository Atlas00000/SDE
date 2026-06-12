//+------------------------------------------------------------------+
//| IndicatorManager.mqh                                             |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_INDICATORMANAGER_MQH__
#define __ORBVWAP_INDICATORMANAGER_MQH__

#include "Inputs.mqh"
#include "Logger.mqh"

class CIndicatorManager
  {
   string          m_symbol;
   ENUM_TIMEFRAMES m_period;
   int             m_handle_atr;
   int             m_handle_atr_slow;
   int             m_handle_adx_m15;
   int             m_handle_d1_ema;

   bool CopyValue(const int handle, const int shift, double &value) const
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(handle, 0, shift, 1, buf) != 1)
         return(false);
      value = buf[0];
      return(true);
     }

   static bool UsesAtrSlow()
     {
      return(InpAtrExpMax > 0.0);
     }

   static bool UsesM15Adx()
     {
      return(InpAdxMax > 0.0);
     }

   static bool UsesD1Ema()
     {
      return(InpD1EmaPeriod > 0);
     }

public:
   CIndicatorManager()
     {
      m_symbol           = "";
      m_period           = PERIOD_CURRENT;
      m_handle_atr       = INVALID_HANDLE;
      m_handle_atr_slow  = INVALID_HANDLE;
      m_handle_adx_m15   = INVALID_HANDLE;
      m_handle_d1_ema    = INVALID_HANDLE;
     }

   bool Init(const string symbol, const ENUM_TIMEFRAMES period)
     {
      m_symbol = symbol;
      m_period = period;
      m_handle_atr = iATR(m_symbol, m_period, InpAtrPeriod);

      if(m_handle_atr == INVALID_HANDLE)
        {
         COrbVwapLogger::Error("ATR handle creation failed");
         Release();
         return(false);
        }

      if(UsesAtrSlow())
        {
         m_handle_atr_slow = iATR(m_symbol, m_period, InpAtrSlowPeriod);
         if(m_handle_atr_slow == INVALID_HANDLE)
           {
            COrbVwapLogger::Error("ATR slow handle creation failed");
            Release();
            return(false);
           }
        }

      if(UsesM15Adx())
        {
         m_handle_adx_m15 = iADX(m_symbol, PERIOD_M15, InpAdxPeriod);
         if(m_handle_adx_m15 == INVALID_HANDLE)
           {
            COrbVwapLogger::Error("M15 ADX handle creation failed");
            Release();
            return(false);
           }
        }

      if(UsesD1Ema())
        {
         m_handle_d1_ema = iMA(m_symbol, PERIOD_D1, InpD1EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
         if(m_handle_d1_ema == INVALID_HANDLE)
           {
            COrbVwapLogger::Error("D1 EMA handle creation failed");
            Release();
            return(false);
           }
        }

      return(true);
     }

   void Release()
     {
      if(m_handle_atr != INVALID_HANDLE)
        {
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
        }
      if(m_handle_atr_slow != INVALID_HANDLE)
        {
         IndicatorRelease(m_handle_atr_slow);
         m_handle_atr_slow = INVALID_HANDLE;
        }
      if(m_handle_adx_m15 != INVALID_HANDLE)
        {
         IndicatorRelease(m_handle_adx_m15);
         m_handle_adx_m15 = INVALID_HANDLE;
        }
      if(m_handle_d1_ema != INVALID_HANDLE)
        {
         IndicatorRelease(m_handle_d1_ema);
         m_handle_d1_ema = INVALID_HANDLE;
        }
     }

   bool IsReady() const
     {
      if(m_handle_atr == INVALID_HANDLE)
         return(false);

      const int need_bars = MathMax(InpAtrPeriod, InpVolumeMaPeriod) + 5;
      if(Bars(m_symbol, m_period) < need_bars)
         return(false);

      double probe = 0.0;
      if(!CopyValue(m_handle_atr, 1, probe))
         return(false);

      if(UsesAtrSlow())
        {
         if(m_handle_atr_slow == INVALID_HANDLE ||
            Bars(m_symbol, m_period) < InpAtrSlowPeriod + 5 ||
            !CopyValue(m_handle_atr_slow, 1, probe))
            return(false);
        }

      if(UsesM15Adx())
        {
         if(m_handle_adx_m15 == INVALID_HANDLE ||
            Bars(m_symbol, PERIOD_M15) < InpAdxPeriod + 5 ||
            !CopyValue(m_handle_adx_m15, 1, probe))
            return(false);
        }

      if(UsesD1Ema())
        {
         if(m_handle_d1_ema == INVALID_HANDLE ||
            Bars(m_symbol, PERIOD_D1) < InpD1EmaPeriod + 5 ||
            !CopyValue(m_handle_d1_ema, 1, probe))
            return(false);
        }

      return(true);
     }

   bool GetATR(const int shift, double &value) const
     {
      return(CopyValue(m_handle_atr, shift, value));
     }

   bool GetATRSlow(const int shift, double &value) const
     {
      if(m_handle_atr_slow == INVALID_HANDLE)
         return(false);
      return(CopyValue(m_handle_atr_slow, shift, value));
     }

   bool GetM15Adx(const int shift, double &value) const
     {
      if(m_handle_adx_m15 == INVALID_HANDLE)
         return(false);
      return(CopyValue(m_handle_adx_m15, shift, value));
     }

   bool GetD1Ema(const int shift, double &value) const
     {
      if(m_handle_d1_ema == INVALID_HANDLE)
         return(false);
      return(CopyValue(m_handle_d1_ema, shift, value));
     }

   bool GetTickVolume(const int shift, long &value) const
     {
      value = iTickVolume(m_symbol, m_period, shift);
      return(value > 0);
     }

   bool GetVolumeMA(const int shift, double &value) const
     {
      value = 0.0;
      if(InpVolumeMaPeriod <= 0)
         return(false);

      double sum = 0.0;
      for(int i = shift; i < shift + InpVolumeMaPeriod; i++)
        {
         const long vol = iTickVolume(m_symbol, m_period, i);
         if(vol <= 0)
            return(false);
         sum += (double)vol;
        }

      value = sum / (double)InpVolumeMaPeriod;
      return(value > 0.0);
     }
  };

#endif // __ORBVWAP_INDICATORMANAGER_MQH__
