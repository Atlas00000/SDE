//+------------------------------------------------------------------+
//| FilePath.mqh — MQL5/Files and FILE_COMMON folder helpers         |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_FILEPATH_MQH__
#define __ORBVWAP_FILEPATH_MQH__

string OrbVwapNormalizeInputPath(const string raw)
  {
   const int p = StringFind(raw, "||");
   if(p >= 0)
      return(StringSubstr(raw, 0, p));
   return(raw);
  }

void OrbVwapEnsureCommonParentFolders(const string relPath)
  {
   const int lastSlash = StringFind(relPath, "\\", 0);
   if(lastSlash < 0)
      return;

   int pos = 0;
   string folder = "";
   while(pos >= 0)
     {
      const int next = StringFind(relPath, "\\", pos);
      if(next < 0)
         break;
      folder = StringSubstr(relPath, 0, next);
      if(folder != "")
         FolderCreate(folder, FILE_COMMON);
      pos = next + 1;
     }
  }

#endif // __ORBVWAP_FILEPATH_MQH__
