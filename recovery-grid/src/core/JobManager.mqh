//+------------------------------------------------------------------+
//| Project: Recovery Grid Direction v3 - Multi-Job System           |
//| Purpose: Job Manager - Spawns and manages multiple lifecycles    |
//+------------------------------------------------------------------+
#ifndef __RGD_V3_JOB_MANAGER_MQH__
#define __RGD_V3_JOB_MANAGER_MQH__

#include "Types.mqh"
#include "Params.mqh"
#include "SpacingEngine.mqh"
#include "OrderExecutor.mqh"
#include "RescueEngine.mqh"
#include "LifecycleController.mqh"
#include "PortfolioLedger.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Job Structure (contains lifecycle + metadata)                    |
//+------------------------------------------------------------------+
struct SJob
  {
   // Identity
   int                      job_id;              // Unique job ID (1, 2, 3...)
   long                     magic;               // Job magic number
   datetime                 created_at;          // Spawn timestamp

   // Lifecycle controller (BUY + SELL baskets)
   CLifecycleController    *controller;

   // Job-specific risk limits
   double                   job_sl_usd;          // Max loss USD per job
   double                   job_dd_threshold;    // DD% to abandon job

   // Status flags
   EJobStatus               status;              // Current status
   bool                     is_full;             // Grid full flag
   bool                     is_tsl_active;       // TSL active flag

   // P&L tracking
   double                   realized_pnl;        // Closed profit/loss
   double                   unrealized_pnl;      // Floating P&L
   double                   peak_equity;         // Peak for DD calculation

   // Constructor
   SJob() : job_id(0),
            magic(0),
            created_at(0),
            controller(NULL),
            job_sl_usd(0),
            job_dd_threshold(0),
            status(JOB_ACTIVE),
            is_full(false),
            is_tsl_active(false),
            realized_pnl(0),
            unrealized_pnl(0),
            peak_equity(0)
     {
     }
  };

