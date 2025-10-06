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
#include "RangeDetector.mqh"

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

   // Profit optimization (Phase 4)
   double                   profit_target_usd;   // Job TP target
   double                   trail_start_usd;     // Start trailing at
   double                   trail_step_usd;      // Trail step size
   double                   trail_stop_usd;      // Current trailing stop
   bool                     is_trailing;         // Trailing active flag

   // Market adaptation (Phase 4)
   EMarketCondition         market_condition;    // Market state at spawn
   double                   grid_spacing_mult;   // Grid spacing multiplier
   double                   lot_size_mult;        // Lot size multiplier
   int                      optimal_grid_levels; // Optimal levels for market

   // Profit acceleration (Phase 4)
   bool                     acceleration_active;  // Booster mode active
   int                      booster_count;        // Current booster positions
   double                   last_booster_price;   // Last booster price
   datetime                 last_booster_time;    // Last booster timestamp

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
            peak_equity(0),
            profit_target_usd(0),
            trail_start_usd(0),
            trail_step_usd(0),
            trail_stop_usd(0),
            is_trailing(false),
            market_condition(MARKET_UNKNOWN),
            grid_spacing_mult(1.0),
            lot_size_mult(1.0),
            optimal_grid_levels(10),
            acceleration_active(false),
            booster_count(0),
            last_booster_price(0),
            last_booster_time(0)
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

   // Spawn control (Phase 2)
   datetime          m_last_spawn_time;     // Last spawn timestamp
   int               m_total_spawns;        // Total spawns this session
   int               m_spawn_cooldown_sec;  // Cooldown between spawns
   int               m_max_spawns;          // Max spawns per session

   // Job risk params (Phase 3)
   double            m_job_sl_usd;          // Per-job SL in USD
   double            m_job_dd_threshold;    // Per-job DD% abandon threshold

   // Profit optimization params (Phase 4)
   bool              m_smart_close_enabled; // Only close profitable jobs
   double            m_min_profit_to_close; // Min profit to allow close
   double            m_job_tp_usd;          // Job take profit
   double            m_job_trail_start;     // Start trailing at
   double            m_job_trail_step;      // Trail step size

   // Profit acceleration (Phase 4)
   bool              m_profit_accel_enabled; // Enable booster positions
   double            m_booster_threshold;    // Profit threshold to trigger
   double            m_booster_lot_mult;     // Booster lot multiplier
   int               m_max_boosters;         // Max boosters per job

   // Dependencies
   CPortfolioLedger *m_ledger;              // Global ledger
   CLogger          *m_log;                 // Logger
   string            m_symbol;              // Trading symbol
   SParams           m_params;              // Strategy parameters

   // Shared resources (all jobs use same instances)
   CSpacingEngine   *m_spacing;             // Spacing calculator
   COrderExecutor   *m_executor;            // Order executor
   CRescueEngine    *m_rescue;              // Rescue engine
   CRangeDetector   *m_range_detector;      // Range detection (Phase 4)

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
               const int spawn_cooldown_sec,
               const double job_sl_usd,
               const double job_dd_threshold,
               const bool smart_close_enabled,
               const double min_profit_to_close,
               const double job_tp_usd,
               const double job_trail_start,
               const double job_trail_step,
               const bool profit_accel_enabled,
               const double booster_threshold,
               const double booster_lot_mult,
               const int max_boosters,
               CSpacingEngine *spacing,
               COrderExecutor *executor,
               CRescueEngine *rescue,
               CRangeDetector *range_detector,
               CPortfolioLedger *ledger,
               CLogger *logger)
      : m_symbol(symbol),
        m_params(params),
        m_magic_start(magic_start),
        m_magic_offset(magic_offset),
        m_max_jobs(max_jobs),
        m_global_dd_limit(global_dd_limit),
        m_last_spawn_time(0),
        m_total_spawns(0),
        m_spawn_cooldown_sec(spawn_cooldown_sec),
        m_max_spawns(20),
        m_job_sl_usd(job_sl_usd),
        m_job_dd_threshold(job_dd_threshold),
        m_smart_close_enabled(smart_close_enabled),
        m_min_profit_to_close(min_profit_to_close),
        m_job_tp_usd(job_tp_usd),
        m_job_trail_start(job_trail_start),
        m_job_trail_step(job_trail_step),
        m_profit_accel_enabled(profit_accel_enabled),
        m_booster_threshold(booster_threshold),
        m_booster_lot_mult(booster_lot_mult),
        m_max_boosters(max_boosters),
        m_spacing(spacing),
        m_executor(executor),
        m_rescue(rescue),
        m_range_detector(range_detector),
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
      job.job_sl_usd = m_job_sl_usd;
      job.job_dd_threshold = m_job_dd_threshold;

      // Profit optimization settings
      job.profit_target_usd = m_job_tp_usd;
      job.trail_start_usd = m_job_trail_start;
      job.trail_step_usd = m_job_trail_step;
      job.trail_stop_usd = 0;
      job.is_trailing = false;

      // Market adaptation (Phase 4)
      if(m_range_detector != NULL)
        {
         // Update market analysis
         m_range_detector.Update();

         // Get current market condition
         job.market_condition = m_range_detector.GetCondition();
         job.grid_spacing_mult = m_range_detector.GetGridSpacingMultiplier();
         job.lot_size_mult = m_range_detector.GetLotSizeMultiplier();
         job.optimal_grid_levels = m_range_detector.GetOptimalGridLevels();

         // Adapt job parameters based on market
         job.profit_target_usd *= m_range_detector.GetTPMultiplier();

         // Log market adaptation
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("Job %d spawned in %s market: Spacing=%.1fx, Lot=%.1fx, TP=$%.2f, Levels=%d",
                                        job_id,
                                        m_range_detector.ConditionToString(job.market_condition),
                                        job.grid_spacing_mult,
                                        job.lot_size_mult,
                                        job.profit_target_usd,
                                        job.optimal_grid_levels));
        }
      else
        {
         // Default values if no range detector
         job.market_condition = MARKET_UNKNOWN;
         job.grid_spacing_mult = 1.0;
         job.lot_size_mult = 1.0;
         job.optimal_grid_levels = m_params.grid_levels;
        }

      // Create adapted params for this job
      SParams job_params = m_params;  // Copy base params

      // Apply market adaptations
      job_params.grid_levels = job.optimal_grid_levels;
      job_params.lot_base *= job.lot_size_mult;
      job_params.spacing_atr_mult *= job.grid_spacing_mult;
      job_params.target_cycle_usd = job.profit_target_usd;

      // Create lifecycle controller with job magic & adapted params
      job.controller = new CLifecycleController(
         m_symbol,
         job_params,  // Use adapted params
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

      // Track spawn
      m_last_spawn_time = TimeCurrent();
      m_total_spawns++;

      if(m_log != NULL)
         m_log.Event(Tag(), StringFormat("Job %d spawned (Magic %d) at %s [Total spawns: %d]",
                                       job_id, job_magic,
                                       TimeToString(job.created_at),
                                       m_total_spawns));

      return job_id;
     }

   //+------------------------------------------------------------------+
   //| Phase 2 & 3: Spawn and Risk Decision Logic                      |
   //+------------------------------------------------------------------+
   bool ShouldSpawnNew(int job_index)
     {
      if(job_index < 0 || job_index >= ArraySize(m_jobs))
         return false;

      // Guard 1: Check spawn cooldown
      datetime now = TimeCurrent();
      int elapsed = (int)(now - m_last_spawn_time);
      if(elapsed < m_spawn_cooldown_sec)
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("[Spawn] Cooldown active (%d/%d sec)", elapsed, m_spawn_cooldown_sec));
         return false;
        }

      // Guard 2: Check max spawns per session
      if(m_total_spawns >= m_max_spawns)
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("[Spawn] Max spawns reached (%d/%d)", m_total_spawns, m_max_spawns));
         return false;
        }

      // Guard 3: Check global DD limit
      double global_dd = 0.0;
      if(m_ledger != NULL)
         global_dd = m_ledger.GetEquityDrawdownPercent();
      if(global_dd >= m_global_dd_limit)
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("[Spawn] Global DD %.2f%% >= %.2f%%, blocked", global_dd, m_global_dd_limit));
         return false;
        }

      // Trigger: Grid full (ONLY trigger - simplified logic)
      // Reason: TSL adds rescue to existing job (no need to spawn)
      //         DD threshold not needed yet (testing phase)
      if(m_jobs[job_index].controller != NULL && m_jobs[job_index].controller.IsGridFull())
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("[Spawn] Job %d grid full, spawning new job", m_jobs[job_index].job_id));
         return true;
        }

      /* DISABLED: TSL active trigger
      // TSL adds rescue orders to EXISTING job, no need to spawn new job
      if(m_jobs[job_index].controller != NULL && m_jobs[job_index].controller.IsTSLActive())
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("[Spawn] Job %d TSL active, spawning new job", m_jobs[job_index].job_id));
         return true;
        }
      */

      /* DISABLED: Job DD threshold trigger
      // Temporarily disabled - testing grid full trigger only first
      double job_dd_pct = 0.0;
      if(m_jobs[job_index].peak_equity > 0)
        {
         job_dd_pct = (m_jobs[job_index].peak_equity - m_jobs[job_index].unrealized_pnl) / m_jobs[job_index].peak_equity * 100.0;
        }
      if(job_dd_pct >= m_jobs[job_index].job_dd_threshold)
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("[Spawn] Job %d DD %.2f%% >= %.2f%%, spawning new job",
                                          m_jobs[job_index].job_id, job_dd_pct, m_jobs[job_index].job_dd_threshold));
         return true;
        }
      */

      return false;
     }

   bool ShouldStopJob(int job_index)
     {
      if(job_index < 0 || job_index >= ArraySize(m_jobs))
         return false;

      // Stop if unrealized PnL <= -job_sl_usd
      if(m_jobs[job_index].unrealized_pnl <= -m_jobs[job_index].job_sl_usd)
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("[SL] Job %d PnL %.2f <= -%.2f, stopping",
                                          m_jobs[job_index].job_id, m_jobs[job_index].unrealized_pnl, m_jobs[job_index].job_sl_usd));
         return true;
        }
      return false;
     }

   bool ShouldAbandonJob(int job_index)
     {
      if(job_index < 0 || job_index >= ArraySize(m_jobs))
         return false;

      // Abandon if job DD% >= global DD limit (can't be saved)
      double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(account_equity <= 0)
         return false;

      double job_dd_usd = MathAbs(m_jobs[job_index].unrealized_pnl);
      double job_dd_pct = job_dd_usd / account_equity * 100.0;

      if(job_dd_pct >= m_global_dd_limit)
        {
         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("[Abandon] Job %d DD %.2f%% >= %.2f%%, abandoning",
                                          m_jobs[job_index].job_id, job_dd_pct, m_global_dd_limit));
         return true;
        }
      return false;
     }

   void AbandonJob(int job_id)
     {
      int idx = GetJobIndex(job_id);
      if(idx < 0)
         return;

      m_jobs[idx].status = JOB_ABANDONED;

      if(m_log != NULL)
         m_log.Event(Tag(), StringFormat("Job %d abandoned (DD too high, positions kept open)", job_id));
     }

   void CheckProfitAcceleration(int job_index)
     {
      if(job_index < 0 || job_index >= ArraySize(m_jobs))
         return;

      if(m_jobs[job_index].status != JOB_ACTIVE || m_jobs[job_index].controller == NULL)
         return;

      // Check if already at max boosters
      if(m_jobs[job_index].booster_count >= m_max_boosters)
         return;

      // Check cooldown (don't add boosters too fast)
      if(m_jobs[job_index].last_booster_time > 0 && TimeCurrent() - m_jobs[job_index].last_booster_time < 60)
         return;

      // Get winning direction from controller
      double buy_pnl = 0, sell_pnl = 0;
      if(!m_jobs[job_index].controller.GetBasketPnL(buy_pnl, sell_pnl))
         return;

      EDirection winning_dir = (buy_pnl > sell_pnl) ? DIR_BUY : DIR_SELL;

      // Calculate booster lot
      double booster_lot = m_params.lot_base * m_booster_lot_mult * m_jobs[job_index].lot_size_mult;

      // Get current price
      double price = (winning_dir == DIR_BUY) ?
                     SymbolInfoDouble(m_symbol, SYMBOL_ASK) :
                     SymbolInfoDouble(m_symbol, SYMBOL_BID);

      // Deploy booster position
      string comment = StringFormat("RGDv3_J%d_Booster%d", m_jobs[job_index].job_id, m_jobs[job_index].booster_count + 1);

      if(m_jobs[job_index].controller.AddBoosterPosition(winning_dir, booster_lot, comment))
        {
         m_jobs[job_index].booster_count++;
         m_jobs[job_index].last_booster_price = price;
         m_jobs[job_index].last_booster_time = TimeCurrent();
         m_jobs[job_index].acceleration_active = true;

         // Tighten TP for quicker profit
         m_jobs[job_index].profit_target_usd *= 0.7;

         if(m_log != NULL)
            m_log.Event(Tag(), StringFormat("[ACCEL] Job %d added booster #%d: %s %.2f lot at %.5f (PnL=%.2f)",
                                        m_jobs[job_index].job_id, m_jobs[job_index].booster_count,
                                        (winning_dir == DIR_BUY) ? "BUY" : "SELL",
                                        booster_lot, price, m_jobs[job_index].unrealized_pnl));
        }
     }

   void StopJob(int job_id, const string reason)
     {
      int idx = GetJobIndex(job_id);
      if(idx < 0)
         return;

      if(m_jobs[idx].controller != NULL)
        {
         // Close all positions for this job
         m_jobs[idx].controller.FlattenAllPublic(reason);
        }

      m_jobs[idx].status = JOB_STOPPED;

      if(m_log != NULL)
         m_log.Event(Tag(), StringFormat("Job %d stopped: %s", job_id, reason));
     }

   void UpdateJobs()
     {
      // Phase 2 & 3: Full job management loop

      // CRITICAL: Check GLOBAL Session SL FIRST (before any job updates)
      // This prevents multiple jobs from all calling FlattenAll() simultaneously
      if(m_ledger != NULL && m_ledger.SessionRiskBreached())
        {
         if(m_log != NULL)
            m_log.Event(Tag(), "[GLOBAL] Session SL breached - stopping ALL jobs (no new spawns)");

         // Stop all active jobs (no spawn after Session SL)
         for(int i = 0; i < ArraySize(m_jobs); i++)
           {
            if(m_jobs[i].status == JOB_ACTIVE && m_jobs[i].controller != NULL)
              {
               m_jobs[i].controller.FlattenAllPublic("Session SL");
               m_jobs[i].status = JOB_STOPPED;
              }
           }

         // HALT: Do not spawn new jobs after Session SL
         return;
        }

      // FIRST: Check spawn trigger and close OLD job BEFORE it accumulates too much loss
      int newest_idx = GetNewestJobIndex();
      if(newest_idx >= 0 && m_jobs[newest_idx].status == JOB_ACTIVE)
        {
         // Update stats for newest job to check grid full
         if(m_jobs[newest_idx].controller != NULL)
           {
            m_jobs[newest_idx].unrealized_pnl = m_jobs[newest_idx].controller.GetUnrealizedPnL();
            m_jobs[newest_idx].realized_pnl = m_jobs[newest_idx].controller.GetRealizedPnL();
           }

         // Phase 4: SMART CLOSE LOGIC
         // Only close job at grid full if profitable or hit SL
         if(ShouldStopJob(newest_idx))
           {
            StopJob(m_jobs[newest_idx].job_id, StringFormat("Job SL hit: %.2f USD", m_jobs[newest_idx].unrealized_pnl));
            // Don't spawn new job if SL hit (losing scenario)
           }
         else if(ShouldSpawnNew(newest_idx))
           {
            double pnl = m_jobs[newest_idx].unrealized_pnl;
            int old_job_id = m_jobs[newest_idx].job_id;

            // SMART CLOSE: Check if should close based on P&L
            if(m_smart_close_enabled)
              {
               if(pnl >= m_min_profit_to_close)
                 {
                  // Profitable: close and spawn new
                  if(m_log != NULL)
                     m_log.Event(Tag(), StringFormat("[SMART] Closing Job %d (PROFIT %.2f >= %.2f)",
                                                   old_job_id, pnl, m_min_profit_to_close));
                  StopJob(old_job_id, StringFormat("Grid full - PROFIT %.2f", pnl));
                  SpawnJob();
                 }
               else if(pnl > -m_job_sl_usd * 0.5)
                 {
                  // Small loss: keep running, spawn helper job
                  if(m_log != NULL)
                     m_log.Event(Tag(), StringFormat("[SMART] Job %d grid full but LOSING %.2f, spawning HELPER",
                                                   old_job_id, pnl));
                  m_jobs[newest_idx].is_full = true;  // Mark as full
                  SpawnJob();  // Spawn helper job
                 }
               else
                 {
                  // Big loss: keep running, no spawn
                  if(m_log != NULL)
                     m_log.Event(Tag(), StringFormat("[SMART] Job %d grid full but BIG LOSS %.2f, NO ACTION",
                                                   old_job_id, pnl));
                  m_jobs[newest_idx].is_full = true;
                 }
              }
            else
              {
               // Old logic: always close at grid full
               StopJob(old_job_id, "Grid full, spawning new job");
               SpawnJob();
              }
           }
        }

      // SECOND: Update all active jobs
      for(int i = 0; i < ArraySize(m_jobs); i++)
        {
         if(m_jobs[i].status != JOB_ACTIVE)
            continue;

         // 1. Update lifecycle (main trading logic)
         if(m_jobs[i].controller != NULL)
            m_jobs[i].controller.Update();

         // 2. Update job stats
         if(m_jobs[i].controller != NULL)
           {
            m_jobs[i].unrealized_pnl = m_jobs[i].controller.GetUnrealizedPnL();
            m_jobs[i].realized_pnl = m_jobs[i].controller.GetRealizedPnL();
           }

         // 3. Update peak equity
         double current_equity = m_jobs[i].realized_pnl + m_jobs[i].unrealized_pnl;
         if(current_equity > m_jobs[i].peak_equity)
            m_jobs[i].peak_equity = current_equity;

         // 4. Phase 4: Check Job TP (PROFIT TARGET)
         if(m_jobs[i].profit_target_usd > 0 && m_jobs[i].unrealized_pnl >= m_jobs[i].profit_target_usd)
           {
            if(m_log != NULL)
               m_log.Event(Tag(), StringFormat("[TP] Job %d hit profit target %.2f >= %.2f",
                                             m_jobs[i].job_id, m_jobs[i].unrealized_pnl, m_jobs[i].profit_target_usd));
            StopJob(m_jobs[i].job_id, StringFormat("JOB TP HIT: %.2f USD", m_jobs[i].unrealized_pnl));
            SpawnJob();  // Spawn new job after TP
            continue;
           }

         // 5. Phase 4: Check Job Trailing Stop
         if(m_jobs[i].trail_start_usd > 0 && m_jobs[i].unrealized_pnl >= m_jobs[i].trail_start_usd)
           {
            if(!m_jobs[i].is_trailing)
              {
               // Activate trailing
               m_jobs[i].is_trailing = true;
               m_jobs[i].trail_stop_usd = m_jobs[i].unrealized_pnl - m_jobs[i].trail_step_usd;
               if(m_log != NULL)
                  m_log.Event(Tag(), StringFormat("[TRAIL] Job %d activated trailing at %.2f, stop at %.2f",
                                                m_jobs[i].job_id, m_jobs[i].unrealized_pnl, m_jobs[i].trail_stop_usd));
              }
            else
              {
               // Update trailing stop
               double new_stop = m_jobs[i].unrealized_pnl - m_jobs[i].trail_step_usd;
               if(new_stop > m_jobs[i].trail_stop_usd)
                 {
                  m_jobs[i].trail_stop_usd = new_stop;
                  if(m_log != NULL)
                     m_log.Event(Tag(), StringFormat("[TRAIL] Job %d updated stop to %.2f",
                                                   m_jobs[i].job_id, m_jobs[i].trail_stop_usd));
                 }

               // Check if trail stop hit
               if(m_jobs[i].unrealized_pnl <= m_jobs[i].trail_stop_usd)
                 {
                  if(m_log != NULL)
                     m_log.Event(Tag(), StringFormat("[TRAIL] Job %d stop hit at %.2f",
                                                   m_jobs[i].job_id, m_jobs[i].unrealized_pnl));
                  StopJob(m_jobs[i].job_id, StringFormat("TRAIL STOP HIT: %.2f USD", m_jobs[i].unrealized_pnl));
                  SpawnJob();  // Spawn new after trail stop
                  continue;
                 }
              }
           }

         // 6. Phase 4: Check Profit Acceleration (BOOSTER)
         if(m_profit_accel_enabled && m_jobs[i].unrealized_pnl >= m_booster_threshold)
           {
            CheckProfitAcceleration(i);
           }

         // 7. Check risk conditions (Phase 3) - Job SL protection
         if(ShouldStopJob(i))
           {
            StopJob(m_jobs[i].job_id, StringFormat("SL hit: %.2f USD", m_jobs[i].unrealized_pnl));

            // CRITICAL: Spawn new job after SL (like we do for TP)
            // Don't leave EA idle after one job fails!
            if(m_log != NULL)
               m_log.Event(Tag(), StringFormat("[RESPAWN] Job %d hit SL, spawning replacement job", m_jobs[i].job_id));
            SpawnJob();

            continue;
           }

         if(ShouldAbandonJob(i))
           {
            AbandonJob(m_jobs[i].job_id);
            continue;
           }
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

   int GetJobIndex(int job_id)
     {
      for(int i = 0; i < ArraySize(m_jobs); i++)
        {
         if(m_jobs[i].job_id == job_id)
            return i;
        }
      return -1;
     }

   int GetNewestJobIndex()
     {
      int size = ArraySize(m_jobs);
      if(size == 0)
         return -1;
      return size - 1;
     }
  };

#endif // __RGD_V3_JOB_MANAGER_MQH__
