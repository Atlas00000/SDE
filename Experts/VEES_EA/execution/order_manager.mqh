void ExecuteTrade()
{
    if(PositionSelect(_Symbol)) return;

    double lot = CalculateLot(1.0, 20);

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    double sl, tp;

    if(iClose(_Symbol, PERIOD_M5, 0) > iOpen(_Symbol, PERIOD_M5, 0))
    {
        sl = bid - 20 * _Point;
        tp = bid + 50 * _Point;

        trade.Buy(lot, _Symbol, ask, sl, tp);
    }
    else
    {
        sl = ask + 20 * _Point;
        tp = ask - 50 * _Point;

        trade.Sell(lot, _Symbol, bid, sl, tp);
    }
}