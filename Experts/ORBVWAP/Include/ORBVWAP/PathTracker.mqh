//+------------------------------------------------------------------+
//| PathTracker.mqh — AI-4 intra-trade MFE/MAE sampling              |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_PATHTRACKER_MQH__
#define __ORBVWAP_PATHTRACKER_MQH__

#include "Inputs.mqh"
#include "Constants.mqh"

struct SPathTrack
  {
   ulong    ticket;
   ulong    position_id;
   double   range_width;
   datetime open_time;
   double   mfe_price;
   double   mae_price;
   double   mfe_at_15;
   double   mfe_at_30;
   double   mfe_at_45;
   double   mfe_at_60;
   bool     snap_15;
   bool     snap_30;
   bool     snap_45;
   bool     snap_60;
  };

class CPathTracker
  {
   static SPathTrack s_tracks[];

   static int FindIndex(const ulong ticket)
     {
      for(int i = 0; i < ArraySize(s_tracks); i++)
        {
         if(s_tracks[i].ticket == ticket)
            return(i);
        }
      return(-1);
     }

   static void RemoveAt(const int idx)
     {
      const int last = ArraySize(s_tracks) - 1;
      if(idx < 0 || idx > last)
         return;
      if(idx != last)
         s_tracks[idx] = s_tracks[last];
      ArrayResize(s_tracks, last);
     }

   static double FavorableMove(const ENUM_POSITION_TYPE pos_type,
                               const double entry,
                               const double bid,
                               const double ask)
     {
      if(pos_type == POSITION_TYPE_BUY)
         return(MathMax(0.0, bid - entry));
      return(MathMax(0.0, entry - ask));
     }

   static double AdverseMove(const ENUM_POSITION_TYPE pos_type,
                             const double entry,
                             const double bid,
                             const double ask)
     {
      if(pos_type == POSITION_TYPE_BUY)
         return(MathMax(0.0, entry - bid));
      return(MathMax(0.0, ask - entry));
     }

   static void WritePathLine(const SPathTrack &t,
                             const double      profit,
                             const int         label_win,
                             const datetime    close_gmt)
     {
      if(!InpEnablePathExport)
         return;

      const double mfe = t.mfe_price;
      const double mae = t.mae_price;
      double mfe_frac = 0.0;
      double mae_frac = 0.0;
      if(t.range_width > 0.0)
        {
         mfe_frac = mfe / t.range_width;
         mae_frac = mae / t.range_width;
        }

      const string line = StringFormat("%I64u,%I64u,%s,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.2f,%d",
                                       t.position_id,
                                       t.ticket,
                                       TimeToString(close_gmt, TIME_DATE | TIME_SECONDS),
                                       t.range_width,
                                       mfe,
                                       mae,
                                       mfe_frac,
                                       mae_frac,
                                       t.mfe_at_15,
                                       t.mfe_at_30,
                                       t.mfe_at_45,
                                       profit,
                                       label_win);

      const int handle = FileOpen(ORBVWAP_PATHS_FILE,
                                  FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
      if(handle == INVALID_HANDLE)
         return;
      const bool is_new = (FileSize(handle) == 0);
      FileSeek(handle, 0, SEEK_END);
      if(is_new)
         FileWriteString(handle,
                         "position_id,ticket,close_time_gmt,range_width,mfe,mae,mfe_frac,mae_frac,"
                         "mfe_at_15,mfe_at_30,mfe_at_45,profit,label_win\r\n");
      FileWriteString(handle, line + "\r\n");
      FileClose(handle);
     }

public:
   static void Reset()
     {
      ArrayResize(s_tracks, 0);
     }

   static void Register(const ulong ticket,
                        const ulong position_id,
                        const double range_width)
     {
      if(ticket == 0 || range_width <= 0.0)
         return;
      if(FindIndex(ticket) >= 0)
         return;

      SPathTrack t;
      t.ticket        = ticket;
      t.position_id   = position_id;
      t.range_width   = range_width;
      t.open_time     = (datetime)PositionGetInteger(POSITION_TIME);
      t.mfe_price     = 0.0;
      t.mae_price     = 0.0;
      t.mfe_at_15     = 0.0;
      t.mfe_at_30     = 0.0;
      t.mfe_at_45     = 0.0;
      t.mfe_at_60     = 0.0;
      t.snap_15       = false;
      t.snap_30       = false;
      t.snap_45       = false;
      t.snap_60       = false;

      const int n = ArraySize(s_tracks);
      ArrayResize(s_tracks, n + 1);
      s_tracks[n] = t;
     }

   static void Update(const string symbol, const long magic)
     {
      if(!InpEnablePathExport && InpAiExitMode == ORBVWAP_AI_EXIT_OFF)
         return;

      const datetime now = TimeCurrent();
      const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      for(int i = ArraySize(s_tracks) - 1; i >= 0; i--)
        {
         const ulong ticket = s_tracks[i].ticket;
         if(!PositionSelectByTicket(ticket))
           {
            RemoveAt(i);
            continue;
           }
         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         const double fav = FavorableMove(pos_type, entry, bid, ask);
         const double adv = AdverseMove(pos_type, entry, bid, ask);
         if(fav > s_tracks[i].mfe_price)
            s_tracks[i].mfe_price = fav;
         if(adv > s_tracks[i].mae_price)
            s_tracks[i].mae_price = adv;

         const int hold_min = (int)((now - s_tracks[i].open_time) / 60);
         if(hold_min >= 15 && !s_tracks[i].snap_15)
           {
            s_tracks[i].mfe_at_15 = s_tracks[i].mfe_price;
            s_tracks[i].snap_15   = true;
           }
         if(hold_min >= 30 && !s_tracks[i].snap_30)
           {
            s_tracks[i].mfe_at_30 = s_tracks[i].mfe_price;
            s_tracks[i].snap_30   = true;
           }
         if(hold_min >= 45 && !s_tracks[i].snap_45)
           {
            s_tracks[i].mfe_at_45 = s_tracks[i].mfe_price;
            s_tracks[i].snap_45   = true;
           }
         if(hold_min >= 60 && !s_tracks[i].snap_60)
           {
            s_tracks[i].mfe_at_60 = s_tracks[i].mfe_price;
            s_tracks[i].snap_60   = true;
           }
        }
     }

   static void OnClose(const ulong position_id,
                       const double profit,
                       const int label_win,
                       const datetime close_gmt)
     {
      for(int i = ArraySize(s_tracks) - 1; i >= 0; i--)
        {
         if(s_tracks[i].position_id != position_id && s_tracks[i].ticket != position_id)
            continue;
         WritePathLine(s_tracks[i], profit, label_win, close_gmt);
         RemoveAt(i);
         return;
        }
     }

   static double MfeFrac(const ulong ticket)
     {
      const int idx = FindIndex(ticket);
      if(idx < 0)
         return(0.0);
      if(s_tracks[idx].range_width <= 0.0)
         return(0.0);
      return(s_tracks[idx].mfe_price / s_tracks[idx].range_width);
     }

   static int HoldMinutes(const ulong ticket)
     {
      const int idx = FindIndex(ticket);
      if(idx < 0)
         return(0);
      return((int)((TimeCurrent() - s_tracks[idx].open_time) / 60));
     }

   static double RangeWidth(const ulong ticket)
     {
      const int idx = FindIndex(ticket);
      if(idx < 0)
         return(0.0);
      return(s_tracks[idx].range_width);
     }
  };

SPathTrack CPathTracker::s_tracks[];

#endif // __ORBVWAP_PATHTRACKER_MQH__
