//+------------------------------------------------------------------+
//| VEM_Log.mqh                                                      |
//+------------------------------------------------------------------+
#ifndef VEM_LOG_MQH
#define VEM_LOG_MQH

#include <VEM/VEM_Config.mqh>

#define VEM_LOG_PREFIX "VEM "

inline void VEM_Log_Info(const string msg)
  {
   Print(VEM_LOG_PREFIX, msg);
  }

inline void VEM_Log_Verbose(const string msg)
  {
   if(inp_log_verbose)
      Print(VEM_LOG_PREFIX, msg);
  }

inline void VEM_Log_TradeFail(const string ctx, const uint retcode)
  {
   PrintFormat("%sTrade fail [%s] retcode=%u", VEM_LOG_PREFIX, ctx, retcode);
  }

#endif // VEM_LOG_MQH
