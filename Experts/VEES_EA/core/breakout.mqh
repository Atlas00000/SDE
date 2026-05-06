#ifndef BREAKOUT_MQH
#define BREAKOUT_MQH

#include "pip.mqh"

// Highest high / lowest low over `lookback` bars starting at shift `rangeStartShift` (typically 2).
void GetM5Range(const int lookback, const int rangeStartShift, double &rangeHigh, double &rangeLow)
{
   const int highBar = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, lookback, rangeStartShift);
   const int lowBar  = iLowest(_Symbol, PERIOD_M5, MODE_LOW, lookback, rangeStartShift);
   rangeHigh = iHigh(_Symbol, PERIOD_M5, highBar);
   rangeLow  = iLow(_Symbol, PERIOD_M5, lowBar);
}

// Closed bar 1: close must be beyond range (20 bars at shifts 2..21) + buffer in pips.
bool DetectBreakoutCloseBar1(const int lookback, const double bufferPips,
                              bool &isLong, bool &isShort, double &brokenLevel)
{
   isLong = false;
   isShort = false;
   brokenLevel = 0.0;

   double rangeHigh = 0.0;
   double rangeLow  = 0.0;
   GetM5Range(lookback, 2, rangeHigh, rangeLow);

   const double buf = bufferPips * PricePerPip();
   const double c1    = iClose(_Symbol, PERIOD_M5, 1);

   if(c1 > rangeHigh + buf)
   {
      isLong      = true;
      brokenLevel = rangeHigh;
      return true;
   }
   if(c1 < rangeLow - buf)
   {
      isShort     = true;
      brokenLevel = rangeLow;
      return true;
   }
   return false;
}

// Wick or close: bar intersects [level - tol, level + tol].
bool RetestTouchesLevel(const double level, const double tolPips, const int shift)
{
   const double tol = tolPips * PricePerPip();
   const double L   = iLow(_Symbol, PERIOD_M5, shift);
   const double H   = iHigh(_Symbol, PERIOD_M5, shift);
   return (L <= level + tol) && (H >= level - tol);
}

// Breakout-bar impulse: strong body vs range + range expansion vs prior 10 bars (shifts 2..11).
bool IsStrongMomentum(const int shift)
{
   const double open  = iOpen(_Symbol, PERIOD_M5, shift);
   const double close = iClose(_Symbol, PERIOD_M5, shift);
   const double high  = iHigh(_Symbol, PERIOD_M5, shift);
   const double low   = iLow(_Symbol, PERIOD_M5, shift);

   const double body  = MathAbs(close - open);
   const double range = high - low;

   if(range <= 0.0)
      return false;

   double avgRange = 0.0;
   for(int i = 2; i <= 11; i++)
      avgRange += (iHigh(_Symbol, PERIOD_M5, i) - iLow(_Symbol, PERIOD_M5, i));
   avgRange /= 10.0;

   return (body / range >= 0.70) && (range >= avgRange * 1.5);
}

// Continuation confirmation on the next closed candle after breakout.
// dir: 1 = buy breakout, 2 = sell breakout.
bool HasFollowThrough(const int dir, const double breakoutClose)
{
   const double confirmClose = iClose(_Symbol, PERIOD_M5, 1);

   if(dir == 1)
      return (confirmClose > breakoutClose);
   if(dir == 2)
      return (confirmClose < breakoutClose);

   return false;
}

#endif
