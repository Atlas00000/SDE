#include <Trade/Trade.mqh>
CTrade trade;

#include "core/pip.mqh"
#include "core/breakout.mqh"
#include "core/candle.mqh"
#include "filters/spread.mqh"
#include "filters/trend.mqh"
#include "filters/session.mqh"
#include "risk/risk_manager.mqh"

input double RiskPercent        = 1.0;
input double StopLossPips       = 20.0;
input double TakeProfitPips      = 50.0;
input int    BreakoutLookback   = 20;
input double BreakoutBufferPips = 2.5;
input double RetestTolerancePips = 5.0;
input int    MaxSpreadPoints    = 30;
input bool   VerboseLog         = false;
input bool   UseMomentumFilter  = false;
input bool   UseRejectionFilter = true;
input double RejectionStrength  = 0.2;
input bool   UseTimeStop        = false;
input int    TimeStopBars       = 12;
input double MinProgressR       = 0.3;
input bool   UseBreakEven       = false;
input double BreakEvenTriggerR  = 1.0;
input double BreakEvenOffsetR   = 0.1;
input bool   SkipWorstHour13    = true;
input double MaxEmaDistancePips = 45.0;

struct TradeStats
{
   ulong  ticket;
   int    hour;
   string session;
   double breakout_strength;
   double ema_distance;
   double spread;
   double range;
   bool   is_buy;
   bool   is_win;
};

// 0 = idle, 1 = wait long retest, 2 = wait short retest
int    g_pendingDir   = 0;
double g_pendingLevel = 0.0;
int    g_age          = 0;
ulong  g_manageTicket = 0;
double g_maxFavorableR = 0.0;
bool   g_summaryPrinted = false;
TradeStats g_openStats;
bool g_hasOpenStats = false;

double g_sumBreakoutWin = 0.0, g_sumBreakoutLoss = 0.0;
double g_sumEmaWin = 0.0, g_sumEmaLoss = 0.0;
int g_countWin = 0, g_countLoss = 0;
int g_hourWins[24], g_hourLosses[24];

void PrintTradeStatsSummary();
bool ResolveClosedTradeResult(const ulong ticket, bool &isWin);
void RegisterClosedTradeStats(const bool isWin);

bool IsNewBar()
{
   static datetime lastTime = 0;
   const datetime current = iTime(_Symbol, PERIOD_M5, 0);
   if(current != lastTime)
   {
      lastTime = current;
      return true;
   }
   return false;
}

