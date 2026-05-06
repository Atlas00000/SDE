#ifndef RISK_MANAGER_MQH
#define RISK_MANAGER_MQH

#include "../core/pip.mqh"

int VolumeDigitsFromStep(const double lotStep)
{
   if(lotStep <= 0.0 || lotStep >= 1.0)
      return 0;
   int digits = 0;
   double x = lotStep;
   while(x < 1.0 - 1e-12 && digits < 8)
   {
      x *= 10.0;
      digits++;
   }
   return digits;
}

double CalculateRiskLot(const string sym, const double riskPercent, const double stopLossPips, const bool isBuy)
{
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   const double riskMoney = balance * (riskPercent / 100.0);
   const double price      = isBuy ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   const double pip        = PricePerPip();
   const double slPrice    = isBuy ? (price - stopLossPips * pip) : (price + stopLossPips * pip);

   double profit = 0.0;
   const ENUM_ORDER_TYPE ot = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(ot, sym, 1.0, price, slPrice, profit))
      return SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   const double lossPerLot = MathAbs(profit);
   if(lossPerLot < 1e-12)
      return SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   const double minLot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   const double maxLot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   const double lotStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   double lots = riskMoney / lossPerLot;
   lots        = MathFloor(lots / lotStep) * lotStep;
   if(lots < minLot)
      lots = minLot;
   if(lots > maxLot)
      lots = maxLot;

   const int vd = VolumeDigitsFromStep(lotStep);
   return NormalizeDouble(lots, vd);
}

#endif
