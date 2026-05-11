#ifndef __SDE_SIGNAL_ENGINE_MQH__
#define __SDE_SIGNAL_ENGINE_MQH__

#include "Config.mqh"
#include "State.mqh"
#include "Indicators.mqh"

struct SdeSignalResult
  {
   SdeDirection direction;
   bool         should_enter;
   string       reason;
  };

class SdeSignalEngine
  {
private:
   SdeConfig m_cfg;

   bool IsSqueezeOn(const SdeIndicatorSnapshot &s) const
     {
      return (s.bb_upper<=s.kc_upper && s.bb_lower>=s.kc_lower);
     }

   SdeDirection ExpansionDirection(const SdeIndicatorSnapshot &s) const
     {
      if(s.bb_upper>s.kc_upper && s.close_price>s.kc_middle)
         return DIR_BUY;
      if(s.bb_lower<s.kc_lower && s.close_price<s.kc_middle)
         return DIR_SELL;
      return DIR_NONE;
     }

public:
   void Init(const SdeConfig &cfg) { m_cfg=cfg; }

   SdeSignalResult Evaluate(const SdeIndicatorSnapshot &curr,const SdeIndicatorSnapshot &prev,SdeRuntimeState &st)
     {
      SdeSignalResult r;
      r.direction=DIR_NONE;
      r.should_enter=false;
      r.reason="";

      bool squeeze_now=IsSqueezeOn(curr);
      SdeDirection fired_dir=ExpansionDirection(curr);

      if(st.state==STATE_FLAT)
        {
         if(squeeze_now)
           {
            st.state=STATE_SQUEEZE_ON;
            st.squeeze_bars=1;
            r.reason="Entered SQUEEZE_ON";
           }
         return r;
        }

      if(st.state==STATE_SQUEEZE_ON)
        {
         if(squeeze_now)
           {
            st.squeeze_bars++;
            return r;
           }

         if(st.squeeze_bars<m_cfg.min_squeeze_bars || fired_dir==DIR_NONE)
           {
            st.state=STATE_FLAT;
            st.ResetSetup();
            r.reason="Invalid squeeze fire, reset FLAT";
            return r;
           }

         st.state=STATE_SQUEEZE_FIRED;
         st.direction=fired_dir;
         st.setup_bars_since_fire=0;
         st.setup_time=TimeCurrent();
         r.reason="SQUEEZE_FIRED";
         return r;
        }

      if(st.state==STATE_SQUEEZE_FIRED || st.state==STATE_ADX_CONFIRM)
        {
         if(fired_dir!=DIR_NONE && fired_dir!=st.direction)
           {
            st.state=STATE_FLAT;
            st.ResetSetup();
            r.reason="Opposite breakout invalidation";
            return r;
           }

         st.setup_bars_since_fire++;
         if(st.setup_bars_since_fire>m_cfg.setup_expiration_bars)
           {
            st.state=STATE_FLAT;
            st.ResetSetup();
            r.reason="Setup expired";
            return r;
           }

         bool adx_rising=true;
         if(m_cfg.adx_rising_bars>0)
           {
            adx_rising=(curr.adx>prev.adx);
           }
         bool adx_ok=(curr.adx>=m_cfg.adx_threshold && adx_rising);
         if(!adx_ok)
           {
            st.state=STATE_ADX_CONFIRM;
            return r;
           }

         st.state=STATE_IN_TRADE;
         r.direction=st.direction;
         r.should_enter=true;
         r.reason="ADX confirmed entry";
         return r;
        }

      return r;
     }
  };

#endif
