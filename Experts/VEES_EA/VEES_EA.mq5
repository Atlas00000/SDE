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
input bool   UseMomentumFilter  = true;
input bool   UseRejectionFilter = false;
input double RejectionStrength  = 0.3;

// 0 = idle, 1 = wait long retest, 2 = wait short retest
int    g_pendingDir   = 0;
double g_pendingLevel = 0.0;
int    g_age          = 0;

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

void OnTick()
{
   if(!IsNewBar())
      return;

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
