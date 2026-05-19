//+------------------------------------------------------------------+
//| VEM_AI.mqh — v0.1 logistic bad_trade scorer (AI-4 shadow)        |
//+------------------------------------------------------------------+
#ifndef VEM_AI_MQH
#define VEM_AI_MQH

#include <VEM/VEM_Config.mqh>
#include <VEM/VEM_Indicators.mqh>

// Auto-generated weights (scripts/export_ai_model_mqh.py)
#include <VEM/VEM_AI_Model.inc.mqh>

inline double VEM_AI_Sigmoid(const double z)
  {
   if(z > 30.0)
      return 1.0;
   if(z < -30.0)
      return 0.0;
   return 1.0 / (1.0 + MathExp(-z));
  }

inline double VEM_AI_StdScale(const double x, const double mean, const double scale)
  {
   if(scale <= 0.0)
      return 0.0;
   return (x - mean) / scale;
  }

inline double VEM_AI_RsiDepth(const bool is_sell, const double rsi)
  {
   if(is_sell)
      return MathMax(0.0, rsi - 75.0);
   return MathMax(0.0, 25.0 - rsi);
  }

inline double VEM_AI_BbWidthRatio(const VEMIndicatorSnap &s)
  {
   if(!s.valid || s.bb_middle <= 0.0)
      return 0.0;
   return (s.bb_upper - s.bb_lower) / s.bb_middle;
  }

inline double VEM_AI_VolRatio(const VEMIndicatorSnap &s)
  {
   if(!s.valid || s.volume_ma <= 0.0)
      return 0.0;
   return s.volume / s.volume_ma;
  }

inline int VEM_AI_SpreadPts(const string sym)
  {
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(pt <= 0.0)
      return 0;
   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   return (int)MathRound((ask - bid) / pt);
  }

inline double VEM_AI_ScoreBadTrade(const string sym, const VEMIndicatorSnap &entry_s,
                                   const bool is_sell)
  {
   if(!entry_s.valid)
      return 0.0;

   MqlDateTime dt;
   TimeToStruct(entry_s.bar_time, dt);

   const double rsi = entry_s.rsi;
   const double bbw = VEM_AI_BbWidthRatio(entry_s);
   const double volr = VEM_AI_VolRatio(entry_s);
   const double spr = (double)VEM_AI_SpreadPts(sym);
   const double hour = (double)dt.hour;
   const double dow = (double)dt.day_of_week;
   const double side_s = is_sell ? 1.0 : 0.0;
   const double depth = VEM_AI_RsiDepth(is_sell, rsi);

   double z = VEM_AI_INTERCEPT_V1;
   z += VEM_AI_COEF_RSI * VEM_AI_StdScale(rsi, VEM_AI_MEAN_RSI, VEM_AI_SCALE_RSI);
   z += VEM_AI_COEF_BB_WIDTH_RATIO * VEM_AI_StdScale(bbw, VEM_AI_MEAN_BB_WIDTH_RATIO, VEM_AI_SCALE_BB_WIDTH_RATIO);
   z += VEM_AI_COEF_VOL_RATIO * VEM_AI_StdScale(volr, VEM_AI_MEAN_VOL_RATIO, VEM_AI_SCALE_VOL_RATIO);
   z += VEM_AI_COEF_SPREAD_PTS * VEM_AI_StdScale(spr, VEM_AI_MEAN_SPREAD_PTS, VEM_AI_SCALE_SPREAD_PTS);
   z += VEM_AI_COEF_ENTRY_HOUR * VEM_AI_StdScale(hour, VEM_AI_MEAN_ENTRY_HOUR, VEM_AI_SCALE_ENTRY_HOUR);
   z += VEM_AI_COEF_ENTRY_DOW * VEM_AI_StdScale(dow, VEM_AI_MEAN_ENTRY_DOW, VEM_AI_SCALE_ENTRY_DOW);
   z += VEM_AI_COEF_SIDE_SELL * VEM_AI_StdScale(side_s, VEM_AI_MEAN_SIDE_SELL, VEM_AI_SCALE_SIDE_SELL);
   z += VEM_AI_COEF_RSI_DEPTH * VEM_AI_StdScale(depth, VEM_AI_MEAN_RSI_DEPTH, VEM_AI_SCALE_RSI_DEPTH);

   return VEM_AI_Sigmoid(z);
  }

inline bool VEM_AI_WouldSkip(const double score)
  {
   const double thr = inp_ai_skip_prob_threshold > 0.0
                      ? inp_ai_skip_prob_threshold
                      : VEM_AI_SKIP_THRESH_DEFAULT;
   return score >= thr;
  }

#endif // VEM_AI_MQH
