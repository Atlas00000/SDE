//+------------------------------------------------------------------+
//| SessionVwap.mqh                                                  |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_SESSIONVWAP_MQH__
#define __ORBVWAP_SESSIONVWAP_MQH__

#include "Types.mqh"

class CSessionVwap
  {
   double   m_num;
   double   m_den;
   datetime m_session_open_broker;
   datetime m_last_bar_time;

   void Recalc(const string         symbol,
               const ENUM_TIMEFRAMES tf,
               const datetime       session_open_broker)
     {
      m_num = 0.0;
      m_den = 0.0;
      m_session_open_broker = session_open_broker;
      m_last_bar_time       = 0;

      const int bars = iBars(symbol, tf);
      if(bars < 2)
         return;

      const int max_bars = MathMin(bars - 1, 5000);
      for(int i = 1; i <= max_bars; i++)
        {
         const datetime bar_time = iTime(symbol, tf, i);
         if(bar_time < session_open_broker)
            break;

         const double high  = iHigh(symbol, tf, i);
         const double low   = iLow(symbol, tf, i);
         const double close = iClose(symbol, tf, i);
         const long   vol   = iTickVolume(symbol, tf, i);
         const double tp    = (high + low + close) / 3.0;

         m_num += tp * (double)vol;
         m_den += (double)vol;
         if(i == 1)
            m_last_bar_time = bar_time;
        }
     }

public:
   CSessionVwap()
     {
      m_num                 = 0.0;
      m_den                 = 0.0;
      m_session_open_broker = 0;
      m_last_bar_time       = 0;
     }

   void Update(const SSessionContext &session,
               const string           symbol,
               const ENUM_TIMEFRAMES  tf)
     {
      if(!session.active)
         return;

      const datetime bar_time = iTime(symbol, tf, 1);
      if(bar_time <= 0)
         return;

      if(session.session_open_broker != m_session_open_broker ||
         bar_time < session.session_open_broker)
        {
         Recalc(symbol, tf, session.session_open_broker);
         return;
        }

      if(bar_time == m_last_bar_time)
         return;

      Recalc(symbol, tf, session.session_open_broker);
     }

   bool Value(double &vwap_out) const
     {
      vwap_out = 0.0;
      if(m_den <= 0.0)
         return(false);
      vwap_out = m_num / m_den;
      return(vwap_out > 0.0);
     }
  };

#endif // __ORBVWAP_SESSIONVWAP_MQH__
