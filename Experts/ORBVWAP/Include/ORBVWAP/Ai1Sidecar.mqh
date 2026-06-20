//+------------------------------------------------------------------+
//| Ai1Sidecar.mqh — INF-8: AI-1 FILE_COMMON sidecar IPC             |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AI1SIDECAR_MQH__
#define __ORBVWAP_AI1SIDECAR_MQH__

#include "FilePath.mqh"
#include "Logger.mqh"
#include "AiFeatures.mqh"

// Binary layout (116 bytes, little-endian) — must match Scripts/ai1_ipc.py
const uint   ORBVWAP_AI1_IPC_MAGIC       = 0x3149524F; // "ORI1"
const uint   ORBVWAP_AI1_IPC_VERSION     = 1;
const int    ORBVWAP_AI1_N_FEATURES      = 10;
const int    ORBVWAP_AI1_SIDECAR_SIZE    = 116;
const uint   ORBVWAP_AI1_STATUS_IDLE     = 0;
const uint   ORBVWAP_AI1_STATUS_REQUEST  = 1;
const uint   ORBVWAP_AI1_STATUS_READY    = 2;
const uint   ORBVWAP_AI1_STATUS_ERROR    = 3;

const double ORBVWAP_AI1_FAILOPEN_SCORE  = 0.5;

ulong g_orb_ai1_request_seq = 0;

union UAi1DoublePack
  {
   double            v;
   uchar             b[8];
  };

void OrbAi1_WriteU32(uchar &buf[], int &pos, const uint v)
  {
   buf[pos++] = (uchar)(v & 0xFF);
   buf[pos++] = (uchar)((v >> 8) & 0xFF);
   buf[pos++] = (uchar)((v >> 16) & 0xFF);
   buf[pos++] = (uchar)((v >> 24) & 0xFF);
  }

void OrbAi1_WriteU64(uchar &buf[], int &pos, const ulong v)
  {
   for(int i = 0; i < 8; i++)
      buf[pos++] = (uchar)((v >> (8 * i)) & 0xFF);
  }

void OrbAi1_WriteDouble(uchar &buf[], int &pos, const double v)
  {
   UAi1DoublePack p;
   p.v = v;
   for(int i = 0; i < 8; i++)
      buf[pos++] = p.b[i];
  }

bool OrbAi1_ReadU32(const uchar &buf[], int &pos, uint &v)
  {
   if(pos + 4 > ORBVWAP_AI1_SIDECAR_SIZE)
      return(false);
   v = (uint)buf[pos]
       | ((uint)buf[pos + 1] << 8)
       | ((uint)buf[pos + 2] << 16)
       | ((uint)buf[pos + 3] << 24);
   pos += 4;
   return(true);
  }

bool OrbAi1_ReadU64(const uchar &buf[], int &pos, ulong &v)
  {
   if(pos + 8 > ORBVWAP_AI1_SIDECAR_SIZE)
      return(false);
   v = 0;
   for(int i = 0; i < 8; i++)
      v |= ((ulong)buf[pos + i] << (8 * i));
   pos += 8;
   return(true);
  }

bool OrbAi1_ReadDouble(const uchar &buf[], int &pos, double &v)
  {
   if(pos + 8 > ORBVWAP_AI1_SIDECAR_SIZE)
      return(false);
   UAi1DoublePack p;
   p.v = 0.0;
   for(int i = 0; i < 8; i++)
      p.b[i] = buf[pos + i];
   pos += 8;
   v = p.v;
   return(true);
  }

bool OrbAi1_PackBlock(const ulong    requestSeq,
                      const ulong    responseSeq,
                      const uint     status,
                      const double   ai1Score,
                      const double   &feats[],
                      uchar          &buf[])
  {
   if(ArraySize(feats) != ORBVWAP_AI1_N_FEATURES)
      return(false);
   ArrayResize(buf, ORBVWAP_AI1_SIDECAR_SIZE);
   int pos = 0;
   OrbAi1_WriteU32(buf, pos, ORBVWAP_AI1_IPC_MAGIC);
   OrbAi1_WriteU32(buf, pos, ORBVWAP_AI1_IPC_VERSION);
   OrbAi1_WriteU64(buf, pos, requestSeq);
   OrbAi1_WriteU64(buf, pos, responseSeq);
   OrbAi1_WriteU32(buf, pos, status);
   OrbAi1_WriteDouble(buf, pos, ai1Score);
   for(int i = 0; i < ORBVWAP_AI1_N_FEATURES; i++)
      OrbAi1_WriteDouble(buf, pos, feats[i]);
   return(pos == ORBVWAP_AI1_SIDECAR_SIZE);
  }

bool OrbAi1_UnpackBlock(const uchar &buf[],
                        ulong       &requestSeq,
                        ulong       &responseSeq,
                        uint        &status,
                        double      &ai1Score,
                        double      &feats[])
  {
   if(ArraySize(buf) < ORBVWAP_AI1_SIDECAR_SIZE)
      return(false);
   int pos = 0;
   uint magic = 0, version = 0;
   if(!OrbAi1_ReadU32(buf, pos, magic) || magic != ORBVWAP_AI1_IPC_MAGIC)
      return(false);
   if(!OrbAi1_ReadU32(buf, pos, version) || version != ORBVWAP_AI1_IPC_VERSION)
      return(false);
   if(!OrbAi1_ReadU64(buf, pos, requestSeq))
      return(false);
   if(!OrbAi1_ReadU64(buf, pos, responseSeq))
      return(false);
   if(!OrbAi1_ReadU32(buf, pos, status))
      return(false);
   if(!OrbAi1_ReadDouble(buf, pos, ai1Score))
      return(false);
   ArrayResize(feats, ORBVWAP_AI1_N_FEATURES);
   for(int i = 0; i < ORBVWAP_AI1_N_FEATURES; i++)
     {
      if(!OrbAi1_ReadDouble(buf, pos, feats[i]))
         return(false);
     }
   return(pos == ORBVWAP_AI1_SIDECAR_SIZE);
  }

