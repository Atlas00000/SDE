#ifndef VOLATILITY_MQH
#define VOLATILITY_MQH

bool CheckATRExpansion()
{
    int handle = iATR(_Symbol, PERIOD_M5, 14);

    if(handle == INVALID_HANDLE)
        return true; // fail-safe

    double atr[2];

    if(CopyBuffer(handle, 0, 0, 2, atr) < 2)
        return true;

    return (atr[0] >= atr[1]); // relaxed
}

#endif