#ifndef COMPRESSION_MQH
#define COMPRESSION_MQH

bool DetectCompression(int bars = 12, double maxRangePips = 80)
{
    int highestIndex = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, bars, 1);
    int lowestIndex  = iLowest(_Symbol, PERIOD_M5, MODE_LOW, bars, 1);

    double high = iHigh(_Symbol, PERIOD_M5, highestIndex);
    double low  = iLow(_Symbol, PERIOD_M5, lowestIndex);

    double range = (high - low) / _Point;

    return (range <= maxRangePips);
}

#endif