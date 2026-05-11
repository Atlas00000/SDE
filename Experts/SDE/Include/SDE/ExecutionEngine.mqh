#ifndef __SDE_EXECUTION_ENGINE_MQH__
#define __SDE_EXECUTION_ENGINE_MQH__

#include <Trade/Trade.mqh>
#include "Config.mqh"
#include "State.mqh"

class SdeExecutionEngine
  {
private:
   CTrade    m_trade;
   string    m_symbol;
   SdeConfig m_cfg;

   bool SelectFillingMode()
     {
      long fill_flags=0;
      if(!SymbolInfoInteger(m_symbol,SYMBOL_FILLING_MODE,fill_flags))
         return false;

      if((fill_flags & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
        {
         m_trade.SetTypeFilling(ORDER_FILLING_FOK);
         return true;
        }
      if((fill_flags & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
        {
         m_trade.SetTypeFilling(ORDER_FILLING_IOC);
         return true;
        }

      return false;
     }

public:
   void Init(const string symbol,const SdeConfig &cfg)
     {
      m_symbol=symbol;
      m_cfg=cfg;
      m_trade.SetExpertMagicNumber(m_cfg.magic_number);
      m_trade.SetDeviationInPoints(m_cfg.max_slippage_points);
      SelectFillingMode();
     }

   bool BuildStops(const SdeDirection dir,const double entry,double &sl,double &tp,string &err) const
     {
      if(m_cfg.stop_loss_points<=0 || m_cfg.take_profit_points<=0)
        {
         err="SL/TP points must be > 0";
         return false;
        }

      const double p=_Point;
      if(dir==DIR_BUY)
        {
         sl=NormalizeDouble(entry-(m_cfg.stop_loss_points*p),_Digits);
         tp=NormalizeDouble(entry+(m_cfg.take_profit_points*p),_Digits);
        }
      else
        {
         sl=NormalizeDouble(entry+(m_cfg.stop_loss_points*p),_Digits);
         tp=NormalizeDouble(entry-(m_cfg.take_profit_points*p),_Digits);
        }

      long stops_level=(long)SymbolInfoInteger(m_symbol,SYMBOL_TRADE_STOPS_LEVEL);
      if(stops_level>0)
        {
         double min_dist=stops_level*p;
         if(MathAbs(entry-sl)<min_dist || MathAbs(entry-tp)<min_dist)
           {
            err="Stops too close to market";
            return false;
           }
        }
      return true;
     }

   bool ExecuteMarket(const SdeDirection dir,const double volume,string &err)
     {
      if(volume<=0.0)
        {
         err="Invalid volume";
         return false;
        }

      long trade_mode=0;
      if(!SymbolInfoInteger(m_symbol,SYMBOL_TRADE_MODE,trade_mode) || trade_mode==SYMBOL_TRADE_MODE_DISABLED)
        {
         err="Trading disabled for symbol";
         return false;
        }

      double price=(dir==DIR_BUY)?SymbolInfoDouble(m_symbol,SYMBOL_ASK):SymbolInfoDouble(m_symbol,SYMBOL_BID);
      double sl=0.0,tp=0.0;
      if(!BuildStops(dir,price,sl,tp,err))
         return false;

      bool ok=false;
      if(dir==DIR_BUY)
         ok=m_trade.Buy(volume,m_symbol,0.0,sl,tp,"SDE_BUY");
      else if(dir==DIR_SELL)
         ok=m_trade.Sell(volume,m_symbol,0.0,sl,tp,"SDE_SELL");

      if(!ok)
        {
         err=StringFormat("Order failed retcode=%d",m_trade.ResultRetcode());
         return false;
        }

      return true;
     }
  };

#endif
