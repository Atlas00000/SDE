#ifndef SPREAD_MQH
#define SPREAD_MQH

bool SpreadFilter(double maxSpread = 20)
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    double spread = (ask - bid) / _Point;

    return (spread <= maxSpread);
}

#endif