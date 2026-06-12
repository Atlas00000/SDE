//+------------------------------------------------------------------+
//| CircuitBreakers.mqh — P2D failure containment                    |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_CIRCUITBREAKERS_MQH__
#define __ORBVWAP_CIRCUITBREAKERS_MQH__

#include "Inputs.mqh"
#include "Constants.mqh"
#include "SessionUtils.mqh"
#include "Logger.mqh"

class CCircuitBreakers
  {
   datetime m_day_start_broker;
   double   m_day_start_equity;
   double   m_day_peak_equity;
   int      m_consec_losses;
   datetime m_pause_until;
   ulong    m_last_deal_ticket;

   static bool UsesAnyBreaker()
     {
      return(InpDailyLossPct > 0.0 ||
             InpConsecLossMax > 0 ||
             InpEqTrailPct > 0.0);
     }

   static double DealNetProfit(const ulong deal_ticket)
     {
      return(HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) +
             HistoryDealGetDouble(deal_ticket, DEAL_SWAP) +
             HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION));
     }

   void ResetDayState()
     {
      m_day_start_broker  = CSessionUtils::DayStartBroker(TimeCurrent());
      m_day_start_equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      m_day_peak_equity   = m_day_start_equity;
      m_consec_losses     = 0;
      m_pause_until       = 0;
     }

   void SyncDay()
     {
      const datetime day_start = CSessionUtils::DayStartBroker(TimeCurrent());
      if(m_day_start_broker <= 0 || day_start != m_day_start_broker)
         ResetDayState();
     }

   void UpdateDayPeak()
     {
      if(InpEqTrailPct <= 0.0)
         return;

      const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity > m_day_peak_equity)
         m_day_peak_equity = equity;
     }

   void ProcessClosedDeals(const string symbol, const long magic)
     {
      if(InpConsecLossMax <= 0)
         return;

      const datetime from = (m_day_start_broker > 0) ? m_day_start_broker : (TimeCurrent() - 86400 * 30);
      if(!HistorySelect(from, TimeCurrent()))
         return;

      const int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         const ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0 || ticket <= m_last_deal_ticket)
            continue;

         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol)
            continue;
         if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
            continue;

         const ENUM_DEAL_ENTRY entry =
            (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(entry != DEAL_ENTRY_OUT)
            continue;

         m_last_deal_ticket = ticket;

         const double net = DealNetProfit(ticket);
         if(net < -1e-8)
           {
            m_consec_losses++;
            if(m_consec_losses >= InpConsecLossMax && InpConsecLossPauseMin > 0)
              {
               m_pause_until = TimeCurrent() + (datetime)InpConsecLossPauseMin * 60;
               m_consec_losses = 0;
               COrbVwapLogger::Warn(StringFormat("Consec loss pause until %s (after %d losses)",
                                                 TimeToString(m_pause_until, TIME_MINUTES),
                                                 InpConsecLossMax));
              }
           }
         else if(net > 1e-8)
            m_consec_losses = 0;
        }
     }

public:
   CCircuitBreakers()
     {
      m_day_start_broker  = 0;
      m_day_start_equity  = 0.0;
      m_day_peak_equity   = 0.0;
      m_consec_losses     = 0;
      m_pause_until       = 0;
      m_last_deal_ticket  = 0;
     }

   void Init()
     {
      ResetDayState();
      m_last_deal_ticket = 0;
     }

   void Update(const string symbol, const long magic)
     {
      if(!UsesAnyBreaker())
         return;

      SyncDay();
      UpdateDayPeak();
      ProcessClosedDeals(symbol, magic);
     }

   bool AllowEntry(string &reject_code, string &detail) const
     {
      reject_code = "";
      detail      = "";

      if(!UsesAnyBreaker())
         return(true);

      if(InpConsecLossMax > 0 && m_pause_until > 0)
        {
         const datetime now = TimeCurrent();
         if(now < m_pause_until)
           {
            reject_code = ORBVWAP_REJECT_CONSEC_LOSS;
            detail      = StringFormat("until=%s", TimeToString(m_pause_until, TIME_MINUTES));
            return(false);
           }
        }

      if(m_day_start_equity > 0.0)
        {
         const double equity = AccountInfoDouble(ACCOUNT_EQUITY);

         if(InpDailyLossPct > 0.0)
           {
            const double day_loss_pct =
               (m_day_start_equity - equity) / m_day_start_equity * 100.0;
            if(day_loss_pct >= InpDailyLossPct)
              {
               reject_code = ORBVWAP_REJECT_DAILY_LOSS;
               detail      = StringFormat("loss=%.2f%% limit=%.2f%%",
                                          day_loss_pct, InpDailyLossPct);
               return(false);
              }
           }

         if(InpEqTrailPct > 0.0 && m_day_peak_equity > 0.0)
           {
            const double trail_pct =
               (m_day_peak_equity - equity) / m_day_peak_equity * 100.0;
            if(trail_pct >= InpEqTrailPct)
              {
               reject_code = ORBVWAP_REJECT_EQ_TRAIL;
               detail      = StringFormat("drop=%.2f%% limit=%.2f%% peak=%.2f",
                                          trail_pct, InpEqTrailPct, m_day_peak_equity);
               return(false);
              }
           }
        }

      return(true);
     }
  };

#endif // __ORBVWAP_CIRCUITBREAKERS_MQH__
