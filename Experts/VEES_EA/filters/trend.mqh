#ifndef TREND_MQH
#define TREND_MQH

input int EMA_Period = 50;

static int s_emaH1 = INVALID_HANDLE;

bool TrendIndicatorInit()
{
   if(s_emaH1 != INVALID_HANDLE)
      IndicatorRelease(s_emaH1);

   s_emaH1 = iMA(_Symbol, PERIOD_H1, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   return (s_emaH1 != INVALID_HANDLE);
}

void TrendIndicatorDeinit()
{
   if(s_emaH1 != INVALID_HANDLE)
   {
      IndicatorRelease(s_emaH1);
      s_emaH1 = INVALID_HANDLE;
   }
}

bool IsH1UpTrendClosed()
{
   double c[1], e[1];
   if(CopyClose(_Symbol, PERIOD_H1, 1, 1, c) < 1)
      return false;
   if(CopyBuffer(s_emaH1, 0, 1, 1, e) < 1)
      return false;
   return (c[0] > e[0]);
}

bool IsH1DownTrendClosed()
{
   double c[1], e[1];
   if(CopyClose(_Symbol, PERIOD_H1, 1, 1, c) < 1)
      return false;
   if(CopyBuffer(s_emaH1, 0, 1, 1, e) < 1)
      return false;
   return (c[0] < e[0]);
}

#endif
