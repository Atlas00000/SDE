#ifndef SESSION_MQH
#define SESSION_MQH

input bool UseSessionFilter        = true;
input int  LondonSessionStartHour  = 8;
input int  LondonSessionEndHour    = 12; // inclusive
input int  NYSessionStartHour      = 13;
input int  NYSessionEndHour        = 17; // inclusive

bool SessionFilter()
{
   if(!UseSessionFilter)
      return true;

   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   const int h = t.hour;

   const bool london = (h >= LondonSessionStartHour && h <= LondonSessionEndHour);
   const bool ny     = (h >= NYSessionStartHour && h <= NYSessionEndHour);

   return (london || ny);
}

#endif