int OnInit()
{
   if(!TrendIndicatorInit())
   {
      Print("VEES_EA: failed to create H1 EMA handle");
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   bool isWin = false;
   if(ResolveClosedTradeResult(g_manageTicket, isWin))
      RegisterClosedTradeStats(isWin);
   PrintTradeStatsSummary();
   TrendIndicatorDeinit();
}

void ExecuteTrade(const bool isBuy, const double lot)
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double pip = PricePerPip();

   double sl = 0.0;
   double tp = 0.0;
   bool ok = false;

   if(isBuy)
   {
      sl = bid - StopLossPips * pip;
      tp = bid + TakeProfitPips * pip;
      ok = trade.Buy(lot, _Symbol, ask, sl, tp);
      if(ok)
         Print("BUY EXECUTED lot=", lot, " SL=", sl, " TP=", tp);
      else
         Print("BUY FAILED retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
   else
   {
      sl = ask + StopLossPips * pip;
      tp = ask - TakeProfitPips * pip;
      ok = trade.Sell(lot, _Symbol, bid, sl, tp);
      if(ok)
         Print("SELL EXECUTED lot=", lot, " SL=", sl, " TP=", tp);
      else
         Print("SELL FAILED retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }

   if(ok && PositionSelect(_Symbol))
   {
      // Collect entry features for post-backtest win/loss profiling.
      const double open1  = iOpen(_Symbol, PERIOD_M5, 1);
      const double close1 = iClose(_Symbol, PERIOD_M5, 1);
      const double high1  = iHigh(_Symbol, PERIOD_M5, 1);
      const double low1   = iLow(_Symbol, PERIOD_M5, 1);
      const double range1 = high1 - low1;
      const double body1  = MathAbs(close1 - open1);

      double emaH1[1];
      double emaDistPips = 0.0;
      if(CopyBuffer(s_emaH1, 0, 1, 1, emaH1) >= 1)
         emaDistPips = MathAbs(close1 - emaH1[0]) / PricePerPip();

      MqlDateTime t;
      TimeToStruct(TimeCurrent(), t);
      string sess = "OffSession";
      if(t.hour >= LondonSessionStartHour && t.hour <= LondonSessionEndHour)
         sess = "London";
      else if(t.hour >= NYSessionStartHour && t.hour <= NYSessionEndHour)
         sess = "NY";

      g_openStats.ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      g_openStats.hour = t.hour;
      g_openStats.session = sess;
      g_openStats.breakout_strength = (range1 > 0.0 ? body1 / range1 : 0.0);
      g_openStats.ema_distance = emaDistPips;
      g_openStats.spread = (ask - bid) / _Point;
      g_openStats.range = range1 / PricePerPip();
      g_openStats.is_buy = isBuy;
      g_openStats.is_win = false;
      g_hasOpenStats = true;

      Print("TRADE_STATS ENTRY ticket=", g_openStats.ticket,
            " dir=", (isBuy ? "BUY" : "SELL"),
            " hour=", g_openStats.hour,
            " session=", g_openStats.session,
            " breakout_strength=", DoubleToString(g_openStats.breakout_strength, 4),
            " ema_distance_pips=", DoubleToString(g_openStats.ema_distance, 2),
            " spread_points=", DoubleToString(g_openStats.spread, 2),
            " range_pips=", DoubleToString(g_openStats.range, 2));
   }
}

bool HasSimpleMomentum(const int dir, const int shift)
{
   const double open  = iOpen(_Symbol, PERIOD_M5, shift);
   const double close = iClose(_Symbol, PERIOD_M5, shift);

   if(dir == 1)
      return (close > open);
   if(dir == 2)
      return (close < open);

   return false;
}

bool HasRetestRejection(const int dir, const int shift)
{
   const double open  = iOpen(_Symbol, PERIOD_M5, shift);
   const double close = iClose(_Symbol, PERIOD_M5, shift);
   const double high  = iHigh(_Symbol, PERIOD_M5, shift);
   const double low   = iLow(_Symbol, PERIOD_M5, shift);

   const double range = high - low;
   if(range <= 0.0)
      return false;

   if(dir == 1)
   {
      const double lower_wick = MathMin(open, close) - low;
      return (lower_wick >= (range * RejectionStrength));
   }

   if(dir == 2)
   {
      const double upper_wick = high - MathMax(open, close);
      return (upper_wick >= (range * RejectionStrength));
   }

   return false;
}

void ResetManageState()
{
   g_manageTicket = 0;
   g_maxFavorableR = 0.0;
}

bool ResolveClosedTradeResult(const ulong ticket, bool &isWin)
{
   if(ticket == 0)
      return false;

   const datetime now = TimeCurrent();
   if(!HistorySelect(0, now + 60))
      return false;

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID) != ticket)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      const double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                          + HistoryDealGetDouble(deal, DEAL_SWAP)
                          + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      isWin = (profit > 0.0);
      return true;
   }
   return false;
}

void RegisterClosedTradeStats(const bool isWin)
{
   if(!g_hasOpenStats)
      return;

   g_openStats.is_win = isWin;
   if(isWin)
   {
      g_countWin++;
      g_sumBreakoutWin += g_openStats.breakout_strength;
      g_sumEmaWin += g_openStats.ema_distance;
      if(g_openStats.hour >= 0 && g_openStats.hour < 24)
         g_hourWins[g_openStats.hour]++;
   }
   else
   {
      g_countLoss++;
      g_sumBreakoutLoss += g_openStats.breakout_strength;
      g_sumEmaLoss += g_openStats.ema_distance;
      if(g_openStats.hour >= 0 && g_openStats.hour < 24)
         g_hourLosses[g_openStats.hour]++;
   }

   Print("TRADE_STATS RESULT ticket=", g_openStats.ticket,
         " dir=", (g_openStats.is_buy ? "BUY" : "SELL"),
         " result=", (isWin ? "WIN" : "LOSS"),
         " hour=", g_openStats.hour,
         " session=", g_openStats.session);

   g_hasOpenStats = false;
}

void ManageOpenPosition()
{
   if(!PositionSelect(_Symbol))
   {
      bool isWin = false;
      if(ResolveClosedTradeResult(g_manageTicket, isWin))
         RegisterClosedTradeStats(isWin);
      ResetManageState();
      return;
   }

   const ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   if(ticket != g_manageTicket)
   {
      g_manageTicket = ticket;
      g_maxFavorableR = 0.0;
   }

   const ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl    = PositionGetDouble(POSITION_SL);
   const double tp    = PositionGetDouble(POSITION_TP);
   const datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   const int barsSinceOpen = iBarShift(_Symbol, PERIOD_M5, openTime, false);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   const double riskPrice = MathAbs(entry - sl);
   if(riskPrice <= 0.0)
      return;

   double favorableR = 0.0;
   if(posType == POSITION_TYPE_BUY)
      favorableR = (bid - entry) / riskPrice;
   else if(posType == POSITION_TYPE_SELL)
      favorableR = (entry - ask) / riskPrice;

   if(favorableR > g_maxFavorableR)
      g_maxFavorableR = favorableR;

   if(UseBreakEven && g_maxFavorableR >= BreakEvenTriggerR)
   {
      double newSL = sl;
      if(posType == POSITION_TYPE_BUY)
         newSL = entry + (riskPrice * BreakEvenOffsetR);
      else if(posType == POSITION_TYPE_SELL)
         newSL = entry - (riskPrice * BreakEvenOffsetR);

      const bool needsUpdate = (posType == POSITION_TYPE_BUY && (sl <= 0.0 || newSL > sl))
                            || (posType == POSITION_TYPE_SELL && (sl <= 0.0 || newSL < sl));
      if(needsUpdate)
      {
         if(!trade.PositionModify(_Symbol, newSL, tp))
         {
            if(VerboseLog)
               Print("Manage: BE modify failed retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
         }
         else if(VerboseLog)
         {
            Print("Manage: Break-even applied ticket=", ticket, " newSL=", newSL);
         }
      }
   }

   if(UseTimeStop && barsSinceOpen >= TimeStopBars && g_maxFavorableR < MinProgressR)
   {
      if(!trade.PositionClose(_Symbol))
      {
         if(VerboseLog)
            Print("Manage: Time stop close failed retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      }
      else if(VerboseLog)
      {
         Print("Manage: Time stop close ticket=", ticket, " bars=", barsSinceOpen, " maxR=", g_maxFavorableR);
      }
      ResetManageState();
   }
}

void OnTick()
{
   if(!IsNewBar())
      return;

   ManageOpenPosition();

   if(!SpreadFilter(MaxSpreadPoints))
   {
      if(VerboseLog)
         Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: Spread");
      return;
   }

   if(PositionSelect(_Symbol))
   {
      if(VerboseLog)
         Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: Position exists");
      return;
   }

   if(!SessionFilter())
   {
      if(VerboseLog)
         Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: Session");
      return;
   }

   if(g_pendingDir != 0)
   {
      g_age++;
      if(g_age > 3)
      {
         if(VerboseLog)
            Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Pending retest expired");
         g_pendingDir   = 0;
         g_pendingLevel = 0.0;
         g_age          = 0;
      }
      else
      {
         const bool touch = RetestTouchesLevel(g_pendingLevel, RetestTolerancePips, 1);
         if(!touch)
         {
            if(VerboseLog)
               Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: No retest");
            return;
         }

         if(!ValidateCandleClosed(1))
         {
            if(VerboseLog)
               Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: Candle invalid");
            return;
         }

         if(UseMomentumFilter && !HasSimpleMomentum(g_pendingDir, 1))
         {
            if(VerboseLog)
               Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: Weak momentum");
            return;
         }

         if(UseRejectionFilter && !HasRetestRejection(g_pendingDir, 1))
         {
            if(VerboseLog)
               Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: Weak rejection (soft filter)");
            return;
         }

         MqlDateTime t;
         TimeToStruct(TimeCurrent(), t);
         if(SkipWorstHour13 && t.hour == 13)
         {
            if(VerboseLog)
               Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: Worst hour filter (13)");
            return;
         }

         double emaH1[1];
         if(CopyBuffer(s_emaH1, 0, 1, 1, emaH1) < 1)
         {
            if(VerboseLog)
               Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: EMA unavailable");
            return;
         }
         const double emaDistancePips = MathAbs(iClose(_Symbol, PERIOD_M5, 1) - emaH1[0]) / PricePerPip();
         if(emaDistancePips > MaxEmaDistancePips)
         {
            if(VerboseLog)
               Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: EMA distance too high (", DoubleToString(emaDistancePips, 2), " pips)");
            return;
         }

         if(g_pendingDir == 1 && !IsH1UpTrendClosed())
         {
            if(VerboseLog)
               Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: Not uptrend (H1)");
            g_pendingDir   = 0;
            g_pendingLevel = 0.0;
            g_age          = 0;
            return;
         }
         if(g_pendingDir == 2 && !IsH1DownTrendClosed())
         {
            if(VerboseLog)
               Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: Not downtrend (H1)");
            g_pendingDir   = 0;
            g_pendingLevel = 0.0;
            g_age          = 0;
            return;
         }

         const bool isBuy = (g_pendingDir == 1);
         const double lot = CalculateRiskLot(_Symbol, RiskPercent, StopLossPips, isBuy);
         Print("ENTRY: Retest ", (isBuy ? "BUY" : "SELL"), " lot=", lot);
         ExecuteTrade(isBuy, lot);

         g_pendingDir   = 0;
         g_pendingLevel = 0.0;
         g_age          = 0;
         return;
      }
   }

   bool isLong = false;
   bool isShort = false;
   double broken = 0.0;
   if(!DetectBreakoutCloseBar1(BreakoutLookback, BreakoutBufferPips, isLong, isShort, broken))
   {
      if(VerboseLog)
         Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " Blocked: No breakout");
      return;
   }

   g_pendingLevel = broken;
   g_pendingDir   = isLong ? 1 : 2;
   g_age          = 0;
}

void PrintTradeStatsSummary()
{
   if(g_summaryPrinted)
      return;
   g_summaryPrinted = true;

   const double avgBreakoutWin = (g_countWin > 0 ? g_sumBreakoutWin / g_countWin : 0.0);
   const double avgBreakoutLoss = (g_countLoss > 0 ? g_sumBreakoutLoss / g_countLoss : 0.0);
   const double avgEmaWin = (g_countWin > 0 ? g_sumEmaWin / g_countWin : 0.0);
   const double avgEmaLoss = (g_countLoss > 0 ? g_sumEmaLoss / g_countLoss : 0.0);

   int bestHour = -1, worstHour = -1;
   int bestDiff = -1000000, worstDiff = 1000000;
   for(int h = 0; h < 24; h++)
   {
      const int diff = g_hourWins[h] - g_hourLosses[h];
      if(diff > bestDiff)
      {
         bestDiff = diff;
         bestHour = h;
      }
      if(diff < worstDiff)
      {
         worstDiff = diff;
         worstHour = h;
      }
   }

   Print("TRADE_STATS SUMMARY wins=", g_countWin, " losses=", g_countLoss,
         " avg_breakout_strength_win=", DoubleToString(avgBreakoutWin, 4),
         " avg_breakout_strength_loss=", DoubleToString(avgBreakoutLoss, 4),
         " avg_ema_distance_win=", DoubleToString(avgEmaWin, 2),
         " avg_ema_distance_loss=", DoubleToString(avgEmaLoss, 2),
         " best_hour=", bestHour,
         " worst_hour=", worstHour);
}

void OnTesterDeinit()
{
   PrintTradeStatsSummary();
}
