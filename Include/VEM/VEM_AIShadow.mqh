//+------------------------------------------------------------------+
//| VEM_AIShadow.mqh — AI-4 / P4-2 shadow CSV (no order impact)      |
//+------------------------------------------------------------------+
#ifndef VEM_AISHADOW_MQH
#define VEM_AISHADOW_MQH

#include <VEM/VEM_Config.mqh>
#include <VEM/VEM_Log.mqh>
#include <VEM/VEM_AI.mqh>
#include <VEM/VEM_Risk.mqh>

static int  g_vem_ai_shadow_handle = INVALID_HANDLE;
static bool g_vem_ai_shadow_header_ok = false;

inline bool VEM_AIShadow_Active()
  {
   return inp_ai_shadow_enable || inp_ai_tail_shadow_enable;
  }

inline string VEM_AIShadow_FileName(const string sym, const ENUM_TIMEFRAMES tf)
  {
   string tf_s = EnumToString(tf);
   StringReplace(tf_s, "PERIOD_", "");
   return StringFormat("VEM_ai_shadow_%s_%s.csv", sym, tf_s);
  }

inline bool VEM_AIShadow_Open(const string sym, const ENUM_TIMEFRAMES tf)
  {
   if(g_vem_ai_shadow_handle != INVALID_HANDLE)
      return true;

   const string path = VEM_AIShadow_FileName(sym, tf);
   const bool exists = FileIsExist(path, FILE_COMMON);
   g_vem_ai_shadow_handle = FileOpen(path, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(g_vem_ai_shadow_handle == INVALID_HANDLE)
     {
      VEM_Log_Info(StringFormat("AIShadow: FileOpen failed %s err=%d", path, GetLastError()));
      return false;
     }
   if(!exists || !g_vem_ai_shadow_header_ok)
     {
      FileSeek(g_vem_ai_shadow_handle, 0, SEEK_SET);
      FileWrite(g_vem_ai_shadow_handle,
                "signal_time", "side", "rsi", "bb_width_ratio", "vol_ratio",
                "spread_pts", "entry_hour", "entry_dow",
                "ai_score", "would_skip",
                "tail_score", "would_skip_tail", "would_skip_any",
                "habitat_ok", "opened", "skip_reason");
      g_vem_ai_shadow_header_ok = true;
     }
   FileSeek(g_vem_ai_shadow_handle, 0, SEEK_END);
   return true;
  }

inline void VEM_AIShadow_OnInit(const string sym, const ENUM_TIMEFRAMES tf)
  {
   if(VEM_AIShadow_Active())
      VEM_AIShadow_Open(sym, tf);
  }

inline void VEM_AIShadow_OnDeinit()
  {
   if(g_vem_ai_shadow_handle != INVALID_HANDLE)
     {
      FileClose(g_vem_ai_shadow_handle);
      g_vem_ai_shadow_handle = INVALID_HANDLE;
     }
  }

inline void VEM_AIShadow_LogAttempt(const string sym, const ENUM_TIMEFRAMES tf,
                                    const int signal_shift, const VEMIndicatorSnap &entry_s,
                                    const ENUM_ORDER_TYPE otype, const bool opened,
                                    const string &habitat_reason)
  {
   if(!VEM_AIShadow_Active() || !entry_s.valid)
      return;
   if(!VEM_AIShadow_Open(sym, tf))
      return;

   const bool is_sell = (otype == ORDER_TYPE_SELL);
   const double bad_score = VEM_AI_ScoreBadTrade(sym, entry_s, is_sell);
   const double tail_score = VEM_AI_ScoreTailLoss(sym, entry_s, is_sell);
   // Threshold flags (independent of live skip toggles — for shadow / parity)
   const int would_skip_bad = VEM_AI_WouldSkip(bad_score) ? 1 : 0;
   const int would_skip_tail = VEM_AI_WouldSkipTail(tail_score) ? 1 : 0;
   const int would_skip_any = (would_skip_bad || would_skip_tail) ? 1 : 0;
   const bool habitat_ok = (StringLen(habitat_reason) == 0);

   MqlDateTime dt;
   TimeToStruct(entry_s.bar_time, dt);

   FileWrite(g_vem_ai_shadow_handle,
             TimeToString(entry_s.bar_time, TIME_DATE | TIME_SECONDS),
             is_sell ? "sell" : "buy",
             DoubleToString(entry_s.rsi, 2),
             DoubleToString(VEM_AI_BbWidthRatio(entry_s), 6),
             DoubleToString(VEM_AI_VolRatio(entry_s), 3),
             IntegerToString(VEM_AI_SpreadPts(sym)),
             IntegerToString(dt.hour),
             IntegerToString(dt.day_of_week),
             DoubleToString(bad_score, 4),
             IntegerToString(would_skip_bad),
             DoubleToString(tail_score, 4),
             IntegerToString(would_skip_tail),
             IntegerToString(would_skip_any),
             habitat_ok ? "1" : "0",
             opened ? "1" : "0",
             habitat_reason);
   FileFlush(g_vem_ai_shadow_handle);
  }

#endif // VEM_AISHADOW_MQH