//+------------------------------------------------------------------+
//| Job Manager Class                                                |
//+------------------------------------------------------------------+
class CJobManager
  {
private:
   // Job array
   SJob              m_jobs[];              // Active jobs
   int               m_next_job_id;         // Auto-increment ID

   // Magic number configuration
   long              m_magic_start;         // User input start (e.g., 1000)
   long              m_magic_offset;        // User input offset (e.g., 421)

   // Risk limits
   int               m_max_jobs;            // Max concurrent jobs
   double            m_global_dd_limit;     // Global DD% to stop spawning

   // Dependencies
   CPortfolioLedger *m_ledger;              // Global ledger
   CLogger          *m_log;                 // Logger
   string            m_symbol;              // Trading symbol
   SParams           m_params;              // Strategy parameters

   // Shared resources (all jobs use same instances)
   CSpacingEngine   *m_spacing;             // Spacing calculator
   COrderExecutor   *m_executor;            // Order executor
   CRescueEngine    *m_rescue;              // Rescue engine

   // Helpers
   string            Tag() const { return StringFormat("[RGDv3][%s][JobMgr]", m_symbol); }

public:
   // Constructor
   CJobManager(const string symbol,
               const SParams &params,
               const long magic_start,
               const long magic_offset,
               const int max_jobs,
               const double global_dd_limit,
               CSpacingEngine *spacing,
               COrderExecutor *executor,
               CRescueEngine *rescue,
               CPortfolioLedger *ledger,
               CLogger *logger)
      : m_symbol(symbol),
        m_params(params),
        m_magic_start(magic_start),
        m_magic_offset(magic_offset),
        m_max_jobs(max_jobs),
        m_global_dd_limit(global_dd_limit),
        m_spacing(spacing),
        m_executor(executor),
        m_rescue(rescue),
        m_ledger(ledger),
        m_log(logger),
        m_next_job_id(1)  // Start from 1
     {
      ArrayResize(m_jobs, 0);
     }

   // Destructor
   ~CJobManager()
     {
      // Clean up all jobs
      for(int i = 0; i < ArraySize(m_jobs); i++)
        {
         if(m_jobs[i].controller != NULL)
           {
            delete m_jobs[i].controller;
            m_jobs[i].controller = NULL;
           }
        }
      ArrayResize(m_jobs, 0);
     }

   //+------------------------------------------------------------------+
   //| Magic Number Helpers                                             |
   //+------------------------------------------------------------------+
   long CalculateJobMagic(int job_id)
     {
      // job_id starts from 1
      // Example: start=1000, offset=421
      // Job 1: 1000 + (0 * 421) = 1000
      // Job 2: 1000 + (1 * 421) = 1421
      // Job 3: 1000 + (2 * 421) = 1842
      return m_magic_start + ((job_id - 1) * m_magic_offset);
     }

   int GetJobIdFromMagic(long magic)
     {
      if(magic < m_magic_start)
         return -1;  // Invalid magic

      // Reverse calculation
      int job_id = int((magic - m_magic_start) / m_magic_offset) + 1;
      return job_id;
     }

   //+------------------------------------------------------------------+
   //| Job Lifecycle                                                    |
   //+------------------------------------------------------------------+
   int SpawnJob()
     {
      // Check max jobs limit
      if(ArraySize(m_jobs) >= m_max_jobs)
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("Max jobs reached (%d), cannot spawn", m_max_jobs));
         return -1;
        }

      // Check global DD limit
      if(m_ledger != NULL && m_ledger.GetEquityDrawdownPercent() >= m_global_dd_limit)
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("Global DD %.2f%% >= %.2f%%, spawn blocked",
                                          m_ledger.GetEquityDrawdownPercent(),
                                          m_global_dd_limit));
         return -1;
        }

      // Calculate job magic
      int job_id = m_next_job_id++;
      long job_magic = CalculateJobMagic(job_id);

      // Create job struct
      SJob job;
      job.job_id = job_id;
      job.magic = job_magic;
      job.created_at = TimeCurrent();
      job.status = JOB_ACTIVE;
      job.job_sl_usd = m_params.session_sl_usd;  // Use session SL as job SL (for now)
      job.job_dd_threshold = 30.0;  // Hardcoded for now (TODO: make input)

      // Create lifecycle controller with job magic & job_id
      job.controller = new CLifecycleController(
         m_symbol,
         m_params,
         m_spacing,
         m_executor,
         m_rescue,
         m_ledger,
         m_log,
         job_magic,
         job_id
      );

      // Initialize the controller
      if(job.controller != NULL && !job.controller.Init())
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("Job %d failed to initialize", job_id));

         delete job.controller;
         job.controller = NULL;
         return -1;
        }

      // Add to array
      int new_size = ArraySize(m_jobs) + 1;
      ArrayResize(m_jobs, new_size);
      m_jobs[new_size - 1] = job;

      if(m_log != NULL)
         m_log.Event(Tag(), StringFormat("Job %d spawned (Magic %d) at %s",
                                       job_id, job_magic,
                                       TimeToString(job.created_at)));

      return job_id;
     }

   void StopJob(int job_id, const string reason)
     {
      SJob *job = GetJob(job_id);
      if(job == NULL)
         return;

      if(job.controller != NULL)
        {
         // Close all positions for this job
         job.controller.FlattenAll(reason);
        }

      job.status = JOB_STOPPED;

      if(m_log != NULL)
         m_log.Event(Tag(), StringFormat("Job %d stopped: %s", job_id, reason));
     }

   void UpdateJobs()
     {
      for(int i = 0; i < ArraySize(m_jobs); i++)
        {
         if(m_jobs[i].status != JOB_ACTIVE)
            continue;

         // Update lifecycle (main trading logic)
         if(m_jobs[i].controller != NULL)
            m_jobs[i].controller.Update();

         // Update stats (TODO: add PnL getter methods to LifecycleController)
         // For now, stats will be updated when we add the methods
         // m_jobs[i].unrealized_pnl = m_jobs[i].controller.GetUnrealizedPnL();
         // m_jobs[i].realized_pnl = m_jobs[i].controller.GetRealizedPnL();

         // Update peak equity
         double current_equity = m_jobs[i].realized_pnl + m_jobs[i].unrealized_pnl;
         if(current_equity > m_jobs[i].peak_equity)
            m_jobs[i].peak_equity = current_equity;
        }
     }

   //+------------------------------------------------------------------+
   //| Queries                                                          |
   //+------------------------------------------------------------------+
   int GetActiveJobCount()
     {
      int count = 0;
      for(int i = 0; i < ArraySize(m_jobs); i++)
        {
         if(m_jobs[i].status == JOB_ACTIVE)
            count++;
        }
      return count;
     }

   SJob* GetJob(int job_id)
     {
      for(int i = 0; i < ArraySize(m_jobs); i++)
        {
         if(m_jobs[i].job_id == job_id)
            return &m_jobs[i];
        }
      return NULL;
     }

   SJob* GetNewestJob()
     {
      int size = ArraySize(m_jobs);
      if(size == 0)
         return NULL;
      return &m_jobs[size - 1];
     }
  };

#endif // __RGD_V3_JOB_MANAGER_MQH__
