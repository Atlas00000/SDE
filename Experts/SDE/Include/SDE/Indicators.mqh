#ifndef __SDE_INDICATORS_MQH__
#define __SDE_INDICATORS_MQH__

#include "Config.mqh"

struct SdeIndicatorSnapshot
  {
   double bb_upper;
   double bb_middle;
   double bb_lower;
   double adx;
   double kc_upper;
   double kc_middle;
   double kc_lower;
   double close_price;
  };

class SdeIndicators
  {
private:
   string     m_symbol;
   ENUM_TIMEFRAMES m_tf;
   SdeConfig  m_cfg;
   int        m_bb_handle;
   int        m_adx_handle;
   int        m_ema_handle;
   int        m_atr_handle;

public:
   bool Init(const string symbol,ENUM_TIMEFRAMES tf,const SdeConfig &cfg)
     {
      m_symbol=symbol;
      m_tf=tf;
      m_cfg=cfg;
      m_bb_handle=iBands(m_symbol,m_tf,m_cfg.bb_period,0,m_cfg.bb_deviation,PRICE_CLOSE);
      m_adx_handle=iADX(m_symbol,m_tf,m_cfg.adx_period);
      m_ema_handle=iMA(m_symbol,m_tf,m_cfg.kc_period,0,MODE_EMA,PRICE_TYPICAL);
      m_atr_handle=iATR(m_symbol,m_tf,m_cfg.kc_period);
      return (m_bb_handle!=INVALID_HANDLE && m_adx_handle!=INVALID_HANDLE && m_ema_handle!=INVALID_HANDLE && m_atr_handle!=INVALID_HANDLE);
     }

   void Release()
     {
      if(m_bb_handle!=INVALID_HANDLE) IndicatorRelease(m_bb_handle);
      if(m_adx_handle!=INVALID_HANDLE) IndicatorRelease(m_adx_handle);
      if(m_ema_handle!=INVALID_HANDLE) IndicatorRelease(m_ema_handle);
      if(m_atr_handle!=INVALID_HANDLE) IndicatorRelease(m_atr_handle);
      m_bb_handle=INVALID_HANDLE;
      m_adx_handle=INVALID_HANDLE;
      m_ema_handle=INVALID_HANDLE;
      m_atr_handle=INVALID_HANDLE;
     }

   bool Ready() const
     {
      if(m_bb_handle==INVALID_HANDLE || m_adx_handle==INVALID_HANDLE || m_ema_handle==INVALID_HANDLE || m_atr_handle==INVALID_HANDLE)
         return false;
      if(BarsCalculated(m_bb_handle)<m_cfg.bb_period+20) return false;
      if(BarsCalculated(m_adx_handle)<m_cfg.adx_period+20) return false;
      if(BarsCalculated(m_ema_handle)<m_cfg.kc_period+20) return false;
      if(BarsCalculated(m_atr_handle)<m_cfg.kc_period+20) return false;
      return true;
     }

   bool ReadSnapshot(const int shift,SdeIndicatorSnapshot &out)
     {
      double bb_up[1],bb_mid[1],bb_lo[1],adx_main[1],ema[1],atr[1],close_val[1];

      if(CopyBuffer(m_bb_handle,1,shift,1,bb_up)!=1) return false;
      if(CopyBuffer(m_bb_handle,0,shift,1,bb_mid)!=1) return false;
      if(CopyBuffer(m_bb_handle,2,shift,1,bb_lo)!=1) return false;
      if(CopyBuffer(m_adx_handle,0,shift,1,adx_main)!=1) return false;
      if(CopyBuffer(m_ema_handle,0,shift,1,ema)!=1) return false;
      if(CopyBuffer(m_atr_handle,0,shift,1,atr)!=1) return false;
      if(CopyClose(m_symbol,m_tf,shift,1,close_val)!=1) return false;

      out.bb_upper=bb_up[0];
      out.bb_middle=bb_mid[0];
      out.bb_lower=bb_lo[0];
      out.adx=adx_main[0];
      out.kc_middle=ema[0];
      out.kc_upper=ema[0]+(atr[0]*m_cfg.kc_multiplier);
      out.kc_lower=ema[0]-(atr[0]*m_cfg.kc_multiplier);
      out.close_price=close_val[0];
      return true;
     }
  };

#endif