class CAi1Sidecar
  {
   static string NormalizePath(const string relPath)
     {
      string path = OrbVwapNormalizeInputPath(relPath);
      if(path == "")
         path = "Logs\\ORBVWAP_ai1_sidecar.bin";
      return(path);
     }

   static bool WriteBlock(const string relPath, const uchar &buf[])
     {
      const string path = NormalizePath(relPath);
      const int h = FileOpen(path,
                             FILE_BIN | FILE_WRITE |
                             FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON);
      if(h == INVALID_HANDLE)
        {
         COrbVwapLogger::Warn("AI1 sidecar write failed: " + path
                              + " err=" + IntegerToString(GetLastError()));
         return(false);
        }
      FileSeek(h, 0, SEEK_SET);
      if(FileWriteArray(h, buf, 0, ORBVWAP_AI1_SIDECAR_SIZE) != (uint)ORBVWAP_AI1_SIDECAR_SIZE)
        {
         FileClose(h);
         return(false);
        }
      FileFlush(h);
      FileClose(h);
      return(true);
     }

public:
   static bool Init(const string relPath)
     {
      g_orb_ai1_request_seq = 0;
      const string path = NormalizePath(relPath);
      OrbVwapEnsureCommonParentFolders(path);

      double zeroFeats[];
      ArrayResize(zeroFeats, ORBVWAP_AI1_N_FEATURES);
      ArrayInitialize(zeroFeats, 0.0);

      uchar buf[];
      if(!OrbAi1_PackBlock(0, 0, ORBVWAP_AI1_STATUS_IDLE, ORBVWAP_AI1_FAILOPEN_SCORE, zeroFeats, buf))
         return(false);

      const int h = FileOpen(path,
                             FILE_BIN | FILE_READ | FILE_WRITE |
                             FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON);
      if(h == INVALID_HANDLE)
        {
         COrbVwapLogger::Warn("AI1 sidecar file open failed: " + path);
         return(false);
        }
      FileWriteArray(h, buf, 0, ORBVWAP_AI1_SIDECAR_SIZE);
      FileFlush(h);
      FileClose(h);
      return(true);
     }

   static bool RequestScore(const string   relPath,
                            const int      timeoutMs,
                            const double   &feats[],
                            double         &ai1Score)
     {
      ai1Score = ORBVWAP_AI1_FAILOPEN_SCORE;
      if(ArraySize(feats) != ORBVWAP_AI1_N_FEATURES)
         return(false);

      g_orb_ai1_request_seq++;
      const ulong reqSeq = g_orb_ai1_request_seq;

      uchar buf[];
      if(!OrbAi1_PackBlock(reqSeq, 0, ORBVWAP_AI1_STATUS_REQUEST, 0.0, feats, buf))
         return(false);
      if(!WriteBlock(relPath, buf))
         return(false);

      const uint deadline = GetTickCount() + (uint)MathMax(timeoutMs, 1);
      const string path = NormalizePath(relPath);

      while(GetTickCount() < deadline)
        {
         const int h = FileOpen(path,
                                FILE_BIN | FILE_READ |
                                FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON);
         if(h == INVALID_HANDLE)
           {
            Sleep(5);
            continue;
           }
         uchar in[];
         ArrayResize(in, ORBVWAP_AI1_SIDECAR_SIZE);
         const uint got = FileReadArray(h, in, 0, ORBVWAP_AI1_SIDECAR_SIZE);
         FileClose(h);
         if(got != (uint)ORBVWAP_AI1_SIDECAR_SIZE)
           {
            Sleep(5);
            continue;
           }

         ulong readReq = 0, readResp = 0;
         uint status = ORBVWAP_AI1_STATUS_IDLE;
         double score = ORBVWAP_AI1_FAILOPEN_SCORE;
         double readFeats[];
         if(!OrbAi1_UnpackBlock(in, readReq, readResp, status, score, readFeats))
           {
            Sleep(5);
            continue;
           }

         if(readReq == reqSeq && readResp == reqSeq && status == ORBVWAP_AI1_STATUS_READY)
           {
            ai1Score = MathMax(0.0, MathMin(score, 1.0));
            uchar idle[];
            OrbAi1_PackBlock(reqSeq, reqSeq, ORBVWAP_AI1_STATUS_IDLE, ai1Score, readFeats, idle);
            WriteBlock(relPath, idle);
            return(true);
           }

         if(readReq == reqSeq && status == ORBVWAP_AI1_STATUS_ERROR)
           {
            COrbVwapLogger::Warn("AI1 sidecar ERROR — fail-open ai1_score=0.5");
            return(false);
           }
         Sleep(5);
        }

      COrbVwapLogger::Warn(StringFormat("AI1 sidecar timeout (%d ms) — fail-open ai1_score=0.5",
                                        timeoutMs));
      uchar idle[];
      OrbAi1_PackBlock(reqSeq, 0, ORBVWAP_AI1_STATUS_IDLE, ORBVWAP_AI1_FAILOPEN_SCORE, feats, idle);
      WriteBlock(relPath, idle);
      return(false);
     }
  };

#endif // __ORBVWAP_AI1SIDECAR_MQH__
