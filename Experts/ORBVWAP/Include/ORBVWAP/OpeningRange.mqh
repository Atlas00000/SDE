//+------------------------------------------------------------------+
//| OpeningRange.mqh                                                 |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_OPENINGRANGE_MQH__
#define __ORBVWAP_OPENINGRANGE_MQH__

#include "Inputs.mqh"
#include "Types.mqh"
#include "Logger.mqh"

class COpeningRange
  {
   SOpeningRangeState m_state;

   void Reset(const datetime session_open_broker)
     {
      m_state.Clear();
      m_state.state               = ORBVWAP_RANGE_FORMING;
      m_state.session_open_broker = session_open_broker;
      m_state.high                = -DBL_MAX;
      m_state.low                 = DBL_MAX;
      m_state.bars_collected      = 0;
     }

public:
   COpeningRange()
     {
      m_state.Clear();
     }

   ENUM_ORBVWAP_RANGE_STATE RangeState() const { return(m_state.state); }

   void Update(const SSessionContext &session,
               const string         symbol,
               const ENUM_TIMEFRAMES tf)
     {
      if(!session.active)
        {
         if(m_state.state == ORBVWAP_RANGE_FORMING ||
            m_state.state == ORBVWAP_RANGE_LOCKED)
            m_state.state = ORBVWAP_RANGE_EXPIRED;
         return;
        }

      if(session.session_open_broker != m_state.session_open_broker ||
         m_state.state == ORBVWAP_RANGE_IDLE ||
         m_state.state == ORBVWAP_RANGE_EXPIRED)
        {
         Reset(session.session_open_broker);
         if(InpLogSessionState)
            COrbVwapLogger::Info("Range FORMING session_open=" +
                                 TimeToString(session.session_open_broker));
        }

      if(m_state.state == ORBVWAP_RANGE_TRADED)
         return;

      const datetime bar_time = iTime(symbol, tf, 1);
      if(bar_time <= 0 || bar_time < session.session_open_broker)
         return;

      if(m_state.state == ORBVWAP_RANGE_FORMING)
        {
         const double bar_high = iHigh(symbol, tf, 1);
         const double bar_low  = iLow(symbol, tf, 1);
         if(bar_high > m_state.high)
            m_state.high = bar_high;
         if(bar_low < m_state.low)
            m_state.low = bar_low;
         m_state.bars_collected++;

         const int elapsed_minutes = (int)((bar_time - session.session_open_broker) / 60) + 1;
         if(m_state.bars_collected >= InpRangeMinutes ||
            elapsed_minutes >= InpRangeMinutes)
           {
            m_state.state     = ORBVWAP_RANGE_LOCKED;
            m_state.lock_time = bar_time;
            m_state.width     = m_state.high - m_state.low;
            if(InpLogSessionState)
               COrbVwapLogger::Info(StringFormat("Range LOCKED high=%.5f low=%.5f width=%.5f",
                                                 m_state.high, m_state.low, m_state.width));
           }
        }
     }

   bool IsLocked() const
     {
      return(m_state.state == ORBVWAP_RANGE_LOCKED);
     }

   bool IsForming() const
     {
      return(m_state.state == ORBVWAP_RANGE_FORMING);
     }

   bool IsTraded() const
     {
      return(m_state.state == ORBVWAP_RANGE_TRADED);
     }

   void MarkTraded()
     {
      m_state.state = ORBVWAP_RANGE_TRADED;
     }

   double High() const  { return(m_state.high); }
   double Low() const   { return(m_state.low); }
   double Width() const { return(m_state.width); }
   datetime LockTime() const { return(m_state.lock_time); }

   bool IsBreakoutFresh(const string symbol,
                        const ENUM_TIMEFRAMES tf,
                        const datetime signal_bar_time) const
     {
      if(InpMaxBarsAfterLock <= 0)
         return(true);
      if(m_state.lock_time <= 0 || signal_bar_time < m_state.lock_time)
         return(false);

      const int lock_shift = iBarShift(symbol, tf, m_state.lock_time, true);
      const int signal_shift = iBarShift(symbol, tf, signal_bar_time, true);
      if(lock_shift < 0 || signal_shift < 0)
         return(false);

      const int bars_since_lock = lock_shift - signal_shift;
      return(bars_since_lock <= InpMaxBarsAfterLock);
     }
  };

#endif // __ORBVWAP_OPENINGRANGE_MQH__
