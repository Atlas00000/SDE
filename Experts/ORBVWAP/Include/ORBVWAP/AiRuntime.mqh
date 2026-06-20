//+------------------------------------------------------------------+
//| AiRuntime.mqh — INF-8: route AI-1 scoring (mqh / sidecar / HTTP)|
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AIRUNTIME_MQH__
#define __ORBVWAP_AIRUNTIME_MQH__

#include "AiScorer.mqh"
#include "Ai1Sidecar.mqh"
#include "AiInferenceClient.mqh"

class CAiRuntime
  {
   static double ScoreCompiled(const string               symbol,
                               const SSessionContext       &session,
                               const ENUM_ORBVWAP_SIGNAL    signal,
                               COpeningRange               &opening_range,
                               CSessionVwap                &session_vwap,
                               CIndicatorManager           &indicators,
                               const STradeSetup           &setup)
     {
      return(CAiScorer::Score(symbol, session, signal, opening_range, session_vwap,
                              indicators, setup));
     }

   static bool FillFeatures(const string               symbol,
                            const SSessionContext       &session,
                            const ENUM_ORBVWAP_SIGNAL    signal,
                            COpeningRange               &opening_range,
                            CSessionVwap                &session_vwap,
                            CIndicatorManager           &indicators,
                            const STradeSetup           &setup,
                            double                      &feats[])
     {
      return(CAiFeatures::FillAi1(symbol, session, signal, opening_range, session_vwap,
                                  indicators, setup.risk_reward, feats));
     }

public:
   static bool InitOnStart()
     {
      if(InpAi1SidecarEnable)
        {
         if(!CAi1Sidecar::Init(InpAi1SidecarFile))
            COrbVwapLogger::Warn("AI1 sidecar init failed — will fail-open until sidecar ready");
        }
      return(true);
     }

   static bool UsesExternalRuntime()
     {
      if(MQLInfoInteger(MQL_TESTER))
         return(InpAi1SidecarEnable);
      return(InpAiInferenceEnable || InpAi1SidecarEnable);
     }

   static double ScoreAi1(const string               symbol,
                          const SSessionContext       &session,
                          const ENUM_ORBVWAP_SIGNAL    signal,
                          COpeningRange               &opening_range,
                          CSessionVwap                &session_vwap,
                          CIndicatorManager           &indicators,
                          const STradeSetup           &setup)
     {
      if(MQLInfoInteger(MQL_TESTER))
        {
         if(InpAi1SidecarEnable)
           {
            double feats[];
            if(!FillFeatures(symbol, session, signal, opening_range, session_vwap, indicators,
                             setup, feats))
               return(ORBVWAP_AI1_FAILOPEN_SCORE);

            double score = ORBVWAP_AI1_FAILOPEN_SCORE;
            if(CAi1Sidecar::RequestScore(InpAi1SidecarFile, InpAi1SidecarTimeoutMs, feats, score))
               return(score);
            return(ORBVWAP_AI1_FAILOPEN_SCORE);
           }
         return(ScoreCompiled(symbol, session, signal, opening_range, session_vwap, indicators,
                              setup));
        }

      if(InpAiInferenceEnable)
        {
         double feats[];
         if(!FillFeatures(symbol, session, signal, opening_range, session_vwap, indicators,
                          setup, feats))
            return(ORBVWAP_AI1_FAILOPEN_SCORE);

         double score = ORBVWAP_AI1_FAILOPEN_SCORE;
         if(CAiInferenceClient::RequestAi1Score(feats, score))
            return(score);
         return(ORBVWAP_AI1_FAILOPEN_SCORE);
        }

      if(InpAi1SidecarEnable)
        {
         double feats[];
         if(!FillFeatures(symbol, session, signal, opening_range, session_vwap, indicators,
                          setup, feats))
            return(ORBVWAP_AI1_FAILOPEN_SCORE);

         double score = ORBVWAP_AI1_FAILOPEN_SCORE;
         if(CAi1Sidecar::RequestScore(InpAi1SidecarFile, InpAi1SidecarTimeoutMs, feats, score))
            return(score);
         return(ORBVWAP_AI1_FAILOPEN_SCORE);
        }

      return(ScoreCompiled(symbol, session, signal, opening_range, session_vwap, indicators,
                           setup));
     }
  };

#endif // __ORBVWAP_AIRUNTIME_MQH__
