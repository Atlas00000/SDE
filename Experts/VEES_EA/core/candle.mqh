#ifndef CANDLE_MQH
#define CANDLE_MQH

// Body >= 50% of range on a completed bar (use shift 1 on new bar).
bool ValidateCandleClosed(const int shift)
{
   const double open  = iOpen(_Symbol, PERIOD_M5, shift);
   const double close = iClose(_Symbol, PERIOD_M5, shift);
   const double high  = iHigh(_Symbol, PERIOD_M5, shift);
   const double low   = iLow(_Symbol, PERIOD_M5, shift);

   const double body  = MathAbs(close - open);
   const double range = high - low;

   if(range <= 0.0)
      return false;

   return (body / range >= 0.5);
}

#endif
