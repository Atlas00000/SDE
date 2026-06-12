//+------------------------------------------------------------------+
//| SessionUtils.mqh                                                 |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_SESSIONUTILS_MQH__
#define __ORBVWAP_SESSIONUTILS_MQH__

#include "Inputs.mqh"
#include "Types.mqh"

class CSessionUtils
  {
   static datetime GmtDayStart(const datetime gmt_time)
     {
      MqlDateTime dt;
      TimeToStruct(gmt_time, dt);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      return(StructToTime(dt));
     }

   static datetime BrokerToGmt(const datetime broker_time)
     {
      return(broker_time - (datetime)InpGmtOffsetHours * 3600);
     }

   static datetime GmtToBroker(const datetime gmt_time)
     {
      return(gmt_time + (datetime)InpGmtOffsetHours * 3600);
     }

   static bool HourInWindow(const int hour, const int start_hour, const int end_hour)
     {
      if(start_hour == end_hour)
         return(false);
      if(start_hour < end_hour)
         return(hour >= start_hour && hour < end_hour);
      return(hour >= start_hour || hour < end_hour);
     }

   static bool ResolveSessionAtGmt(const datetime gmt_time,
                                   ENUM_ORBVWAP_SESSION &session_out,
                                   datetime             &open_gmt_out,
                                   datetime             &end_gmt_out)
     {
      session_out  = ORBVWAP_SESSION_NONE;
      open_gmt_out = 0;
      end_gmt_out  = 0;

      MqlDateTime dt;
      TimeToStruct(gmt_time, dt);
      const datetime day_start = GmtDayStart(gmt_time);

      const bool london_allowed = (InpActiveSession == ORBVWAP_ACTIVE_LONDON ||
                                   InpActiveSession == ORBVWAP_ACTIVE_BOTH);
      const bool ny_allowed = (InpActiveSession == ORBVWAP_ACTIVE_NY ||
                               InpActiveSession == ORBVWAP_ACTIVE_BOTH);

      if(london_allowed &&
         HourInWindow(dt.hour, InpLondonStartHour, InpLondonEndHour))
        {
         session_out  = ORBVWAP_SESSION_LONDON;
         open_gmt_out = day_start + (datetime)InpLondonStartHour * 3600;
         end_gmt_out  = day_start + (datetime)InpLondonEndHour * 3600;
         return(true);
        }

      if(ny_allowed &&
         HourInWindow(dt.hour, InpNyStartHour, InpNyEndHour))
        {
         session_out  = ORBVWAP_SESSION_NY;
         open_gmt_out = day_start + (datetime)InpNyStartHour * 3600;
         end_gmt_out  = day_start + (datetime)InpNyEndHour * 3600;
         return(true);
        }

      return(false);
     }

public:
   static datetime BarTimeToGmt(const datetime broker_bar_time)
     {
      return(BrokerToGmt(broker_bar_time));
     }

   static datetime DayStartBroker(const datetime broker_time)
     {
      return(GmtToBroker(GmtDayStart(BrokerToGmt(broker_time))));
     }

   static bool ResolveSession(const datetime broker_bar_time, SSessionContext &ctx)
     {
      ctx.Clear();
      if(broker_bar_time <= 0)
         return(false);

      const datetime gmt_time = BrokerToGmt(broker_bar_time);
      datetime open_gmt = 0;
      datetime end_gmt  = 0;
      ENUM_ORBVWAP_SESSION session = ORBVWAP_SESSION_NONE;

      if(!ResolveSessionAtGmt(gmt_time, session, open_gmt, end_gmt))
         return(false);

      ctx.active              = true;
      ctx.session             = session;
      ctx.session_open_gmt    = open_gmt;
      ctx.session_end_gmt     = end_gmt;
      ctx.session_open_broker = GmtToBroker(open_gmt);
      return(true);
     }

   static bool ResolveCurrentSession(SSessionContext &ctx)
     {
      return(ResolveSession(TimeCurrent(), ctx));
     }

   static int GmtHour(const datetime broker_time)
     {
      MqlDateTime dt;
      TimeToStruct(BrokerToGmt(broker_time), dt);
      return(dt.hour);
     }

   static bool IsEntryTimeAllowed(const datetime broker_bar_time)
     {
      if(InpNoEntryAfterHour <= 0)
         return(true);
      if(broker_bar_time <= 0)
         return(false);
      return(GmtHour(broker_bar_time) < InpNoEntryAfterHour);
     }

   static bool IsWeekdayAllowed(const datetime broker_bar_time)
     {
      if(InpSkipWeekdays == 0)
         return(true);
      if(broker_bar_time <= 0)
         return(false);

      MqlDateTime dt;
      TimeToStruct(BrokerToGmt(broker_bar_time), dt);
      const int day_mask = 1 << dt.day_of_week;
      return((InpSkipWeekdays & day_mask) == 0);
     }

   static bool IsNyEntryDelaySatisfied(const datetime      broker_bar_time,
                                       const SSessionContext &session)
     {
      if(InpNyEntryDelayMin <= 0)
         return(true);
      if(!session.active || session.session != ORBVWAP_SESSION_NY)
         return(true);
      if(broker_bar_time <= 0 || session.session_open_gmt <= 0)
         return(false);

      const datetime gmt_time = BrokerToGmt(broker_bar_time);
      const int elapsed_min = (int)((gmt_time - session.session_open_gmt) / 60);
      return(elapsed_min >= InpNyEntryDelayMin);
     }

   static bool IsLondonEntryDelaySatisfied(const datetime      broker_bar_time,
                                           const SSessionContext &session)
     {
      if(InpLondonEntryDelayMin <= 0)
         return(true);
      if(!session.active || session.session != ORBVWAP_SESSION_LONDON)
         return(true);
      if(broker_bar_time <= 0 || session.session_open_gmt <= 0)
         return(false);

      const datetime gmt_time = BrokerToGmt(broker_bar_time);
      const int elapsed_min = (int)((gmt_time - session.session_open_gmt) / 60);
      return(elapsed_min >= InpLondonEntryDelayMin);
     }
  };

#endif // __ORBVWAP_SESSIONUTILS_MQH__
