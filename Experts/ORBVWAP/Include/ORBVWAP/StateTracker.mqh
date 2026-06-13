//+------------------------------------------------------------------+
//| StateTracker.mqh                                                 |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_STATETRACKER_MQH__
#define __ORBVWAP_STATETRACKER_MQH__

#include "Inputs.mqh"

class CStateTracker
  {
   datetime m_last_entry_time;
   datetime m_session_open_broker;
   bool     m_breakout_consumed;
   double   m_prior_session_loss;

public:
   CStateTracker()
     {
      m_last_entry_time      = 0;
      m_session_open_broker  = 0;
      m_breakout_consumed    = false;
      m_prior_session_loss   = 0.0;
     }

   datetime LastEntryTime() const { return(m_last_entry_time); }

   double PriorSessionLoss() const { return(m_prior_session_loss); }

   void RecordSessionOutcome(const double net_profit)
     {
      m_prior_session_loss = (net_profit > 0.0) ? 0.0 : 1.0;
     }

   void SyncSession(const datetime session_open_broker)
     {
      if(session_open_broker <= 0)
         return;
      if(session_open_broker == m_session_open_broker)
         return;
      m_session_open_broker = session_open_broker;
      m_breakout_consumed   = false;
     }

   bool IsBreakoutConsumed() const { return(m_breakout_consumed); }

   void MarkBreakoutConsumed()
     {
      m_breakout_consumed = true;
     }

   void RecordEntry()
     {
      m_last_entry_time = TimeCurrent();
     }

   int CountOpenPositions(const string symbol, const long magic) const
     {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         count++;
        }
      return(count);
     }
  };

#endif // __ORBVWAP_STATETRACKER_MQH__
