//+------------------------------------------------------------------+
//| AiInferenceClient.mqh — INF-8: AI-1 HTTP inference (live chart)  |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AIINFERENCECLIENT_MQH__
#define __ORBVWAP_AIINFERENCECLIENT_MQH__

#include "FilePath.mqh"
#include "Logger.mqh"
#include "Ai1Sidecar.mqh"
#include "AiFeatures.mqh"

string OrbInferenceNormalizeBaseUrl(const string baseUrl)
  {
   string url = OrbVwapNormalizeInputPath(baseUrl);
   StringTrimLeft(url);
   StringTrimRight(url);
   while(StringLen(url) > 0 && StringGetCharacter(url, StringLen(url) - 1) == '/')
      url = StringSubstr(url, 0, StringLen(url) - 1);
   return(url);
  }

bool OrbInferenceParseJsonDouble(const string json, const string key, double &value)
  {
   const string needle = "\"" + key + "\":";
   const int pos = StringFind(json, needle);
   if(pos < 0)
      return(false);
   const string tail = StringSubstr(json, pos + StringLen(needle));
   value = StringToDouble(tail);
   return(true);
  }

bool OrbInferenceHttpPost(const string url,
                          const string body,
                          const int timeoutMs,
                          string &response,
                          int &httpStatus)
  {
   response = "";
   httpStatus = 0;

   char post[];
   char result[];
   string resultHeaders = "";
   const string reqHeaders = "Content-Type: application/json\r\n";

   if(StringLen(body) <= 0)
      return(false);

   const int n = StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
   if(n <= 0)
      return(false);
   ArrayResize(post, n - 1);

   ResetLastError();
   httpStatus = WebRequest("POST",
                           url,
                           reqHeaders,
                           MathMax(timeoutMs, 1),
                           post,
                           result,
                           resultHeaders);
   if(httpStatus == -1)
     {
      const int err = GetLastError();
      if(err == 4014)
         COrbVwapLogger::Warn("WebRequest URL not allowed — add "
                              + OrbInferenceNormalizeBaseUrl(InpAiInferenceBaseUrl)
                              + " in MT5 Expert Advisors settings");
      else
         COrbVwapLogger::Warn("WebRequest failed err=" + IntegerToString(err));
      return(false);
     }

   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return(httpStatus == 200);
  }

string OrbInferenceBuildAi1JsonBody(const double &feats[])
  {
   if(ArraySize(feats) != ORBVWAP_AI1_N_FEATURES)
      return("");

   return(StringFormat(
             "{\"range_width_atr\":%.6f,\"vol_ratio\":%.6f,\"vwap_dist_atr\":%.6f,"
             "\"spread_pct_range\":%.6f,\"min_rr\":%.6f,\"hour_gmt\":%.6f,"
             "\"weekday\":%.6f,\"ny_min_since_open\":%.6f,\"session_ny\":%.6f,"
             "\"direction_sell\":%.6f}",
             feats[0],
             feats[1],
             feats[2],
             feats[3],
             feats[4],
             feats[5],
             feats[6],
             feats[7],
             feats[8],
             feats[9]));
  }

class CAiInferenceClient
  {
public:
   static bool RequestAi1Score(const double &feats[], double &ai1Score)
     {
      ai1Score = ORBVWAP_AI1_FAILOPEN_SCORE;

      const string body = OrbInferenceBuildAi1JsonBody(feats);
      if(body == "")
        {
         COrbVwapLogger::Warn("AI1 inference feature build fail-open ai1_score=0.5");
         return(false);
        }

      const string base = OrbInferenceNormalizeBaseUrl(InpAiInferenceBaseUrl);
      const string url = base + "/score/ai1";

      string response = "";
      int httpStatus = 0;
      if(!OrbInferenceHttpPost(url, body, InpAiInferenceTimeoutMs, response, httpStatus))
        {
         COrbVwapLogger::Warn("AI1 inference HTTP fail-open ai1_score=0.5");
         return(false);
        }

      double score = ORBVWAP_AI1_FAILOPEN_SCORE;
      if(!OrbInferenceParseJsonDouble(response, "ai1_score", score))
        {
         COrbVwapLogger::Warn("AI1 inference parse fail-open ai1_score=0.5");
         return(false);
        }

      ai1Score = MathMax(0.0, MathMin(score, 1.0));
      return(true);
     }
  };

#endif // __ORBVWAP_AIINFERENCECLIENT_MQH__
