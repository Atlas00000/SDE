//+------------------------------------------------------------------+
//| AiInferenceClient.mqh — INF-8: full AI stack HTTP (live chart)   |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AIINFERENCECLIENT_MQH__
#define __ORBVWAP_AIINFERENCECLIENT_MQH__

#include "FilePath.mqh"
#include "Logger.mqh"
#include "Ai1Sidecar.mqh"
#include "AiFeatures.mqh"
#include "AiExit.mqh"
#include "AiSizer.mqh"

int    g_orb_ai4_stall_minutes     = ORBVWAP_AI4_STALL_MINUTES;
double g_orb_ai4_stall_mfe_frac    = ORBVWAP_AI4_STALL_MFE_FRAC;
bool   g_orb_http_config_ready     = false;

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

bool OrbInferenceParseJsonBool(const string json, const string key, bool &value)
  {
   const string needle = "\"" + key + "\":";
   const int pos = StringFind(json, needle);
   if(pos < 0)
      return(false);
   const string tail = StringSubstr(json, pos + StringLen(needle));
   if(StringFind(tail, "true") == 0)
     {
      value = true;
      return(true);
     }
   if(StringFind(tail, "false") == 0)
     {
      value = false;
      return(true);
     }
   const double n = StringToDouble(tail);
   value = (n != 0.0);
   return(true);
  }

bool OrbInferenceHttpRequest(const string method,
                             const string url,
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
   string reqHeaders = "Content-Type: application/json\r\n";
   int postLen = 0;

   if(body != "")
     {
      postLen = StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
      if(postLen <= 0)
         return(false);
      ArrayResize(post, postLen - 1);
     }

   ResetLastError();
   httpStatus = WebRequest(method,
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
                              + OrbInferenceNormalizeBaseUrl(InpAiInferenceEnable
                                                             ? InpAiInferenceBaseUrl
                                                             : "")
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
   if(ArraySize(feats) != ORBVWAP_AI1_FEATURE_COUNT)
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

string OrbInferenceBuildRegimeJsonBody(const double &feats[])
  {
   if(ArraySize(feats) != ORBVWAP_AI3_FEATURE_COUNT)
      return("");

   return(StringFormat(
             "{\"range_width_atr\":%.6f,\"vol_ratio\":%.6f,\"spread_pct_range\":%.6f,"
             "\"vwap_dist_atr\":%.6f,\"weekday\":%.6f,\"session_ny\":%.6f,"
             "\"prior_session_loss\":%.6f}",
             feats[0],
             feats[1],
             feats[2],
             feats[3],
             feats[4],
             feats[5],
             feats[6]));
  }

class CAiInferenceClient
  {
   static bool ApplyAi4FromJson(const string json)
     {
      double stallMin = (double)g_orb_ai4_stall_minutes;
      double stallMfe = g_orb_ai4_stall_mfe_frac;
      bool ok = false;
      if(OrbInferenceParseJsonDouble(json, "ai4_stall_minutes", stallMin))
        {
         g_orb_ai4_stall_minutes = (int)MathMax(stallMin, 1.0);
         ok = true;
        }
      if(OrbInferenceParseJsonDouble(json, "ai4_stall_mfe_frac", stallMfe))
        {
         g_orb_ai4_stall_mfe_frac = MathMax(0.0, stallMfe);
         ok = true;
        }
      return(ok);
     }

public:
   static bool SyncConfigFromHealth()
     {
      g_orb_http_config_ready = false;
      const string base = OrbInferenceNormalizeBaseUrl(InpAiInferenceBaseUrl);
      const string url = base + "/health";

      string response = "";
      int httpStatus = 0;
      if(!OrbInferenceHttpRequest("GET", url, "", InpAiInferenceTimeoutMs, response, httpStatus))
        {
         COrbVwapLogger::Warn("AI stack health sync failed — using compiled AI-4 defaults");
         return(false);
        }

      if(!ApplyAi4FromJson(response))
        {
         COrbVwapLogger::Warn("AI stack health parse failed — using compiled AI-4 defaults");
         return(false);
        }

      g_orb_http_config_ready = true;
      COrbVwapLogger::Info(StringFormat("AI stack HTTP ready ai4_stall=%dm mfe<%.2f",
                                        g_orb_ai4_stall_minutes,
                                        g_orb_ai4_stall_mfe_frac));
      return(true);
     }

   static bool RequestRegimeAllow(const double &feats[], bool &allow)
     {
      allow = true;

      const string body = OrbInferenceBuildRegimeJsonBody(feats);
      if(body == "")
         return(false);

      const string base = OrbInferenceNormalizeBaseUrl(InpAiInferenceBaseUrl);
      const string url = base + "/score/regime";

      string response = "";
      int httpStatus = 0;
      if(!OrbInferenceHttpRequest("POST", url, body, InpAiInferenceTimeoutMs, response, httpStatus))
        {
         COrbVwapLogger::Warn("AI3 inference HTTP fail-open allow session");
         return(false);
        }

      if(!OrbInferenceParseJsonBool(response, "ai3_allow", allow))
        {
         COrbVwapLogger::Warn("AI3 inference parse fail-open allow session");
         allow = true;
         return(false);
        }

      ApplyAi4FromJson(response);
      return(true);
     }

   static bool RequestEntryScores(const double &feats[],
                                  double       &ai1Score,
                                  double       &ai2Mult)
     {
      ai1Score = ORBVWAP_AI1_FAILOPEN_SCORE;
      ai2Mult  = ORBVWAP_AI2_MULT_LOW;

      const string body = OrbInferenceBuildAi1JsonBody(feats);
      if(body == "")
         return(false);

      const string base = OrbInferenceNormalizeBaseUrl(InpAiInferenceBaseUrl);
      const string url = base + "/score/entry";

      string response = "";
      int httpStatus = 0;
      if(!OrbInferenceHttpRequest("POST", url, body, InpAiInferenceTimeoutMs, response, httpStatus))
        {
         COrbVwapLogger::Warn("AI1/2 inference HTTP fail-open score=0.5 mult=1.0");
         return(false);
        }

      double score = ORBVWAP_AI1_FAILOPEN_SCORE;
      double mult  = ORBVWAP_AI2_MULT_LOW;
      if(!OrbInferenceParseJsonDouble(response, "ai1_score", score)
         || !OrbInferenceParseJsonDouble(response, "ai2_mult", mult))
        {
         COrbVwapLogger::Warn("AI1/2 inference parse fail-open score=0.5 mult=1.0");
         return(false);
        }

      ai1Score = MathMax(0.0, MathMin(score, 1.0));
      ai2Mult  = MathMax(ORBVWAP_AI2_MULT_LOW, mult);
      ApplyAi4FromJson(response);
      return(true);
     }

   static bool RequestAi1Score(const double &feats[], double &ai1Score)
     {
      double mult = ORBVWAP_AI2_MULT_LOW;
      return(RequestEntryScores(feats, ai1Score, mult));
     }
  };

#endif // __ORBVWAP_AIINFERENCECLIENT_MQH__
