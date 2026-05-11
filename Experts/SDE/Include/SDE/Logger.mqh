#ifndef __SDE_LOGGER_MQH__
#define __SDE_LOGGER_MQH__

#include "Config.mqh"

class SdeLogger
  {
private:
   SdeLogLevel m_level;

public:
   void SetLevel(SdeLogLevel level) { m_level=level; }

   void Log(SdeLogLevel level,const string message)
     {
      if(level>m_level)
         return;
      string tag="INFO";
      if(level==LOG_ERROR) tag="ERROR";
      else if(level==LOG_WARN) tag="WARN";
      else if(level==LOG_DEBUG) tag="DEBUG";
      PrintFormat("[SDE][%s] %s",tag,message);
     }
  };

#endif
