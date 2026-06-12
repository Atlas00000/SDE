//+------------------------------------------------------------------+
//| Logger.mqh                                                       |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_LOGGER_MQH__
#define __ORBVWAP_LOGGER_MQH__

#include "Constants.mqh"
#include "Inputs.mqh"

class COrbVwapLogger
  {
   static string Timestamp()
     {
      return(TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
     }

   static void WriteFileLine(const string line)
     {
      if(!InpEnableFileJournal)
         return;

      const int handle = FileOpen(ORBVWAP_JOURNAL_FILE,
                                  FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
      if(handle == INVALID_HANDLE)
         return;

      const bool is_new = (FileSize(handle) == 0);
      FileSeek(handle, 0, SEEK_END);
      if(is_new)
         FileWriteString(handle, "timestamp,reason_code,direction,detail\r\n");
      FileWriteString(handle, line + "\r\n");
      FileClose(handle);
     }

public:
   static void Info(const string message)
     {
      Print(ORBVWAP_LOG_PREFIX, " [INFO] ", message);
     }

   static void Warn(const string message)
     {
      Print(ORBVWAP_LOG_PREFIX, " [WARN] ", message);
     }

   static void Error(const string message)
     {
      Print(ORBVWAP_LOG_PREFIX, " [ERROR] ", message);
     }

   static void Journal(const string reason_code,
                       const string detail    = "",
                       const string direction = "")
     {
      const string dir_tag = (direction == "") ? "" : direction + " ";
      const string msg = (detail == "") ? reason_code : reason_code + " " + detail;
      Warn("REJECT " + dir_tag + msg);
      WriteFileLine(Timestamp() + "," + reason_code + "," + direction + "," + detail);
     }
  };

#endif // __ORBVWAP_LOGGER_MQH__
