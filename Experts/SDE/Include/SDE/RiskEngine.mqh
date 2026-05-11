#ifndef __SDE_RISK_ENGINE_MQH__
#define __SDE_RISK_ENGINE_MQH__

#include "Config.mqh"
#include "State.mqh"

class SdeRiskEngine
  {
private:
   SdeConfig m_cfg;
   string    m_symbol;

   double NormalizeVolume(const double volume) const
     {
      double min_vol=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN);
      double max_vol=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MAX);
      double step=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP);
      double v=MathMax(min_vol,MathMin(max_vol,volume));
      return MathFloor(v/step)*step;
     }

public:
   void Init(const string symbol,const SdeConfig &cfg)
     {
      m_symbol=symbol;
      m_cfg=cfg;
     }

   bool AllowDirection(const SdeDirection dir) const
     {
      if(m_cfg.trade_permission==TRADE_DISABLED) return false;
      if(m_cfg.trade_permission==TRADE_BOTH) return true;
      if(m_cfg.trade_permission==TRADE_BUY_ONLY && dir==DIR_BUY) return true;
      if(m_cfg.trade_permission==TRADE_SELL_ONLY && dir==DIR_SELL) return true;
      return false;
     }

   bool SpreadOk() const
     {
      long spread=(long)SymbolInfoInteger(m_symbol,SYMBOL_SPREAD);
      return (spread<=m_cfg.max_spread_points);
     }

   bool EquityOk() const
     {
      return (AccountInfoDouble(ACCOUNT_EQUITY)>=m_cfg.min_equity);
     }

   int CountOpenPositionsByMagic(const long magic) const
     {
      int cnt=0;
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC)!=magic)
            continue;
         cnt++;
        }
      return cnt;
     }

   double CalculateVolume()
     {
      if(m_cfg.lot_mode==LOT_FIXED)
         return NormalizeVolume(m_cfg.fixed_lot);

      if(m_cfg.stop_loss_points<=0)
         return 0.0;

      double risk_money=AccountInfoDouble(ACCOUNT_BALANCE)*(m_cfg.risk_percent/100.0);
      double tick_value=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_VALUE);
      double tick_size=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE);
      if(tick_value<=0 || tick_size<=0)
         return 0.0;

      double point_value_per_lot=tick_value*(_Point/tick_size);
      double loss_per_lot=m_cfg.stop_loss_points*point_value_per_lot;
      if(loss_per_lot<=0.0)
         return 0.0;

      return NormalizeVolume(risk_money/loss_per_lot);
     }
  };

#endif
