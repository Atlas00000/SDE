//+------------------------------------------------------------------+
//| VEM_State.mqh                                                    |
//+------------------------------------------------------------------+
#ifndef VEM_STATE_MQH
#define VEM_STATE_MQH

#include <VEM/VEM_Config.mqh>

static datetime g_vem_last_entry_bar_time = 0;

inline void VEM_State_OnInit()
  {
   g_vem_last_entry_bar_time = 0;
  }

inline datetime VEM_State_LastEntryBarTime()
  {
   return g_vem_last_entry_bar_time;
  }

inline void VEM_State_SetLastEntryBarTime(const datetime t)
  {
   g_vem_last_entry_bar_time = t;
  }

inline int VEM_State_CountPositions(const string sym, const long magic, const int position_type_filter)
  {
   int cnt = 0;
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(position_type_filter >= 0 && (int)PositionGetInteger(POSITION_TYPE) != position_type_filter)
         continue;
      cnt++;
     }
   return cnt;
  }

inline bool VEM_State_HasBuy(const string sym, const long magic)
  {
   return VEM_State_CountPositions(sym, magic, POSITION_TYPE_BUY) > 0;
  }

inline bool VEM_State_HasSell(const string sym, const long magic)
  {
   return VEM_State_CountPositions(sym, magic, POSITION_TYPE_SELL) > 0;
  }

inline bool VEM_State_CooldownOk(const string sym, const ENUM_TIMEFRAMES tf,
                                 const int signal_shift, const int cooldown_bars)
  {
   if(cooldown_bars <= 0)
      return true;
   if(g_vem_last_entry_bar_time == 0)
      return true;

   const int shift_last = iBarShift(sym, tf, g_vem_last_entry_bar_time, true);
   if(shift_last < 0)
      return true;

   const int delta = shift_last - signal_shift;
   return (delta >= cooldown_bars);
  }

#endif // VEM_STATE_MQH
