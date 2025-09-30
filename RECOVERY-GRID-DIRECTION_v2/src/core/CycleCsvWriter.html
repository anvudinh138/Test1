//+------------------------------------------------------------------+
//| Cycle CSV writer                                                 |
//+------------------------------------------------------------------+
#ifndef __RGD_V2_CYCLE_CSV_WRITER_MQH__
#define __RGD_V2_CYCLE_CSV_WRITER_MQH__

struct SCycleCsvRow
  {
   datetime timestamp;
   string   symbol;
   int      cycle_id;
   string   direction;
   string   kind;
   double   realized_usd;
   double   total_lot;
   double   max_dd_usd;
   double   spacing_pips;
   string   adaptive_tier;
   bool     lockdown_active;
   double   partial_close_volume;
   double   hedge_profit_pull;
   double   session_equity;
  };

class CCycleCsvWriter
  {
private:
   string m_path_template;
   string m_resolved_path;
   bool   m_enabled;

   string ReplaceAll(string text,const string find,const string repl) const
     {
      if(StringLen(find)==0)
         return text;
      while(true)
        {
         int pos=StringFind(text,find,0);
         if(pos==-1)
            break;
         text=StringSubstr(text,0,pos)+repl+StringSubstr(text,pos+StringLen(find));
        }
      return text;
     }

   string FormatDate(const datetime ts) const
     {
      MqlDateTime dt;
      TimeToStruct(ts,dt);
      return StringFormat("%04d%02d%02d",dt.year,dt.mon,dt.day);
     }

   bool EnsureDirectory(const string path) const
     {
      int pos=StringFind(path,"\\",0);
      int last=-1;
      while(pos!=-1)
        {
         string sub=StringSubstr(path,0,pos);
         if(StringLen(sub)>0)
            FolderCreate(sub);
         last=pos;
         pos=StringFind(path,"\\",pos+1);
        }
      if(last==-1)
         return true;
      string dir=StringSubstr(path,0,last);
      if(StringLen(dir)==0)
         return true;
      FolderCreate(dir);
      return true;
     }

   bool EnsureHeader(const int handle) const
     {
      if(FileSize(handle)>0)
         return true;
      FileSeek(handle,0,SEEK_SET);
      return FileWrite(handle,
                       "timestamp",
                       "symbol",
                       "cycle_id",
                       "direction",
                       "kind",
                       "realized_usd",
                       "total_lot",
                       "max_dd_usd",
                       "spacing_pips",
                       "adaptive_tier",
                       "lockdown_active",
                       "partial_close_volume",
                       "hedge_profit_pull",
                       "session_equity")>0;
     }

public:
                     CCycleCsvWriter()
                       : m_path_template(""),
                         m_resolved_path(""),
                         m_enabled(false)
     {
     }

   bool              Init(const string path_template,const string symbol)
     {
      m_path_template=path_template;
      m_enabled=false;
      m_resolved_path="";
      if(StringLen(path_template)==0)
         return false;

      datetime now=TimeCurrent();
      string expanded=ReplaceAll(path_template,"%symbol%",symbol);
      expanded=ReplaceAll(expanded,"%date%",FormatDate(now));
      expanded=ReplaceAll(expanded,"/","\\");
      if(StringLen(expanded)==0)
         return false;
      if(StringFind(expanded,".csv",0)==-1)
         expanded+=".csv";

      EnsureDirectory(expanded);
      m_resolved_path=expanded;
      int handle=FileOpen(m_resolved_path,FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_WRITE,',');
      if(handle==INVALID_HANDLE)
         return false;
      EnsureHeader(handle);
      FileClose(handle);
      m_enabled=true;
      return true;
     }

   bool              Enabled() const { return m_enabled; }

   bool              Append(const SCycleCsvRow &row)
     {
      if(!m_enabled || StringLen(m_resolved_path)==0)
         return false;
      int handle=FileOpen(m_resolved_path,FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_WRITE,',');
      if(handle==INVALID_HANDLE)
         return false;
      FileSeek(handle,0,SEEK_END);
      bool ok=FileWrite(handle,
                        TimeToString(row.timestamp,TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                        row.symbol,
                        row.cycle_id,
                        row.direction,
                        row.kind,
                        row.realized_usd,
                        row.total_lot,
                        row.max_dd_usd,
                        row.spacing_pips,
                        row.adaptive_tier,
                        row.lockdown_active?1:0,
                        row.partial_close_volume,
                        row.hedge_profit_pull,
                        row.session_equity)>0;
      FileClose(handle);
      return ok;
     }
  };

#endif // __RGD_V2_CYCLE_CSV_WRITER_MQH__
