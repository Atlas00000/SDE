void ManageOpenTrades()
{
    for(int i=PositionsTotal()-1; i>=0; i--)
    {
        ulong ticket = PositionGetTicket(i);

        double profit = PositionGetDouble(POSITION_PROFIT);

        if(profit > 20)
        {
            // move SL / trailing logic
        }
    }
}