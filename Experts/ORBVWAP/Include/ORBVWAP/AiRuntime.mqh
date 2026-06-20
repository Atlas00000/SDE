//+------------------------------------------------------------------+
//| AiRuntime.mqh — INF-8: route full AI stack (mqh / sidecar / HTTP)|
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AIRUNTIME_MQH__
#define __ORBVWAP_AIRUNTIME_MQH__

#include "AiScorer.mqh"
#include "AiSizer.mqh"
#include "AiRegime.mqh"
#include "AiExit.mqh"
#include "Ai1Sidecar.mqh"
#include "AiInferenceClient.mqh"

datetime g_orb_http_entry_bar   = 0;
double   g_orb_http_ai1_score   = 0.5;
double   g_orb_http_ai2_mult    = 1.0;
bool     g_orb_http_entry_valid = false;

class CAiRuntime
  {
   static bool UseHttpStack()
     {
      return(InpAiInferenceEnable && !MQLInfoInteger(MQL_TESTER));
     }

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

   static void FillEntryFeatures(const string               symbol,
                                 const SSessionContext       &session,
                                 const ENUM_ORBVWAP_SIGNAL    signal,
                                 COpeningRange               &opening_range,
                                 CSessionVwap                &session_vwap,
                                 CIndicatorManager           &indicators,
                                 const STradeSetup           &setup,
                                 double                      &feats[])
     {
      CAiFeatures::FillAi1(symbol, session, signal, opening_range, session_vwap,
                             indicators, setup.risk_reward, feats);
     }

   static bool RefreshEntryHttp(const string               symbol,
                                const SSessionContext       &session,
                                const ENUM_ORBVWAP_SIGNAL    signal,
                                COpeningRange               &opening_range,
                                CSessionVwap                &session_vwap,
                                CIndicatorManager           &indicators,
                                const STradeSetup           &setup)
     {
      const datetime bar_time = iTime(symbol, PERIOD_CURRENT, 1);
      if(g_orb_http_entry_valid && bar_time == g_orb_http_entry_bar)
         return(true);

      double feats[];
      FillEntryFeatures(symbol, session, signal, opening_range, session_vwap, indicators,
                        setup, feats);

      g_orb_http_ai1_score = ORBVWAP_AI1_FAILOPEN_SCORE;
      g_orb_http_ai2_mult  = ORBVWAP_AI2_MULT_LOW;
      g_orb_http_entry_bar = bar_time;
      g_orb_http_entry_valid = CAiInferenceClient::RequestEntryScores(feats,
                                                                    g_orb_http_ai1_score,
                                                                    g_orb_http_ai2_mult);
      return(g_orb_http_entry_valid);
     }

public:
   static bool InitOnStart()
     {
      if(InpAi1SidecarEnable)
        {
         if(!CAi1Sidecar::Init(InpAi1SidecarFile))
            COrbVwapLogger::Warn("AI1 sidecar init failed — will fail-open until sidecar ready");
        }

      if(UseHttpStack())
        {
         if(!CAiInferenceClient::SyncConfigFromHealth())
            COrbVwapLogger::Warn("AI HTTP stack config incomplete — fail-open defaults active");
        }
      return(true);
     }

   static bool UsesExternalRuntime()
     {
      if(MQLInfoInteger(MQL_TESTER))
         return(InpAi1SidecarEnable);
      return(InpAiInferenceEnable || InpAi1SidecarEnable);
     }

   static bool RegimeAllow(const string               symbol,
                           const SSessionContext       &session,
                           COpeningRange               &opening_range,
                           CSessionVwap                &session_vwap,
                           CIndicatorManager           &indicators,
                           const double                 prior_session_loss)
     {
      if(UseHttpStack())
        {
         double feats[];
         CAiFeatures::FillRegime(symbol, session, opening_range, session_vwap, indicators,
                                 prior_session_loss, feats);
         bool allow = true;
         if(!CAiInferenceClient::RequestRegimeAllow(feats, allow))
            return(true);
         return(allow);
        }

      return(CAiRegime::AllowFromPipeline(symbol, session, opening_range, session_vwap,
                                          indicators, prior_session_loss));
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
            FillEntryFeatures(symbol, session, signal, opening_range, session_vwap, indicators,
                              setup, feats);

            double score = ORBVWAP_AI1_FAILOPEN_SCORE;
            if(CAi1Sidecar::RequestScore(InpAi1SidecarFile, InpAi1SidecarTimeoutMs, feats, score))
               return(score);
            return(ORBVWAP_AI1_FAILOPEN_SCORE);
           }
         return(ScoreCompiled(symbol, session, signal, opening_range, session_vwap, indicators,
                              setup));
        }

      if(UseHttpStack())
        {
         RefreshEntryHttp(symbol, session, signal, opening_range, session_vwap, indicators, setup);
         return(g_orb_http_ai1_score);
        }

      if(InpAi1SidecarEnable)
        {
         double feats[];
         FillEntryFeatures(symbol, session, signal, opening_range, session_vwap, indicators,
                           setup, feats);

         double score = ORBVWAP_AI1_FAILOPEN_SCORE;
         if(CAi1Sidecar::RequestScore(InpAi1SidecarFile, InpAi1SidecarTimeoutMs, feats, score))
            return(score);
         return(ORBVWAP_AI1_FAILOPEN_SCORE);
        }

      return(ScoreCompiled(symbol, session, signal, opening_range, session_vwap, indicators,
                           setup));
     }

   static double SizeMultiplier(const string               symbol,
                                const SSessionContext       &session,
                                const ENUM_ORBVWAP_SIGNAL    signal,
                                COpeningRange               &opening_range,
                                CSessionVwap                &session_vwap,
                                CIndicatorManager           &indicators,
                                const STradeSetup           &setup,
                                const double                 ai1_score)
     {
      if(UseHttpStack())
        {
         RefreshEntryHttp(symbol, session, signal, opening_range, session_vwap, indicators, setup);
         return(g_orb_http_ai2_mult);
        }

      return(CAiSizer::Multiplier(ai1_score));
     }

   static bool ShouldStallScratch(const int hold_minutes, const double mfe_frac)
     {
      if(UseHttpStack())
        {
         if(hold_minutes < g_orb_ai4_stall_minutes)
            return(false);
         return(mfe_frac < g_orb_ai4_stall_mfe_frac);
        }

      return(CAiExit::ShouldStallScratch(hold_minutes, mfe_frac));
     }

   static int StallMinutes()
     {
      if(UseHttpStack())
         return(g_orb_ai4_stall_minutes);
      return(CAiExit::StallMinutes());
     }
  };

#endif // __ORBVWAP_AIRUNTIME_MQH__
