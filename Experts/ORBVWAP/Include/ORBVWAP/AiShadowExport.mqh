//+------------------------------------------------------------------+
//| AiShadowExport.mqh — INF-1 structured AI shadow CSV               |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AISHADOWEXPORT_MQH__
#define __ORBVWAP_AISHADOWEXPORT_MQH__

#include "Inputs.mqh"
#include "Constants.mqh"
#include "Types.mqh"
#include "SessionUtils.mqh"

class CAiShadowExport
  {
   static string SessionTag(const SSessionContext &session)
     {
      if(session.session == ORBVWAP_SESSION_LONDON)
         return("LONDON");
      if(session.session == ORBVWAP_SESSION_NY)
         return("NY");
      return("NONE");
     }

   static string SessKey(const datetime bar_gmt, const SSessionContext &session)
     {
      return(StringFormat("%s_%s", TimeToString(bar_gmt, TIME_DATE), SessionTag(session)));
     }

   static void WriteLine(const string line)
     {
      const int handle = FileOpen(ORBVWAP_SHADOW_FILE,
                                  FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
      if(handle == INVALID_HANDLE)
         return;

      const bool is_new = (FileSize(handle) == 0);
      FileSeek(handle, 0, SEEK_END);
      if(is_new)
        {
         FileWriteString(handle,
                         "bar_time_gmt,sess_key,decision_id,ai1_score,ai1_pass,ai2_mult,"
                         "ai3_allow,ai4_would_scratch,mode_ai1,mode_ai2,mode_ai3,mode_ai4,"
                         "ea_version,bundle_id\r\n");
        }
      FileWriteString(handle, line + "\r\n");
      FileClose(handle);
     }

public:
   static void LogEvaluation(const datetime               bar_gmt,
                             const SSessionContext         &session,
                             const int                     decision_id,
                             const double                  ai1_score,
                             const int                     ai1_pass,
                             const double                  ai2_mult,
                             const int                     ai3_allow,
                             const int                     ai4_would_scratch)
     {
      if(!InpEnableAiShadowLog)
         return;

      const string line = StringFormat(
         "%s,%s,%d,%.6f,%d,%.4f,%d,%d,%d,%d,%d,%d,%s,%s",
         TimeToString(bar_gmt, TIME_DATE | TIME_SECONDS),
         SessKey(bar_gmt, session),
         decision_id,
         ai1_score,
         ai1_pass,
         ai2_mult,
         ai3_allow,
         ai4_would_scratch,
         (int)InpAiGateMode,
         (int)InpAiSizeMode,
         (int)InpAiRegimeMode,
         (int)InpAiExitMode,
         ORBVWAP_EA_VERSION,
         ORBVWAP_BUNDLE_ID);

      WriteLine(line);
     }
  };

#endif // __ORBVWAP_AISHADOWEXPORT_MQH__
