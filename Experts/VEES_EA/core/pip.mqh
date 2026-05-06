#ifndef PIP_MQH
#define PIP_MQH

// One "pip" in price units (e.g. 0.0001 on 5-digit FX, 0.01 on 3-digit JPY).
double PricePerPip()
{
   const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(dg == 3 || dg == 5)
      return pt * 10.0;
   return pt;
}

#endif
