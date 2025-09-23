//+------------------------------------------------------------------+
//|  mAIshe V27.3 (Final Encapsulation Fix)                          |
//|                      Copyright 2025, The Pro Trader              |
//|  - Corrected final undeclared identifier by encapsulating params |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, The Pro Trader"
#property link      "https://www.forexfactory.com"
#property version   "27.3" // Final Encapsulation Fix
#property strict

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>

//--- CTrade & CAccountInfo instances
CTrade trade;
CAccountInfo account;

//--- Enumerations
enum ENUM_HTF_COUNT
{
   HTF_COUNT_1 = 1,
   HTF_COUNT_2 = 2,
   HTF_COUNT_3 = 3
};
enum ENUM_IMPACT_LEVEL { IMPACT_HIGH, IMPACT_MEDIUM, IMPACT_LOW, IMPACT_ANY };

//--- EA Inputs
input group "Global Trade Settings"
input bool   EnableTrendStrategy       = true;         // MASTER SWITCH for Trend-Following Strategy
input bool   EnableDayTradingStrategy  = false;        // MASTER SWITCH for Day Trading Strategy
input bool   AllowHedging              = false;        // If true, EA can open buy and sell trades at the same time
input bool   EnableAdaptiveRisk      = true;             // MASTER SWITCH to enable using Prime Risk % on A+ setups

input group "Global Risk Management"
input double MaxTotalRiskPercent     = 4.0;              // Max total risk across ALL open/pending trades on THIS symbol
//---
input group "Daily and Weekly Kill-Switch"
input bool   EnableProfitLossLimits  = true;
input double MaxDailyLossPercent     = 3.0;
input double MaxDailyProfitPercent   = 10.0;
input double MaxWeeklyProfitPercent  = 20.0;
//---
input group "Drawdown Kill-Switch"
input bool   EnableMaxDrawdownStop   = true;             // Enable stopping trades based on peak equity drawdown
input double MaxDrawdownPercent      = 10.0;             // If equity drops X% from its peak, stop all trading for the week
//---
input group "Portfolio / Correlation Risk Overlay"
input bool   EnableCorrelationRiskManager = false;       // If true, EA will manage risk across a portfolio of symbols
input string CorrelatedSymbols       = "EURUSD,GBPUSD,AUDUSD"; // Comma-separated list of symbols to manage together
input double MaxCorrelatedRiskPercent= 1.0;              // Max total risk across ALL correlated symbols

input group "Trade Execution Settings"
input ulong  MaxSlippagePoints         = 30;           // Max allowed slippage for market orders (in points)
input double MaxSpreadPips             = 3.0;          // Abort trade if spread exceeds this (in pips)
input uint   SimulatedSlippagePoints   = 2;            // For backtesting: simulate X points of slippage on pending orders
input int    OrderRetries              = 3;            // Number of retries on requote/server error
input int    RetryDelayMs              = 250;          // Milliseconds to wait between retries

input group "Telemetry / Logging"
input bool   EnableCsvLogging        = true;             // If true, logs all decisions to a CSV file
input string CsvLogFileName          = "mAIshe_Log.csv"; // Log file name (in MQL5/Files)


//--- TREND STRATEGY INPUTS ---
input group "--- Trend Strategy ---"
//---
input group "Trend :: Basic Settings"
input ENUM_TIMEFRAMES Trend_Timeframe = PERIOD_H1;      // Entry timeframe for trend strategy
input double Trend_RiskPerEntryPercent = 0.5;
input double Trend_PrimeRiskPercentage = 1.0;            // Risk % for A+ setups
input double Trend_BaseTakeProfitRR    = 4.0;
//---
input group "Trend :: Advanced Settings"
input int    Trend_AtrPeriod           = 14;
input int    Trend_MaxRunningTrades    = 6;
input int    MagicNumber_Trend         = 12345;
input double Trend_BaseSlAtrMult       = 0.5;
input double Trend_MinPullbackAtrMult  = 1.0;
//---
input group "Trend :: Advanced Multi-Timeframe Confluence"
input bool   Trend_EnableMultiHtfFilter = true;
input ENUM_HTF_COUNT Trend_NumberOfHtfs = HTF_COUNT_3;
input ENUM_TIMEFRAMES Trend_Htf1_Timeframe = PERIOD_D1;
input ENUM_TIMEFRAMES Trend_Htf2_Timeframe = PERIOD_H4;
input ENUM_TIMEFRAMES Trend_Htf3_Timeframe = PERIOD_H1;
//---
input group "Trend :: Advanced Multi-Timeframe EMA Filters"
input bool   Trend_Htf1_EnableEmaFilter = true;
input int    Trend_Htf1_EmaPeriod       = 50;
input ENUM_MA_METHOD Trend_Htf1_EmaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE Trend_Htf1_EmaPrice = PRICE_CLOSE;
input bool   Trend_Htf2_EnableEmaFilter = true;
input int    Trend_Htf2_EmaPeriod       = 50;
input ENUM_MA_METHOD Trend_Htf2_EmaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE Trend_Htf2_EmaPrice = PRICE_CLOSE;
input bool   Trend_Htf3_EnableEmaFilter = true;
input int    Trend_Htf3_EmaPeriod       = 50;
input ENUM_MA_METHOD Trend_Htf3_EmaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE Trend_Htf3_EmaPrice = PRICE_CLOSE;
//---
input group "Trend :: Advanced Adaptive Parameters"
input double Trend_LowVolRRMultiplier     = 0.75;
input double Trend_HighVolRRMultiplier    = 1.5;
input double Trend_HighVolSlAtrMultiplier = 1.25;
input double Trend_ImpulseCandleMultiplier = 1.5;
input int    Trend_AvgBodyPeriod           = 50;
input double Trend_SwingConfirmationAtrMult = 0.5;
//---
input group "Trend :: Advanced LTF Confirmation"
input bool   Trend_EnableEmaFilter = true;
input int    Trend_EmaFilterPeriod = 50;
input ENUM_MA_METHOD Trend_EmaFilterMethod = MODE_EMA;
input ENUM_APPLIED_PRICE Trend_EmaFilterPrice = PRICE_CLOSE;


//--- DAY TRADING STRATEGY INPUTS ---
input group "--- Day Trading Strategy ---"
//---
input group "DayTrade :: Basic Settings"
input ENUM_TIMEFRAMES DayTrade_Timeframe = PERIOD_M5; // Entry timeframe for day trading strategy
input double DayTrade_RiskPerEntryPercent = 0.5;
input double DayTrade_PrimeRiskPercentage = 1.0;       // Risk % for A+ setups
input double DayTrade_BaseTakeProfitRR    = 3.0;
//---
input group "DayTrade :: Advanced Settings"
input int    DayTrade_AtrPeriod           = 14;
input int    DayTrade_MaxRunningTrades    = 4;
input int    MagicNumber_DayTrade         = 67890;
input double DayTrade_BaseSlAtrMult       = 0.5;
input double DayTrade_MinPullbackAtrMult  = 1.0;
//---
input group "DayTrade :: Time & Session Filters"
input bool   DayTrade_EnableTimeFilter            = true;
input int    DayTrade_TradeAllowedFromHour        = 9;          // Server hour to start trading
input int    DayTrade_TradeAllowedToHour          = 17;         // Server hour to stop trading
input int    DayTrade_BlockMinutesAfterMarketOpen = 15;         // Don't trade for N minutes after daily bar open
//---
input group "DayTrade :: News Filter"
input bool   DayTrade_EnableNewsFilter          = true;
input int    DayTrade_MinutesBeforeNewsStop     = 30;
input int    DayTrade_MinutesAfterNewsResume    = 30;
input bool   DayTrade_FilterHighImpact          = true;
input bool   DayTrade_FilterMediumImpact        = false;
input bool   DayTrade_FilterLowImpact           = false;
input string DayTrade_NewsURL                   = "https://www.forexfactory.com/calendar";
//---
input group "DayTrade :: Advanced Multi-Timeframe Confluence"
input bool   DayTrade_EnableMultiHtfFilter = true;
input ENUM_HTF_COUNT DayTrade_NumberOfHtfs = HTF_COUNT_3;
input ENUM_TIMEFRAMES DayTrade_Htf1_Timeframe = PERIOD_H4;
input ENUM_TIMEFRAMES DayTrade_Htf2_Timeframe = PERIOD_H1;
input ENUM_TIMEFRAMES DayTrade_Htf3_Timeframe = PERIOD_M15;
//---
input group "DayTrade :: Advanced Multi-Timeframe EMA Filters"
input bool   DayTrade_Htf1_EnableEmaFilter = true;
input int    DayTrade_Htf1_EmaPeriod       = 50;
input ENUM_MA_METHOD DayTrade_Htf1_EmaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE DayTrade_Htf1_EmaPrice = PRICE_CLOSE;
input bool   DayTrade_Htf2_EnableEmaFilter = true;
input int    DayTrade_Htf2_EmaPeriod       = 50;
input ENUM_MA_METHOD DayTrade_Htf2_EmaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE DayTrade_Htf2_EmaPrice = PRICE_CLOSE;
input bool   DayTrade_Htf3_EnableEmaFilter = true;
input int    DayTrade_Htf3_EmaPeriod       = 50;
input ENUM_MA_METHOD DayTrade_Htf3_EmaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE DayTrade_Htf3_EmaPrice = PRICE_CLOSE;
//---
input group "DayTrade :: Advanced Adaptive Parameters"
input double DayTrade_LowVolRRMultiplier     = 0.75;
input double DayTrade_HighVolRRMultiplier    = 1.5;
input double DayTrade_HighVolSlAtrMultiplier = 1.25;
input double DayTrade_ImpulseCandleMultiplier = 1.5;
input int    DayTrade_AvgBodyPeriod           = 50;
input double DayTrade_SwingConfirmationAtrMult = 0.5;
//---
input group "DayTrade :: Advanced LTF Confirmation"
input bool   DayTrade_EnableEmaFilter = true;
input int    DayTrade_EmaFilterPeriod = 50;
input ENUM_MA_METHOD DayTrade_EmaFilterMethod = MODE_EMA;
input ENUM_APPLIED_PRICE DayTrade_EmaFilterPrice = PRICE_CLOSE;


input group "Institutional Trade Management"
input bool   EnableAdvancedManagement = true;
input double BreakEvenTriggerR      = 1.5;
input int    RunnerAtrPeriod        = 14;
input double RunnerAtrMultiplier    = 2.0;

input group "Volatility Regime Filter"
input bool   EnableVolatilityFilter     = true;
input ENUM_TIMEFRAMES VolatilityFilterTimeframe = PERIOD_H4;
int          LongAtrPeriod            = 100;
double       MinVolatilityMultiplier    = 0.6;
double       MaxVolatilityMultiplier    = 3.0;

input group "Dynamic Volatility Engine"
input bool   EnableVolatilityEngine     = true;
double       Volatility_LowThreshold    = 0.7;
double       Volatility_NormalThreshold = 1.5;
double       Volatility_HighThreshold   = 3.0;

input group "Display Settings"
input bool   ShowDashboard = true;

//--- Global Handles and State
int      runnerAtrHandle;
int      longAtrHandle;
int      shortAtrOnHtfHandle;
int      hLogFile; // Handle for the log file

//--- Global Enums
enum ENUM_TREND { NO_TREND, UP, DOWN };
enum ENUM_STATE { TRACKING_IMPULSE, AWAITING_CONTINUATION };
enum ENUM_VOLATILITY_REGIME { VOL_LOW, VOL_NORMAL, VOL_HIGH, VOL_EXTREME };
enum ENUM_MANAGE_PHASE { PHASE_INITIAL, PHASE_BREAKEVEN, PHASE_RUNNER };

//--- Global Structs
struct SwingPoint { double price; datetime time; };

struct TimeframeState
{
   ENUM_TREND      currentTrend;
   ENUM_STATE      currentState;
   SwingPoint      swingLowAnchor;
   SwingPoint      swingHighAnchor;
   SwingPoint      currentImpulseHigh;
   SwingPoint      currentImpulseLow;
   SwingPoint      currentPullbackLow;
   SwingPoint      currentPullbackHigh;
   ENUM_TIMEFRAMES timeframe;
   datetime        lastBarTime;
   string          objectPrefix;
   int             emaHandle;
   datetime        lastBmsTime;
   datetime        lastChochTime;
};

struct StrategyContext
{
    // Configuration
    bool              isEnabled;
    long              magicNumber;
    string            name;
    ENUM_TIMEFRAMES   entryTimeframe;
    double            riskPerEntryPercent;
    double            primeRiskPercentage;
    int               maxRunningTrades;
    double            baseTakeProfitRR;
    double            baseSlAtrMult;
    double            minPullbackAtrMult;
    int               atrPeriod;
    double            swingConfirmationAtrMult;
    int               avgBodyPeriod;
    double            impulseCandleMultiplier;
    bool              enableEmaFilter;
    int               emaFilterPeriod;
    ENUM_MA_METHOD    emaFilterMethod;
    ENUM_APPLIED_PRICE emaFilterPrice;

    // Independent Time Filter Settings
    bool              enableTimeFilter;
    int               tradeAllowedFromHour;
    int               tradeAllowedToHour;
    int               blockMinutesAfterMarketOpen;
    
    // News Filter Settings
    bool              enableNewsFilter;
    int               minutesBeforeNewsStop;
    int               minutesAfterNewsResume;
    bool              filterHighImpact;
    bool              filterMediumImpact;
    bool              filterLowImpact;

    // Independent HTF configuration and state
    bool              enableMultiHtfFilter;
    ENUM_HTF_COUNT    numberOfHtfs;
    TimeframeState    htfStates[3];
    ENUM_TIMEFRAMES   htfTimeframes[3];
    bool              htfEnableEmaFilter[3];
    int               htfEmaPeriod[3];
    ENUM_MA_METHOD    htfEmaMethod[3];
    ENUM_APPLIED_PRICE htfEmaPrice[3];
    
    // Independent Adaptive Parameters
    double            lowVolRRMultiplier;
    double            highVolRRMultiplier;
    double            highVolSlAtrMultiplier;

    // State
    ENUM_TREND        currentTrend;
    ENUM_STATE        currentState;
    SwingPoint        swingLowAnchor;
    SwingPoint        swingHighAnchor;
    SwingPoint        currentImpulseHigh;
    SwingPoint        currentImpulseLow;
    SwingPoint        currentPullbackLow;
    SwingPoint        currentPullbackHigh;
    datetime          lastTradeSetupTime;
    datetime          lastBarTime;
    
    // Handles
    int               atrHandle;
    int               emaHandle;
};

struct ManagedPosition
{
   ulong             ticket;
   double            initialRiskPoints;
   double            entryPrice;
   ENUM_MANAGE_PHASE managementPhase;
};

struct NewsEvent
{
   datetime time;
   string currency;
   ENUM_IMPACT_LEVEL impact;
   string title;
};

//--- State Variables
ManagedPosition        ManagedPositions[];
NewsEvent              UpcomingNews[];
datetime               lastNewsFetchTime = 0;
ENUM_VOLATILITY_REGIME CurrentVolatilityRegime = VOL_NORMAL;
double                 currentVolatilityIndex  = 1.0;
datetime               currentDayStart;
datetime               currentWeekStart;
double                 startOfDayBalance;
double                 startOfWeekBalance;
double                 peakEquity; // For max drawdown tracking
bool                   isTradingStoppedForDay  = false;
bool                   isTradingStoppedForWeek = false;
bool                   isVolatilityFilterActive = true;
bool                   isNewsBlockActive = false;


//--- Strategy Context Instances
StrategyContext TrendStrategy;
StrategyContext DayTradeStrategy;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- Global Initializations ---
   runnerAtrHandle = iATR(_Symbol, _Period, RunnerAtrPeriod);
   
   isVolatilityFilterActive = EnableVolatilityFilter;
   if(isVolatilityFilterActive)
   {
      longAtrHandle = iATR(_Symbol, VolatilityFilterTimeframe, LongAtrPeriod);
      shortAtrOnHtfHandle = iATR(_Symbol, VolatilityFilterTimeframe, LongAtrPeriod); // Use same long period for consistency
      if(longAtrHandle == INVALID_HANDLE || shortAtrOnHtfHandle == INVALID_HANDLE)
      {
         Print("Error creating ATR indicator handles for volatility filter. Disabling feature.");
         isVolatilityFilterActive = false;
      }
   }

   // --- Initialize Strategy Contexts ---
   InitializeStrategyContext(TrendStrategy, "Trend", EnableTrendStrategy, MagicNumber_Trend, Trend_Timeframe, Trend_RiskPerEntryPercent, Trend_PrimeRiskPercentage, Trend_MaxRunningTrades, Trend_BaseTakeProfitRR, Trend_BaseSlAtrMult, Trend_MinPullbackAtrMult, Trend_AtrPeriod, Trend_SwingConfirmationAtrMult, Trend_AvgBodyPeriod, Trend_ImpulseCandleMultiplier, Trend_EnableEmaFilter, Trend_EmaFilterPeriod, Trend_EmaFilterMethod, Trend_EmaFilterPrice, false, 0, 0, 0, false,0,0,false,false,false, Trend_EnableMultiHtfFilter, Trend_NumberOfHtfs, Trend_Htf1_Timeframe, Trend_Htf2_Timeframe, Trend_Htf3_Timeframe, Trend_Htf1_EnableEmaFilter, Trend_Htf2_EnableEmaFilter, Trend_Htf3_EnableEmaFilter, Trend_Htf1_EmaPeriod, Trend_Htf2_EmaPeriod, Trend_Htf3_EmaPeriod, Trend_Htf1_EmaMethod, Trend_Htf2_EmaMethod, Trend_Htf3_EmaMethod, Trend_Htf1_EmaPrice, Trend_Htf2_EmaPrice, Trend_Htf3_EmaPrice, Trend_LowVolRRMultiplier, Trend_HighVolRRMultiplier, Trend_HighVolSlAtrMultiplier);
   InitializeStrategyContext(DayTradeStrategy, "DayTrade", EnableDayTradingStrategy, MagicNumber_DayTrade, DayTrade_Timeframe, DayTrade_RiskPerEntryPercent, DayTrade_PrimeRiskPercentage, DayTrade_MaxRunningTrades, DayTrade_BaseTakeProfitRR, DayTrade_BaseSlAtrMult, DayTrade_MinPullbackAtrMult, DayTrade_AtrPeriod, DayTrade_SwingConfirmationAtrMult, DayTrade_AvgBodyPeriod, DayTrade_ImpulseCandleMultiplier, DayTrade_EnableEmaFilter, DayTrade_EmaFilterPeriod, DayTrade_EmaFilterMethod, DayTrade_EmaFilterPrice, DayTrade_EnableTimeFilter, DayTrade_TradeAllowedFromHour, DayTrade_TradeAllowedToHour, DayTrade_BlockMinutesAfterMarketOpen, DayTrade_EnableNewsFilter, DayTrade_MinutesBeforeNewsStop, DayTrade_MinutesAfterNewsResume, DayTrade_FilterHighImpact, DayTrade_FilterMediumImpact, DayTrade_FilterLowImpact, DayTrade_EnableMultiHtfFilter, DayTrade_NumberOfHtfs, DayTrade_Htf1_Timeframe, DayTrade_Htf2_Timeframe, DayTrade_Htf3_Timeframe, DayTrade_Htf1_EnableEmaFilter, DayTrade_Htf2_EnableEmaFilter, DayTrade_Htf3_EnableEmaFilter, DayTrade_Htf1_EmaPeriod, DayTrade_Htf2_EmaPeriod, DayTrade_Htf3_EmaPeriod, DayTrade_Htf1_EmaMethod, DayTrade_Htf2_EmaMethod, DayTrade_Htf3_EmaMethod, DayTrade_Htf1_EmaPrice, DayTrade_Htf2_EmaPrice, DayTrade_Htf3_EmaPrice, DayTrade_LowVolRRMultiplier, DayTrade_HighVolRRMultiplier, DayTrade_HighVolSlAtrMultiplier);
   
   // --- Final Setup ---
   TimeCurrent();
   currentDayStart = TimeCurrent() - (TimeCurrent() % 86400);
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   int day_of_week = dt.day_of_week == 0 ? 7 : dt.day_of_week;
   currentWeekStart = TimeCurrent() - ((day_of_week - 1) * 86400) - (TimeCurrent() % 86400);
   startOfDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   startOfWeekBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   ObjectsDeleteAll(0, "EA_");
   if(TrendStrategy.isEnabled) InitializeStrategyStateFromHistory(TrendStrategy);
   if(DayTradeStrategy.isEnabled) InitializeStrategyStateFromHistory(DayTradeStrategy);
   
   if(DayTradeStrategy.isEnabled && DayTradeStrategy.enableNewsFilter) FetchNewsData();
   
   if(EnableCsvLogging)
   {
      hLogFile = FileOpen(CsvLogFileName, FILE_WRITE|FILE_SHARE_READ|FILE_CSV, ",");
      if(hLogFile == INVALID_HANDLE) Print("Error opening log file! Logging disabled.");
      else
      {
         // Write header if file is new/empty
         if(FileSize(hLogFile) == 0)
         {
            FileWrite(hLogFile, "Timestamp", "Strategy", "Decision", "Symbol", "Reason", "Details", "RiskPercent", "LotSize");
         }
      }
   }
     
   return(INIT_SUCCEEDED);
}

void InitializeStrategyContext(StrategyContext &context, string name, bool isEnabled, long magic, ENUM_TIMEFRAMES tf, double risk, double prime_risk, int maxTrades, double rr, double slMult, double pbMult, int atrP, double swingAtrMult, int avgBodyP, double impulseMult, bool emaEnabled, int emaPeriod, ENUM_MA_METHOD emaMethod, ENUM_APPLIED_PRICE emaPrice, bool timeFilter, int fromHour, int toHour, int blockMins, bool newsFilter, int beforeNews, int afterNews, bool high, bool med, bool low, bool htfEnabled, ENUM_HTF_COUNT numHtfs, ENUM_TIMEFRAMES htf1, ENUM_TIMEFRAMES htf2, ENUM_TIMEFRAMES htf3, bool htf1Ema, bool htf2Ema, bool htf3Ema, int htf1EmaP, int htf2EmaP, int htf3EmaP, ENUM_MA_METHOD htf1EmaM, ENUM_MA_METHOD htf2EmaM, ENUM_MA_METHOD htf3EmaM, ENUM_APPLIED_PRICE htf1EmaPr, ENUM_APPLIED_PRICE htf2EmaPr, ENUM_APPLIED_PRICE htf3EmaPr, double lowVolRR, double highVolRR, double highVolSl)
{
    context.isEnabled = isEnabled;
    context.name = name;
    if(!context.isEnabled) return;

    // Core
    context.magicNumber = magic;
    context.entryTimeframe = tf;
    context.riskPerEntryPercent = risk;
    context.primeRiskPercentage = prime_risk;
    context.maxRunningTrades = maxTrades;
    context.baseTakeProfitRR = rr;
    context.baseSlAtrMult = slMult;
    context.minPullbackAtrMult = pbMult;
    context.atrPeriod = atrP;
    context.swingConfirmationAtrMult = swingAtrMult;
    context.avgBodyPeriod = avgBodyP;
    context.impulseCandleMultiplier = impulseMult;
    
    // LTF EMA
    context.enableEmaFilter = emaEnabled;
    context.emaFilterPeriod = emaPeriod;
    context.emaFilterMethod = emaMethod;
    context.emaFilterPrice = emaPrice;
    
    // Time Filters
    context.enableTimeFilter = timeFilter;
    context.tradeAllowedFromHour = fromHour;
    context.tradeAllowedToHour = toHour;
    context.blockMinutesAfterMarketOpen = blockMins;
    
    // News Filter
    context.enableNewsFilter = newsFilter;
    context.minutesBeforeNewsStop = beforeNews;
    context.minutesAfterNewsResume = afterNews;
    context.filterHighImpact = high;
    context.filterMediumImpact = med;
    context.filterLowImpact = low;
    
    // HTF
    context.enableMultiHtfFilter = htfEnabled;
    context.numberOfHtfs = numHtfs;
    context.htfTimeframes[0] = htf1; context.htfTimeframes[1] = htf2; context.htfTimeframes[2] = htf3;
    context.htfEnableEmaFilter[0] = htf1Ema; context.htfEnableEmaFilter[1] = htf2Ema; context.htfEnableEmaFilter[2] = htf3Ema;
    context.htfEmaPeriod[0] = htf1EmaP; context.htfEmaPeriod[1] = htf2EmaP; context.htfEmaPeriod[2] = htf3EmaP;
    context.htfEmaMethod[0] = htf1EmaM; context.htfEmaMethod[1] = htf2EmaM; context.htfEmaMethod[2] = htf3EmaM;
    context.htfEmaPrice[0] = htf1EmaPr; context.htfEmaPrice[1] = htf2EmaPr; context.htfEmaPrice[2] = htf3EmaPr;

    // Adaptive
    context.lowVolRRMultiplier = lowVolRR;
    context.highVolRRMultiplier = highVolRR;
    context.highVolSlAtrMultiplier = highVolSl;
    
    // Handles
    context.atrHandle = iATR(_Symbol, context.entryTimeframe, context.atrPeriod);
    context.emaHandle = context.enableEmaFilter ? iMA(_Symbol, context.entryTimeframe, context.emaFilterPeriod, 0, context.emaFilterMethod, context.emaFilterPrice) : INVALID_HANDLE;
    
    string prefix = (magic == MagicNumber_Trend ? "T_" : "D_");
    context.htfStates[0].timeframe = context.htfTimeframes[0]; context.htfStates[0].objectPrefix = prefix + "HTF1_"; context.htfStates[0].emaHandle = context.htfEnableEmaFilter[0] ? iMA(_Symbol, context.htfTimeframes[0], context.htfEmaPeriod[0], 0, context.htfEmaMethod[0], context.htfEmaPrice[0]) : INVALID_HANDLE;
    context.htfStates[1].timeframe = context.htfTimeframes[1]; context.htfStates[1].objectPrefix = prefix + "HTF2_"; context.htfStates[1].emaHandle = context.htfEnableEmaFilter[1] ? iMA(_Symbol, context.htfTimeframes[1], context.htfEmaPeriod[1], 0, context.htfEmaMethod[1], context.htfEmaPrice[1]) : INVALID_HANDLE;
    context.htfStates[2].timeframe = context.htfTimeframes[2]; context.htfStates[2].objectPrefix = prefix + "HTF3_"; context.htfStates[2].emaHandle = context.htfEnableEmaFilter[2] ? iMA(_Symbol, context.htfTimeframes[2], context.htfEmaPeriod[2], 0, context.htfEmaMethod[2], context.htfEmaPrice[2]) : INVALID_HANDLE;

    for(int i=0; i<(int)context.numberOfHtfs; i++) InitializeHtfStateFromHistory(context.htfStates[i], context);
}


//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) 
{
   ObjectsDeleteAll(0, "EA_");
   // Release global handles
   if(runnerAtrHandle != INVALID_HANDLE) IndicatorRelease(runnerAtrHandle);
   if(longAtrHandle != INVALID_HANDLE) IndicatorRelease(longAtrHandle);
   if(shortAtrOnHtfHandle != INVALID_HANDLE) IndicatorRelease(shortAtrOnHtfHandle);
   
   // --- Release Trend Strategy Handles ---
   if(TrendStrategy.isEnabled)
   {
       if(TrendStrategy.atrHandle != INVALID_HANDLE) IndicatorRelease(TrendStrategy.atrHandle);
       if(TrendStrategy.emaHandle != INVALID_HANDLE) IndicatorRelease(TrendStrategy.emaHandle);
       for(int i=0; i<3; i++) if(TrendStrategy.htfStates[i].emaHandle != INVALID_HANDLE) IndicatorRelease(TrendStrategy.htfStates[i].emaHandle);
   }
   
   // --- Release DayTrade Strategy Handles ---
   if(DayTradeStrategy.isEnabled)
   {
       if(DayTradeStrategy.atrHandle != INVALID_HANDLE) IndicatorRelease(DayTradeStrategy.atrHandle);
       if(DayTradeStrategy.emaHandle != INVALID_HANDLE) IndicatorRelease(DayTradeStrategy.emaHandle);
       for(int i=0; i<3; i++) if(DayTradeStrategy.htfStates[i].emaHandle != INVALID_HANDLE) IndicatorRelease(DayTradeStrategy.htfStates[i].emaHandle);
   }
   
   if(hLogFile != INVALID_HANDLE) FileClose(hLogFile);
}

//+------------------------------------------------------------------+
//| OnTick - Main Loop                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(ShowDashboard) UpdateDashboard();
   if(EnableVolatilityEngine) UpdateVolatilityRegime();
   
   // --- Manage News ---
   if(DayTradeStrategy.isEnabled && DayTradeStrategy.enableNewsFilter)
   {
      // Fetch news data periodically (e.g., every hour)
      if(TimeCurrent() - lastNewsFetchTime >= 3600) FetchNewsData();
      ManageNewsClosures();
      isNewsBlockActive = IsInNewsEmbargo();
   }

   // --- Global Kill Switches ---
   CheckMaxDrawdown();
   if(EnableProfitLossLimits) CheckProfitLossLimits();
   
   if(isTradingStoppedForDay || isTradingStoppedForWeek) return;
   
   // --- Trade Management ---
   if(EnableAdvancedManagement) ManageOpenPositions();
     
   // --- STRATEGY-SPECIFIC LOGIC ---
   if(TrendStrategy.isEnabled)
   {
       RunStrategyCycle(TrendStrategy);
   }
   
   if(DayTradeStrategy.isEnabled)
   {
       RunStrategyCycle(DayTradeStrategy);
   }
}

void RunStrategyCycle(StrategyContext &context)
{
    // Analyze this strategy's HTFs
    for(int i=0; i < (int)context.numberOfHtfs; i++)
    {
        datetime newHtfBarTime = (datetime)SeriesInfoInteger(_Symbol, context.htfStates[i].timeframe, SERIES_LASTBAR_DATE);
        if(newHtfBarTime != context.htfStates[i].lastBarTime)
        {
            context.htfStates[i].lastBarTime = newHtfBarTime;
            AnalyzeHtfMarketStructure(context.htfStates[i], context);
        }
    }
    // Check for new bar on entry timeframe and run its logic
    datetime newBarTime = (datetime)SeriesInfoInteger(_Symbol, context.entryTimeframe, SERIES_LASTBAR_DATE);
    if(newBarTime != context.lastBarTime)
    {
        context.lastBarTime = newBarTime;
        AnalyzeStrategyContinuation(context);
    }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction                                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // This function can be used for custom logic after a trade transaction
}

//+------------------------------------------------------------------+
//| STRATEGY LOGIC                                                   |
//+------------------------------------------------------------------+
void AnalyzeStrategyContinuation(StrategyContext &context)
{ 
   MqlRates rates[]; if(CopyRates(_Symbol, context.entryTimeframe, 0, 5, rates) < 5) return; ArraySetAsSeries(rates, true);
   MqlRates pivot_bar = rates[2];
   double currentAtr = GetAtrValue(context.atrHandle); if(currentAtr == 0) return;
   
   if(context.currentState == TRACKING_IMPULSE){ if(context.currentTrend == UP){ if(pivot_bar.high > context.currentImpulseHigh.price) { context.currentImpulseHigh.price = pivot_bar.high;
   context.currentImpulseHigh.time = pivot_bar.time;
   } if(IsUpTrendPullback(0, context) && pivot_bar.time > context.lastTradeSetupTime) { double pullbackDepth = (context.currentImpulseHigh.price - pivot_bar.low);
   if(pullbackDepth >= context.minPullbackAtrMult * currentAtr){ context.currentPullbackLow.price = pivot_bar.low; context.currentPullbackLow.time = pivot_bar.time; context.lastTradeSetupTime = pivot_bar.time; context.currentState = AWAITING_CONTINUATION; if(IsValidPullbackStructure(2, UP, context)) PlaceStrategyTrade(context);
   } } } else if(context.currentTrend == DOWN){ if(pivot_bar.low < context.currentImpulseLow.price) { context.currentImpulseLow.price = pivot_bar.low; context.currentImpulseLow.time = pivot_bar.time;
   } if(IsDownTrendPullback(0, context) && pivot_bar.time > context.lastTradeSetupTime){ double pullbackDepth = (pivot_bar.high - context.currentImpulseLow.price); if(pullbackDepth >= context.minPullbackAtrMult * currentAtr){ context.currentPullbackHigh.price = pivot_bar.high;
   context.currentPullbackHigh.time = pivot_bar.time; context.lastTradeSetupTime = pivot_bar.time; context.currentState = AWAITING_CONTINUATION; if(IsValidPullbackStructure(2, DOWN, context)) PlaceStrategyTrade(context);
   } } } } else if(context.currentState == AWAITING_CONTINUATION){ if(context.currentTrend == UP){ if(pivot_bar.low < context.currentPullbackLow.price) { context.currentPullbackLow.price = pivot_bar.low;
   context.currentPullbackLow.time = pivot_bar.time; } if(pivot_bar.low < context.swingLowAnchor.price){ CancelPendingOrders(context.magicNumber); context.currentTrend = DOWN; context.swingHighAnchor = context.currentImpulseHigh; context.currentImpulseLow.price = pivot_bar.low; context.currentImpulseLow.time = pivot_bar.time;
   context.currentState = TRACKING_IMPULSE; context.lastTradeSetupTime = 0; return; } else if(pivot_bar.high > context.currentImpulseHigh.price){ TrailEarlyStopsToNewSwing(context.currentPullbackLow.price, UP, context); CancelPendingOrders(context.magicNumber); context.swingLowAnchor = context.currentPullbackLow;
   context.currentImpulseHigh.price = pivot_bar.high; context.currentImpulseHigh.time = pivot_bar.time; context.currentState = TRACKING_IMPULSE; context.lastTradeSetupTime = 0; return;
   } if(IsUpTrendPullback(0, context) && pivot_bar.time > context.lastTradeSetupTime){ double pullbackDepth = (context.currentImpulseHigh.price - pivot_bar.low); if(pullbackDepth >= context.minPullbackAtrMult * currentAtr){ if(IsValidPullbackStructure(2, UP, context)) PlaceStrategyTrade(context);
   context.lastTradeSetupTime = pivot_bar.time; } } } else if(context.currentTrend == DOWN){ if(pivot_bar.high > context.currentPullbackHigh.price) { context.currentPullbackHigh.price = pivot_bar.high; context.currentPullbackHigh.time = pivot_bar.time;
   } if(pivot_bar.high > context.swingHighAnchor.price){ CancelPendingOrders(context.magicNumber); context.currentTrend = UP; context.swingLowAnchor = context.currentImpulseLow; context.currentImpulseHigh.price = pivot_bar.high; context.currentImpulseHigh.time = pivot_bar.time; context.currentState = TRACKING_IMPULSE;
   context.lastTradeSetupTime = 0; return; } else if(pivot_bar.low < context.currentImpulseLow.price){ TrailEarlyStopsToNewSwing(context.currentPullbackHigh.price, DOWN, context); CancelPendingOrders(context.magicNumber); context.swingHighAnchor = context.currentPullbackHigh; context.currentImpulseLow.price = pivot_bar.low;
   context.currentImpulseLow.time = pivot_bar.time; context.currentState = TRACKING_IMPULSE; context.lastTradeSetupTime = 0; return;
   } if(IsDownTrendPullback(0, context) && pivot_bar.time > context.lastTradeSetupTime){ double pullbackDepth = (pivot_bar.high - context.currentImpulseLow.price); if(pullbackDepth >= context.minPullbackAtrMult * currentAtr){ if(IsValidPullbackStructure(2, DOWN, context)) PlaceStrategyTrade(context);
   context.lastTradeSetupTime = pivot_bar.time; } } } } }

void PlaceStrategyTrade(StrategyContext &context)
{ 
   double totalRiskPercent = (EnableAdaptiveRisk && IsPrimeSetup(context)) ? context.primeRiskPercentage : context.riskPerEntryPercent;
   if(!PerformPreFlightChecks(totalRiskPercent, context)) return;
   
   if(!IsVolatilityFavorable(context)) return; 
   double adaptiveTakeProfitRR = context.baseTakeProfitRR; double adaptiveSlAtrMult = context.baseSlAtrMult;
   if(EnableVolatilityEngine){ switch(CurrentVolatilityRegime){ case VOL_LOW: adaptiveTakeProfitRR *= context.lowVolRRMultiplier; break; case VOL_HIGH: adaptiveTakeProfitRR *= context.highVolRRMultiplier; adaptiveSlAtrMult *= context.highVolSlAtrMultiplier; break; case VOL_EXTREME: LogDecision(context, "Trade Skipped", "Extreme Volatility", "", 0, 0); return;
   } } 
   if(!context.enableMultiHtfFilter || context.numberOfHtfs < HTF_COUNT_1) return; 
   ENUM_TREND requiredTrend = NO_TREND; TimeframeState htf1 = context.htfStates[0];
   if(htf1.currentTrend == UP && IsPriceAlignedWithEma(htf1.timeframe, htf1.emaHandle, UP, context.htfEnableEmaFilter[0])) requiredTrend = UP;
   else if(htf1.currentTrend == DOWN && IsPriceAlignedWithEma(htf1.timeframe, htf1.emaHandle, DOWN, context.htfEnableEmaFilter[0])) requiredTrend = DOWN; 
   if(requiredTrend == NO_TREND) { LogDecision(context, "Trade Skipped", "HTF1 No Trend", "", 0, 0); return; }
   for(int i = 1; i < (int)context.numberOfHtfs; i++){ if(context.htfStates[i].currentTrend != requiredTrend || !IsPriceAlignedWithEma(context.htfStates[i].timeframe, context.htfStates[i].emaHandle, requiredTrend, context.htfEnableEmaFilter[i])) { LogDecision(context, "Trade Skipped", "HTF Confluence Fail", EnumToString(context.htfStates[i].timeframe), 0, 0); return; }
   } 
   if(context.currentTrend != requiredTrend || !IsPriceAlignedWithEma(context.entryTimeframe, context.emaHandle, requiredTrend, context.enableEmaFilter)) { LogDecision(context, "Trade Skipped", "Entry TF Align Fail", "", 0, 0); return; } 
   
   trade.SetExpertMagicNumber(context.magicNumber);
   double stopLoss=0, takeProfit=0, range_val=0;
   double stopLossBuffer = GetAtrValue(context.atrHandle) * adaptiveSlAtrMult;
   double retracements[] = {0.61, 0.705, 0.75}; double weights[] = {0.6, 0.3, 0.1};
   
   if(context.currentTrend == UP)
   { 
      if(!AllowHedging && HasOppositePosition(ORDER_TYPE_BUY)) return;
      range_val = context.currentImpulseHigh.price - context.swingLowAnchor.price; if(range_val <= 0) return; 
      stopLoss = context.swingLowAnchor.price - stopLossBuffer; 
      UpdatePendingOrders(stopLoss, context.magicNumber, adaptiveTakeProfitRR);
      for(int i = 0; i < ArraySize(retracements); i++)
      { 
         double entryPrice = context.currentImpulseHigh.price - (range_val * retracements[i]);
         double riskDistance = entryPrice - stopLoss; if(riskDistance <= 0) continue; 
         takeProfit = entryPrice + (riskDistance * adaptiveTakeProfitRR);
         double thisRiskPercent = totalRiskPercent * weights[i]; 
         double lotSize = CalculateLotSize(stopLoss, entryPrice, thisRiskPercent);
         if(lotSize > 0 && entryPrice < SymbolInfoDouble(_Symbol, SYMBOL_ASK)) 
         {
            if(!IsMarginSufficient(lotSize, ORDER_TYPE_BUY_LIMIT, context)) continue;
            ExecutePendingOrder(ORDER_TYPE_BUY_LIMIT, lotSize, entryPrice, stopLoss, takeProfit, "", context);
         }
      } 
   } 
   else if(context.currentTrend == DOWN)
   { 
      if(!AllowHedging && HasOppositePosition(ORDER_TYPE_SELL)) return;
      range_val = context.swingHighAnchor.price - context.currentImpulseLow.price; if(range_val <= 0) return;
      stopLoss = context.swingHighAnchor.price + stopLossBuffer; 
      UpdatePendingOrders(stopLoss, context.magicNumber, adaptiveTakeProfitRR);
      for(int i = 0; i < ArraySize(retracements); i++)
      { 
         double entryPrice = context.currentImpulseLow.price + (range_val * retracements[i]);
         double riskDistance = stopLoss - entryPrice; if(riskDistance <= 0) continue; 
         takeProfit = entryPrice - (riskDistance * adaptiveTakeProfitRR);
         double thisRiskPercent = totalRiskPercent * weights[i]; 
         double lotSize = CalculateLotSize(stopLoss, entryPrice, thisRiskPercent);
         if(lotSize > 0 && entryPrice > SymbolInfoDouble(_Symbol, SYMBOL_BID))
         {
            if(!IsMarginSufficient(lotSize, ORDER_TYPE_SELL_LIMIT, context)) continue;
            ExecutePendingOrder(ORDER_TYPE_SELL_LIMIT, lotSize, entryPrice, stopLoss, takeProfit, "", context);
         } 
      } 
   } 
}

void AnalyzeHtfMarketStructure(TimeframeState &state, StrategyContext &context)
{
    MqlRates htf_rates[];
    int barsToScan = 1000; // Hardcoded for performance on HTF
    if(CopyRates(_Symbol, state.timeframe, 0, barsToScan, htf_rates) < 100) return;
    
    ProcessMarketStructure(state, htf_rates, barsToScan, false, context);
}

void ManageOpenPositions(){ SyncManagedPositions();
   for(int i = 0; i < ArraySize(ManagedPositions); i++){ if(!PositionSelectByTicket(ManagedPositions[i].ticket)) continue;
   long magic = PositionGetInteger(POSITION_MAGIC);
   if(magic != MagicNumber_Trend && magic != MagicNumber_DayTrade) continue; 
   
   double currentProfitPoints = 0; long positionType = PositionGetInteger(POSITION_TYPE); double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = (positionType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(positionType == POSITION_TYPE_BUY) currentProfitPoints = (currentPrice - openPrice) / _Point; else currentProfitPoints = (openPrice - currentPrice) / _Point;
   double currentRR = (ManagedPositions[i].initialRiskPoints > 0) ? currentProfitPoints / ManagedPositions[i].initialRiskPoints : 0;
   switch(ManagedPositions[i].managementPhase){ case PHASE_INITIAL: { if(currentRR >= BreakEvenTriggerR){ double newSL = openPrice + ((positionType == POSITION_TYPE_BUY) ? _Point : -_Point);
   if(trade.PositionModify(ManagedPositions[i].ticket, newSL, PositionGetDouble(POSITION_TP))){ ManagedPositions[i].managementPhase = PHASE_BREAKEVEN; } } } break; case PHASE_BREAKEVEN: ManagedPositions[i].managementPhase = PHASE_RUNNER; break;
   case PHASE_RUNNER: { double atr_buffer[]; if(CopyBuffer(runnerAtrHandle, 0, 1, 1, atr_buffer) > 0){ double trailStopPrice = 0, currentSL = PositionGetDouble(POSITION_SL);
   if(positionType == POSITION_TYPE_BUY){ trailStopPrice = currentPrice - (atr_buffer[0] * RunnerAtrMultiplier); if(trailStopPrice > currentSL) trade.PositionModify(ManagedPositions[i].ticket, trailStopPrice, PositionGetDouble(POSITION_TP));
   } else { trailStopPrice = currentPrice + (atr_buffer[0] * RunnerAtrMultiplier); if(trailStopPrice < currentSL && trailStopPrice > 0) trade.PositionModify(ManagedPositions[i].ticket, trailStopPrice, PositionGetDouble(POSITION_TP));
   } } } break; } } 
}

void SyncManagedPositions(){ for(int i = 0; i < PositionsTotal(); i++){ ulong ticket = PositionGetTicket(i);
   if(PositionSelectByTicket(ticket)){ long magic = PositionGetInteger(POSITION_MAGIC); if((magic == MagicNumber_Trend || magic == MagicNumber_DayTrade) && PositionGetString(POSITION_SYMBOL) == _Symbol){ bool isTracked = false;
   for(int j = 0; j < ArraySize(ManagedPositions); j++) if(ManagedPositions[j].ticket == ticket) isTracked = true;
   if(!isTracked){ int newSize = ArraySize(ManagedPositions) + 1; ArrayResize(ManagedPositions, newSize); ManagedPositions[newSize-1].ticket = ticket; ManagedPositions[newSize-1].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   ManagedPositions[newSize-1].initialRiskPoints = MathAbs(ManagedPositions[newSize-1].entryPrice - PositionGetDouble(POSITION_SL)) / _Point; ManagedPositions[newSize-1].managementPhase = PHASE_INITIAL;
   } } } } for(int i = ArraySize(ManagedPositions) - 1; i >= 0; i--){ if(!PositionSelectByTicket(ManagedPositions[i].ticket)){ for(int j = i; j < ArraySize(ManagedPositions) - 1; j++) ManagedPositions[j] = ManagedPositions[j+1];
   ArrayResize(ManagedPositions, ArraySize(ManagedPositions) - 1); } } }

void UpdateDashboard(){ static datetime last_update = 0; if(TimeCurrent() - last_update < 1) return;
   last_update = TimeCurrent(); string status_text; color status_color; if(isTradingStoppedForWeek) { status_text = "STOPPED (WEEKLY)"; status_color = clrRed;
   } else if(isTradingStoppedForDay) { status_text = "STOPPED (DAILY)"; status_color = clrRed; } else { status_text = "ACTIVE"; status_color = clrLimeGreen;
   } 
   int y_pos = 15, y_step = 16; DrawDashboardLabel("Title", 15, y_pos, "MAIshe (Dual Strategy)", clrWhite, 10);
   y_pos += y_step + 5;
   DrawDashboardLabel("Status", 15, y_pos, "Status: " + status_text, status_color); y_pos += y_step;
   
   if(DayTradeStrategy.isEnabled && DayTradeStrategy.enableNewsFilter)
   {
      string news_text = "News: OK";
      color news_color = clrLimeGreen;
      if(isNewsBlockActive)
      {
         news_text = "News: EMBARGO";
         news_color = clrOrange;
      }
      DrawDashboardLabel("News", 15, y_pos, news_text, news_color); y_pos += y_step;
   }
   
   ChartRedraw(0);
}
void DrawDashboardLabel(string name, int x, int y, string text, color clr, int font_size=9){ string obj_name = "EA_DASH_" + name;
   if(ObjectFind(0, obj_name) < 0){ ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER); ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, font_size); ObjectSetString(0, obj_name, OBJPROP_FONT, "Calibri"); } ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr); }

void CheckMaxDrawdown()
{
   if(!EnableMaxDrawdownStop || isTradingStoppedForDay || isTradingStoppedForWeek) return;
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   peakEquity = MathMax(peakEquity, currentEquity);
   
   double drawdown = (peakEquity > 0) ? (peakEquity - currentEquity) / peakEquity * 100.0 : 0.0;
   
   if(drawdown >= MaxDrawdownPercent)
   {
      string reason_detail = "Current DD: " + DoubleToString(drawdown,2) + "% > Limit: " + DoubleToString(MaxDrawdownPercent,2) + "%";
      Print("Max Drawdown limit reached. " + reason_detail + ". Closing all trades and stopping for the week.");
      LogDecision(TrendStrategy, "KILL SWITCH", "Max Drawdown", reason_detail, 0, 0);
      CloseAllAndStopTrading(true);
   }
}

void CheckProfitLossLimits(){ datetime now = TimeCurrent();
   if(now >= currentWeekStart + (7 * 86400)){ MqlDateTime dt; TimeToStruct(now, dt); int day_of_week = dt.day_of_week == 0 ?
   7 : dt.day_of_week; currentWeekStart = now - ((day_of_week - 1) * 86400) - (now % 86400); startOfWeekBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   isTradingStoppedForWeek = false; isTradingStoppedForDay = false; } if(now >= currentDayStart + 86400){ currentDayStart = now - (now % 86400);
   startOfDayBalance = AccountInfoDouble(ACCOUNT_BALANCE); isTradingStoppedForDay = false; } if(isTradingStoppedForWeek || isTradingStoppedForDay) return; double weeklyProfitPercent = (startOfWeekBalance > 0) ?
   (CalculateProfitForPeriod(currentWeekStart) / startOfWeekBalance) * 100 : 0; if(MaxWeeklyProfitPercent > 0 && weeklyProfitPercent >= MaxWeeklyProfitPercent){ if(!isTradingStoppedForWeek) { Print("Weekly Profit limit reached."); LogDecision(TrendStrategy, "KILL SWITCH", "Weekly Profit", "", 0, 0); CloseAllAndStopTrading(true); } return;
   } double dailyProfitPercent = (startOfDayBalance > 0) ? (CalculateProfitForPeriod(currentDayStart) / startOfDayBalance) * 100 : 0;
   if(MaxDailyProfitPercent > 0 && dailyProfitPercent >= MaxDailyProfitPercent){ if(!isTradingStoppedForDay) { Print("Daily Profit limit reached."); LogDecision(TrendStrategy, "KILL SWITCH", "Daily Profit", "", 0, 0); CloseAllAndStopTrading(false);} return; } if(MaxDailyLossPercent > 0 && dailyProfitPercent <= -MaxDailyLossPercent){ if(!isTradingStoppedForDay) { Print("Daily Loss limit reached."); LogDecision(TrendStrategy, "KILL SWITCH", "Daily Loss", "", 0, 0); CloseAllAndStopTrading(false); }
   return; } }
double CalculateProfitForPeriod(datetime startTime){ HistorySelect(startTime, TimeCurrent()); double totalProfit = 0;
   for(int i = 0; i < HistoryDealsTotal(); i++){ ulong ticket = HistoryDealGetTicket(i); long magic = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
   if((magic == MagicNumber_Trend || magic == MagicNumber_DayTrade) && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) totalProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
   } for(int i = PositionsTotal() - 1; i >= 0; i--){ if(PositionSelectByTicket(PositionGetTicket(i))){ long magic = PositionGetInteger(POSITION_MAGIC);
   if(magic == MagicNumber_Trend || magic == MagicNumber_DayTrade) totalProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP); } } return totalProfit;
   }
void CloseAllAndStopTrading(bool stopForWeek){ if(stopForWeek) isTradingStoppedForWeek = true;
   isTradingStoppedForDay = true; 
   CancelPendingOrders(MagicNumber_Trend);
   CancelPendingOrders(MagicNumber_DayTrade);
   for(int i = PositionsTotal() - 1; i >= 0; i--){ ulong ticket = PositionGetTicket(i);
   if(PositionSelectByTicket(ticket)){ long magic = PositionGetInteger(POSITION_MAGIC);
   if(magic == MagicNumber_Trend || magic == MagicNumber_DayTrade) trade.PositionClose(ticket); } } }
   
void UpdateVolatilityRegime(){ if(!EnableVolatilityEngine || !isVolatilityFilterActive) return; double short_atr_buffer[], long_atr_buffer[];
   if(CopyBuffer(shortAtrOnHtfHandle, 0, 1, 1, short_atr_buffer) < 1 || CopyBuffer(longAtrHandle, 0, 1, 1, long_atr_buffer) < 1 || long_atr_buffer[0] <= 0){ currentVolatilityIndex = 1.0;
   CurrentVolatilityRegime = VOL_NORMAL; return; } currentVolatilityIndex = short_atr_buffer[0] / long_atr_buffer[0]; ENUM_VOLATILITY_REGIME previousRegime = CurrentVolatilityRegime; if(currentVolatilityIndex < Volatility_LowThreshold) CurrentVolatilityRegime = VOL_LOW;
   else if(currentVolatilityIndex < Volatility_NormalThreshold) CurrentVolatilityRegime = VOL_NORMAL; else if(currentVolatilityIndex < Volatility_HighThreshold) CurrentVolatilityRegime = VOL_HIGH; else CurrentVolatilityRegime = VOL_EXTREME;
}

void InitializeHtfStateFromHistory(TimeframeState &state, StrategyContext &context)
{
   MqlRates htf_rates[];
   int barsToScan = 1000;
   if(CopyRates(_Symbol, state.timeframe, 0, barsToScan, htf_rates) < 100) return;
   
   ProcessMarketStructure(state, htf_rates, barsToScan, false, context);
}

void InitializeStrategyStateFromHistory(StrategyContext &context)
{
   MqlRates rates[];
   int barsToScan = 2000;
   if(CopyRates(_Symbol, context.entryTimeframe, 0, barsToScan, rates) < 100) return;

   TimeframeState ltfState;
   ltfState.timeframe = context.entryTimeframe;

   ProcessMarketStructure(ltfState, rates, barsToScan, true, context);

   context.currentTrend = ltfState.currentTrend;
   context.currentState = ltfState.currentState;
   context.swingLowAnchor = ltfState.swingLowAnchor;
   context.swingHighAnchor = ltfState.swingHighAnchor;
   context.currentImpulseHigh = ltfState.currentImpulseHigh;
   context.currentImpulseLow = ltfState.currentImpulseLow;
   context.currentPullbackLow = ltfState.currentPullbackLow;
   context.currentPullbackHigh = ltfState.currentPullbackHigh;
}

void ProcessMarketStructure(TimeframeState &state, MqlRates &rates[], int barsToScan, bool isLtf, StrategyContext &context)
{
   int tempAtrHandle = iATR(_Symbol, state.timeframe, context.atrPeriod);
   if(tempAtrHandle == INVALID_HANDLE) {
      Print("Could not create temporary ATR handle for market structure analysis on ", EnumToString(state.timeframe));
      return;
   }
   
   Sleep(100); 
   
   int calculated_bars = BarsCalculated(tempAtrHandle);
   int bars_to_process = MathMin(barsToScan, calculated_bars);

   double atr_values[];
   ArraySetAsSeries(rates, false); 
   if(CopyBuffer(tempAtrHandle, 0, 0, bars_to_process, atr_values) != bars_to_process)
   {
      Print("Could not copy ATR buffer for historical analysis on ", EnumToString(state.timeframe), ". Requested: ", bars_to_process);
      IndicatorRelease(tempAtrHandle);
      ArraySetAsSeries(rates, true);
      return;
   }
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(atr_values, true);

   double firstHigh = 0;
   datetime firstHighTime = 0;
   double firstLow = 9999999;
   datetime firstLowTime = 0;

   int initial_scan_count = MathMin(100, bars_to_process);

   for(int i = 0; i < initial_scan_count; i++)
   {
      if(rates[i].high > firstHigh) { firstHigh = rates[i].high; firstHighTime = rates[i].time; }
      if(rates[i].low < firstLow) { firstLow = rates[i].low; firstLowTime = rates[i].time; }
   }

   int startBar;
   if(firstHighTime > firstLowTime)
   {
      state.currentTrend = UP; state.swingLowAnchor.price = firstLow; state.swingLowAnchor.time = firstLowTime;
      state.currentImpulseHigh.price = firstHigh; state.currentImpulseHigh.time = firstHighTime; state.currentState = TRACKING_IMPULSE;
      startBar = iBarShift(_Symbol, state.timeframe, firstHighTime) + 1;
   }
   else
   {
      state.currentTrend = DOWN; state.swingHighAnchor.price = firstHigh; state.swingHighAnchor.time = firstHighTime;
      state.currentImpulseLow.price = firstLow; state.currentImpulseLow.time = firstLowTime; state.currentState = TRACKING_IMPULSE;
      startBar = iBarShift(_Symbol, state.timeframe, firstLowTime) + 1;
   }

   if(startBar < 4 || startBar >= bars_to_process) startBar = initial_scan_count;
   string prefix = context.name + "_";
   for(int i = startBar; i < bars_to_process; i++)
   {
      MqlRates bar_curr = rates[i];
      MqlRates bar_pivot = rates[i - 2];

      if(state.currentState == TRACKING_IMPULSE)
      {
         if(state.currentTrend == UP)
         {
            if(bar_curr.high > state.currentImpulseHigh.price) { state.currentImpulseHigh.price = bar_curr.high; state.currentImpulseHigh.time = bar_curr.time; }
            if(IsUpTrendPullback_Historical(i, rates, atr_values[i-2], context))
            {
               state.currentPullbackLow.price = bar_pivot.low; state.currentPullbackLow.time = bar_pivot.time; state.currentState = AWAITING_CONTINUATION;
            }
         }
         else if(state.currentTrend == DOWN)
         {
            if(bar_curr.low < state.currentImpulseLow.price) { state.currentImpulseLow.price = bar_curr.low; state.currentImpulseLow.time = bar_curr.time; }
            if(IsDownTrendPullback_Historical(i, rates, atr_values[i-2], context))
            {
               state.currentPullbackHigh.price = bar_pivot.high; state.currentPullbackHigh.time = bar_pivot.time; state.currentState = AWAITING_CONTINUATION;
            }
         }
      }
      else if(state.currentState == AWAITING_CONTINUATION)
      {
         if(state.currentTrend == UP)
         {
            if(bar_curr.low < state.currentPullbackLow.price) { state.currentPullbackLow.price = bar_curr.low; state.currentPullbackLow.time = bar_curr.time; }
            if(bar_curr.low < state.swingLowAnchor.price) // ChoCh
            {
               if(isLtf) DrawChoChLine(prefix, state.swingLowAnchor.time, state.swingLowAnchor.price, bar_curr.time, state.swingLowAnchor.price, "ChoCh Down");
               state.currentTrend = DOWN; state.swingHighAnchor = state.currentImpulseHigh; state.currentImpulseLow.price = bar_curr.low;
               state.currentImpulseLow.time = bar_curr.time; state.currentState = TRACKING_IMPULSE; state.lastBmsTime = bar_curr.time; state.lastChochTime = bar_curr.time;
            }
            else if(bar_curr.high > state.currentImpulseHigh.price) // BMS
            {
               if(isLtf) DrawBMSLine(prefix, state.currentImpulseHigh.time, state.currentImpulseHigh.price, bar_curr.time, state.currentImpulseHigh.price, "BMS Up");
               state.swingLowAnchor = state.currentPullbackLow; state.currentImpulseHigh.price = bar_curr.high; state.currentImpulseHigh.time = bar_curr.time;
               state.currentState = TRACKING_IMPULSE; state.lastBmsTime = bar_curr.time;
            }
         }
         else if(state.currentTrend == DOWN)
         {
            if(bar_curr.high > state.currentPullbackHigh.price) { state.currentPullbackHigh.price = bar_curr.high; state.currentPullbackHigh.time = bar_curr.time; }
            if(bar_curr.high > state.swingHighAnchor.price) // ChoCh
            {
               if(isLtf) DrawChoChLine(prefix, state.swingHighAnchor.time, state.swingHighAnchor.price, bar_curr.time, state.swingHighAnchor.price, "ChoCh Up");
               state.currentTrend = UP; state.swingLowAnchor = state.currentImpulseLow; state.currentImpulseHigh.price = bar_curr.high;
               state.currentImpulseHigh.time = bar_curr.time; state.currentState = TRACKING_IMPULSE; state.lastBmsTime = bar_curr.time; state.lastChochTime = bar_curr.time;
            }
            else if(bar_curr.low < state.currentImpulseLow.price) // BMS
            {
               if(isLtf) DrawBMSLine(prefix, state.currentImpulseLow.time, state.currentImpulseLow.price, bar_curr.time, state.currentImpulseLow.price, "BMS Down");
               state.swingHighAnchor = state.currentPullbackHigh; state.currentImpulseLow.price = bar_curr.low; state.currentImpulseLow.time = bar_curr.time;
               state.currentState = TRACKING_IMPULSE; state.lastBmsTime = bar_curr.time;
            }
         }
      }
   }
   
   IndicatorRelease(tempAtrHandle);
}


//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                 |
//+------------------------------------------------------------------+
double GetAtrValue(int handle){ double atr_buffer[1];
   if(CopyBuffer(handle, 0, 1, 1, atr_buffer) > 0) return atr_buffer[0]; return 0; }
   
double GetAtrValueAtBar(int shift, int handle) {
    double atr_buffer[1];
    if (CopyBuffer(handle, 0, shift + 1, 1, atr_buffer) > 0) return atr_buffer[0]; // shift+1 to get value of previous bar
    return 0;
}

bool IsVolatilityFavorable(StrategyContext &context){ 
   if(!EnableVolatilityFilter) return true;
   if(EnableVolatilityEngine && CurrentVolatilityRegime == VOL_EXTREME) 
   {
      LogDecision(context, "Trade Skipped", "Volatility Filter", "Market is in EXTREME regime", 0, 0);
      return false; 
   }
   double short_atr_buffer[], long_atr_buffer[];
   if(CopyBuffer(shortAtrOnHtfHandle, 0, 1, 1, short_atr_buffer) < 1 || CopyBuffer(longAtrHandle, 0, 1, 1, long_atr_buffer) < 1) return false;
   if(short_atr_buffer[0] <= 0 || long_atr_buffer[0] <= 0) return false; 
   if(short_atr_buffer[0] < long_atr_buffer[0] * MinVolatilityMultiplier)
   {
      LogDecision(context, "Trade Skipped", "Volatility Filter", "Below Min Volatility", 0, 0);
      return false;
   }
   if(short_atr_buffer[0] > long_atr_buffer[0] * MaxVolatilityMultiplier) 
   {
      LogDecision(context, "Trade Skipped", "Volatility Filter", "Above Max Volatility", 0, 0);
      return false; 
   }
   return true; 
}
   
bool IsPriceAlignedWithEma(ENUM_TIMEFRAMES timeframe, int handle, ENUM_TREND requiredTrend, bool isEnabled){ if(!isEnabled || handle == INVALID_HANDLE) return true;
   double ema_buffer[]; MqlRates rates[]; if(CopyBuffer(handle, 0, 1, 1, ema_buffer) > 0 && CopyRates(_Symbol, timeframe, 1, 1, rates) > 0){ if(requiredTrend == UP && rates[0].close < ema_buffer[0]) return false;
   if(requiredTrend == DOWN && rates[0].close > ema_buffer[0]) return false; } else return false; return true;
}
bool HasOppositePosition(ENUM_ORDER_TYPE orderType){ bool has_buy = false, has_sell = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--){ if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetString(POSITION_SYMBOL) == _Symbol){ if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) has_buy = true;
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) has_sell = true; } } if(orderType == ORDER_TYPE_BUY && has_sell) return true;
   if(orderType == ORDER_TYPE_SELL && has_buy) return true; return false; }

bool IsPrimeSetup(StrategyContext &context)
{
    if(context.numberOfHtfs < HTF_COUNT_3) return false;
    if(context.htfStates[0].currentTrend != context.currentTrend || context.htfStates[1].currentTrend != context.currentTrend || context.htfStates[2].currentTrend != context.currentTrend) return false;
    if(CurrentVolatilityRegime != VOL_NORMAL) return false;
    datetime lastBmsOnHtf1 = context.htfStates[0].lastBmsTime;
    if(lastBmsOnHtf1 > 0)
    {
      int barsSinceBms = iBarShift(_Symbol, context.entryTimeframe, lastBmsOnHtf1);
      if(barsSinceBms < 0 || barsSinceBms > (int)(PeriodSeconds(context.htfStates[0].timeframe)/PeriodSeconds(context.entryTimeframe)) * 3) return false;
    }
    double avgBody = GetAverageBodySize(context.avgBodyPeriod, context.entryTimeframe);
    if(avgBody <= 0) return false;
    if(context.currentTrend == UP) { if((context.currentImpulseHigh.price - context.swingLowAnchor.price) < (avgBody * context.impulseCandleMultiplier)) return false; }
    else if(context.currentTrend == DOWN) { if((context.swingHighAnchor.price - context.currentImpulseLow.price) < (avgBody * context.impulseCandleMultiplier)) return false; }
    return true;
}

double GetAverageBodySize(int period, ENUM_TIMEFRAMES timeframe)
{
    MqlRates rates[];
    if(CopyRates(_Symbol, timeframe, 0, period, rates) < period) return 0.0;
    double totalBodySize = 0;
    for(int i = 0; i < period; i++) { totalBodySize += MathAbs(rates[i].open - rates[i].close); }
    return totalBodySize / period;
}


void TrailEarlyStopsToNewSwing(double newSwingPrice, ENUM_TREND direction, StrategyContext &context){ double stopLossBuffer = GetAtrValue(context.atrHandle) * context.baseSlAtrMult;
   for(int i = 0; i < ArraySize(ManagedPositions); i++){ if(PositionSelectByTicket(ManagedPositions[i].ticket) && PositionGetInteger(POSITION_MAGIC) == context.magicNumber && ManagedPositions[i].managementPhase == PHASE_INITIAL){ long positionType = PositionGetInteger(POSITION_TYPE);
   double newStopLoss = 0; if(direction == UP && positionType == POSITION_TYPE_BUY){ newStopLoss = newSwingPrice - stopLossBuffer;
   if(newStopLoss > PositionGetDouble(POSITION_SL)){ if(trade.PositionModify(ManagedPositions[i].ticket, newStopLoss, PositionGetDouble(POSITION_TP))) ManagedPositions[i].initialRiskPoints = MathAbs(ManagedPositions[i].entryPrice - newStopLoss) / _Point;
   } } else if(direction == DOWN && positionType == POSITION_TYPE_SELL){ newStopLoss = newSwingPrice + stopLossBuffer;
   if(newStopLoss < PositionGetDouble(POSITION_SL)){ if(trade.PositionModify(ManagedPositions[i].ticket, newStopLoss, PositionGetDouble(POSITION_TP))) ManagedPositions[i].initialRiskPoints = MathAbs(ManagedPositions[i].entryPrice - newStopLoss) / _Point;
   } } } } }

bool IsUpTrendPullback(int shift, StrategyContext &context)
{
    MqlRates r[]; if(CopyRates(_Symbol, context.entryTimeframe, shift, 5, r) < 5) return false; ArraySetAsSeries(r, true);
    bool isFractal = (r[2].low < r[0].low && r[2].low < r[1].low && r[2].low < r[3].low && r[2].low < r[4].low);
    if(!isFractal || iBarShift(_Symbol, context.entryTimeframe, context.currentImpulseHigh.time) <= shift + 2) return false;
    double swingAtr = GetAtrValueAtBar(shift, context.atrHandle); if(swingAtr <= 0) return false;
    double swingRange = r[1].high - r[2].low; if(swingRange < (swingAtr * context.swingConfirmationAtrMult)) return false;
    return true;
}

bool IsDownTrendPullback(int shift, StrategyContext &context)
{
    MqlRates r[]; if(CopyRates(_Symbol, context.entryTimeframe, shift, 5, r) < 5) return false; ArraySetAsSeries(r, true);
    bool isFractal = (r[2].high > r[0].high && r[2].high > r[1].high && r[2].high > r[3].high && r[2].high > r[4].high);
    if(!isFractal || iBarShift(_Symbol, context.entryTimeframe, context.currentImpulseLow.time) <= shift + 2) return false;
    double swingAtr = GetAtrValueAtBar(shift, context.atrHandle); if(swingAtr <= 0) return false;
    double swingRange = r[2].high - r[1].low; if(swingRange < (swingAtr * context.swingConfirmationAtrMult)) return false;
    return true;
}

bool IsUpTrendPullback_Historical(int i, const MqlRates &rates[], double atr_value, StrategyContext &context)
{
    if(i < 4) return false;
    bool isFractal = (rates[i - 2].low < rates[i - 4].low && rates[i - 2].low < rates[i - 3].low && rates[i - 2].low < rates[i - 1].low && rates[i - 2].low < rates[i].low);
    if(!isFractal) return false;
    
    if(atr_value <= 0) return false;
    double swingRange = rates[i - 3].high - rates[i - 2].low;
    if(swingRange < (atr_value * context.swingConfirmationAtrMult)) return false;
    
    return true;
}

bool IsDownTrendPullback_Historical(int i, const MqlRates &rates[], double atr_value, StrategyContext &context)
{
    if(i < 4) return false;
    bool isFractal = (rates[i - 2].high > rates[i - 4].high && rates[i - 2].high > rates[i - 3].high && rates[i - 2].high > rates[i - 1].high && rates[i - 2].high > rates[i].high);
    if(!isFractal) return false;

    if(atr_value <= 0) return false;
    double swingRange = rates[i - 2].high - rates[i - 3].low;
    if(swingRange < (atr_value * context.swingConfirmationAtrMult)) return false;
    
    return true;
}


void UpdatePendingOrders(double newStopLoss, long magic_number, double adaptiveRR){ for(int i = OrdersTotal() - 1; i >= 0; i--){ ulong ticket = OrderGetTicket(i);
   if(ticket > 0 && OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == magic_number){ double entryPrice = OrderGetDouble(ORDER_PRICE_OPEN), takeProfit = 0;
   ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE); if(orderType == ORDER_TYPE_BUY_LIMIT && entryPrice - newStopLoss > 0){ takeProfit = entryPrice + (entryPrice - newStopLoss) * adaptiveRR;
   trade.OrderModify(ticket, entryPrice, newStopLoss, takeProfit, 0, 0); } else if(orderType == ORDER_TYPE_SELL_LIMIT && newStopLoss - entryPrice > 0){ takeProfit = entryPrice - (newStopLoss - entryPrice) * adaptiveRR;
   trade.OrderModify(ticket, entryPrice, newStopLoss, takeProfit, 0, 0); } } } }
void CancelPendingOrders(long magic_number){ for(int i = OrdersTotal() - 1; i >= 0; i--){ ulong ticket = OrderGetTicket(i);
   if(ticket > 0 && OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == magic_number) trade.OrderDelete(ticket);
   } }
double CalculateLotSize(double stopLoss, double entryPrice, double riskPercentToUse){ double riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * (riskPercentToUse / 100.0);
   double priceDifference = MathAbs(entryPrice - stopLoss); if(priceDifference <= 0) return 0.0; double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE); if(tickSize <= 0) return 0.0; double valuePerPoint = tickValue / tickSize;
   if(valuePerPoint <= 0) return 0.0; double lossPerLot = priceDifference * valuePerPoint; if(lossPerLot <= 0) return 0.0;
   double lotSize = riskAmount / lossPerLot; double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); lotSize = MathFloor(lotSize / volumeStep) * volumeStep;
   double minLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN); double maxLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX); if(lotSize < minLots) lotSize = 0.0;
   if(lotSize > maxLots) lotSize = maxLots; return lotSize; }
   
int CountCurrentTrades(long magic_number){ int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--){ if(PositionSelectByTicket(PositionGetTicket(i))){ if(PositionGetInteger(POSITION_MAGIC) == magic_number){ count++;
   } } } for(int i = OrdersTotal() - 1; i >= 0; i--){ if(OrderSelect(OrderGetTicket(i))){ if(OrderGetInteger(ORDER_MAGIC) == magic_number){ count++;
   } } } return count;}
   
bool IsValidPullbackStructure(int pivotBarShift, ENUM_TREND trendDirection, StrategyContext &context){ int barsToCopy = pivotBarShift + 10;
   MqlRates rates[];
   if(CopyRates(_Symbol, context.entryTimeframe, pivotBarShift, barsToCopy, rates) < 5) return false; ArraySetAsSeries(rates, true); int consecutiveCandles = 0;
   for(int i = 1; i < ArraySize(rates); i++){ bool isCounterCandle = (trendDirection == UP) ?
   (rates[i].close < rates[i].open) : (rates[i].close > rates[i].open); if(isCounterCandle){ consecutiveCandles++; if(consecutiveCandles >= 3) return true; } else consecutiveCandles = 0;
   } return false; }
   
void DrawBMSLine(string prefix, datetime t1, double p1, datetime t2, double p2, string txt){ string name = prefix + "BMS_" + IntegerToString((long)t1);
   if(ObjectFind(0, name) < 0){ ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2); ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue); ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT); } }
void DrawChoChLine(string prefix, datetime t1, double p1, datetime t2, double p2, string txt){ string name = prefix + "ChoCh_" + IntegerToString((long)t1);
   if(ObjectFind(0, name) < 0){ ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2); ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrangeRed); ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT); } }
void DrawHtfBMSLine(string prefix, datetime t1, double p1, datetime t2, double p2, string txt){ string name = prefix + "BMS_" + IntegerToString((long)t1);
   if(ObjectFind(0, name) < 0){ ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2); ObjectSetInteger(0, name, OBJPROP_COLOR, clrCornflowerBlue); ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); } }
void DrawHtfChoChLine(string prefix, datetime t1, double p1, datetime t2, double p2, string txt){ string name = prefix + "ChoCh_" + IntegerToString((long)t1);
   if(ObjectFind(0, name) < 0){ ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2); ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange); ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); } }
   
bool PerformPreFlightChecks(double newTradeRiskPercent, StrategyContext &context){ 
   if(!IsTradingTime(context)) return false; 
   if(context.enableNewsFilter && isNewsBlockActive) { LogDecision(context, "Trade Skipped", "News Filter", "Embargo Active", 0, 0); return false; }
   if(!IsSpreadOK(context)) return false;
   if(CountCurrentTrades(context.magicNumber) >= context.maxRunningTrades){ LogDecision(context, "Trade Skipped", "Max Trades", (string)context.maxRunningTrades + " reached", 0, 0); return false; } 
   if(!IsTotalRiskOK(newTradeRiskPercent, context)) return false;
   if(EnableCorrelationRiskManager && !IsCorrelationRiskOK(newTradeRiskPercent, context)) return false;
   return true;
}

bool ExecuteMarketOrder(ENUM_ORDER_TYPE orderType, double lot, double sl, double tp, string comment, StrategyContext &context){ 
   trade.SetExpertMagicNumber(context.magicNumber);
   trade.SetDeviationInPoints(MaxSlippagePoints);
   for(int i = 0; i < OrderRetries; i++){ bool result = (orderType == ORDER_TYPE_BUY) ?
   trade.Buy(lot, _Symbol, 0, sl, tp, comment) : trade.Sell(lot, _Symbol, 0, sl, tp, comment);
   if(result){ Print("Market order successful. Ticket: ", trade.ResultOrder()); LogDecision(context, "Market Order", "Success", (string)trade.ResultOrder(), context.riskPerEntryPercent, lot);
   return true; } else { uint retcode = trade.ResultRetcode();
   Print("Market order failed attempt #", i+1, ". Reason: ", trade.ResultComment(), " (Code: ", retcode, ")");
   if(retcode == 10004 || retcode == 10006 || retcode == 10008){ Sleep(RetryDelayMs); continue; } else { LogDecision(context, "Market Order", "Failed", trade.ResultComment(), context.riskPerEntryPercent, lot); return false;
   } } } return false; }
bool ExecutePendingOrder(ENUM_ORDER_TYPE orderType, double lot, double entry, double sl, double tp, string comment, StrategyContext &context){ 
   trade.SetExpertMagicNumber(context.magicNumber);
   if(MQLInfoInteger(MQL_TESTER) && SimulatedSlippagePoints > 0){ double slippage = SimulatedSlippagePoints * _Point;
   if(orderType == ORDER_TYPE_BUY_LIMIT) entry += slippage; if(orderType == ORDER_TYPE_SELL_LIMIT) entry -= slippage; } bool result = false;
   if(orderType == ORDER_TYPE_BUY_LIMIT) result = trade.BuyLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
   if(orderType == ORDER_TYPE_SELL_LIMIT) result = trade.SellLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
   if(result){ Print("Pending order placed successfully for magic ", (string)context.magicNumber, ". Ticket: ", (string)trade.ResultOrder()); LogDecision(context, "Pending Order", "Success", (string)trade.ResultOrder(), context.riskPerEntryPercent, lot);
   } else { Print("Pending order failed for magic ", (string)context.magicNumber, ". Reason: ", trade.ResultComment(), " (Code: ", (string)trade.ResultRetcode(), ")"); LogDecision(context, "Pending Order", "Failed", trade.ResultComment(), context.riskPerEntryPercent, lot);
   } return result;
   }
bool IsSpreadOK(StrategyContext &context){ double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pipSize = _Point * ( (_Digits == 3 || _Digits == 5) ? 10 : 1 );
   double maxAllowedSpread = MaxSpreadPips * pipSize; if(spread > maxAllowedSpread){ 
      string details = "Spread: " + DoubleToString(spread/_Point,1) + " > Limit: " + DoubleToString(maxAllowedSpread/_Point, 1);
      LogDecision(context, "Trade Skipped", "High Spread", details, 0, 0);
   return false; } return true; }
bool IsMarginSufficient(double lots, ENUM_ORDER_TYPE orderType, StrategyContext &context){ double margin_required = 0;
   if(!OrderCalcMargin(orderType, _Symbol, lots, SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin_required)){ LogDecision(context, "Trade Skipped", "Margin Calc Fail", "", 0, lots); return false;
   } if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin_required){ 
      string details = "Required: "+DoubleToString(margin_required,2) + ", Available: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2);
      LogDecision(context, "Trade Skipped", "Insufficient Margin", details, 0, lots); 
   return false;
   } return true; }
   
bool IsTradingTime(StrategyContext &context){ 
   if(!context.enableTimeFilter) return true; 
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < context.tradeAllowedFromHour || dt.hour >= context.tradeAllowedToHour){ LogDecision(context, "Trade Skipped", "Time Filter", "Outside hours", 0, 0); return false; } 
   if(context.blockMinutesAfterMarketOpen > 0){ 
      if(TimeCurrent() < (currentDayStart + (context.blockMinutesAfterMarketOpen * 60))){ LogDecision(context, "Trade Skipped", "Time Filter", "Market Open block", 0, 0); return false;
   } } 
   return true; 
}

bool IsTotalRiskOK(double newTradeRiskPercent, StrategyContext &context){ if(MaxTotalRiskPercent <= 0) return true; double totalRisk = 0; double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountEquity <= 0) return false; for(int i = PositionsTotal() - 1; i >= 0; i--){ if(PositionSelectByTicket(PositionGetTicket(i))){ if(PositionGetString(POSITION_SYMBOL) == _Symbol){ long magic = PositionGetInteger(POSITION_MAGIC);
   if(magic == context.magicNumber){ double open_price = PositionGetDouble(POSITION_PRICE_OPEN); double sl = PositionGetDouble(POSITION_SL);
   double lots = PositionGetDouble(POSITION_VOLUME);
   if(sl != 0){ double riskAmount = MathAbs(open_price - sl) * lots * (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
   totalRisk += (riskAmount / accountEquity) * 100.0; } } } } } for(int i = OrdersTotal() - 1; i >= 0; i--){ if(OrderSelect(OrderGetTicket(i))){ if(OrderGetString(ORDER_SYMBOL) == _Symbol){ long magic = (long)OrderGetInteger(ORDER_MAGIC);
   if(magic == context.magicNumber){ double open_price = OrderGetDouble(ORDER_PRICE_OPEN); double sl = OrderGetDouble(ORDER_SL);
   double lots = OrderGetDouble(ORDER_VOLUME_INITIAL);
   if (sl != 0){ double riskAmount = MathAbs(open_price - sl) * lots * (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
   totalRisk += (riskAmount / accountEquity) * 100.0; } } } } } if(totalRisk + newTradeRiskPercent > MaxTotalRiskPercent){ 
      string details = "Current:" + DoubleToString(totalRisk,2) + "% New:" + DoubleToString(newTradeRiskPercent, 2) + "% Limit:" + DoubleToString(MaxTotalRiskPercent, 2) + "%";
      LogDecision(context, "Trade Skipped", "Max Symbol Risk", details, 0, 0);
   return false; } return true; }
   
bool IsCorrelationRiskOK(double newTradeRiskPercent, StrategyContext &context)
{
   double totalRisk = 0;
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountEquity <= 0) return false;
   
   string symbol_array[];
   StringSplit(CorrelatedSymbols, ',', symbol_array);
   
   // Calculate risk for open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         string pos_symbol = PositionGetString(POSITION_SYMBOL);
         for(int j=0; j < ArraySize(symbol_array); j++)
         {
            if(pos_symbol == symbol_array[j])
            {
               double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
               double sl = PositionGetDouble(POSITION_SL);
               double lots = PositionGetDouble(POSITION_VOLUME);
               if(sl != 0)
               {
                  double tick_value = SymbolInfoDouble(pos_symbol, SYMBOL_TRADE_TICK_VALUE);
                  double tick_size = SymbolInfoDouble(pos_symbol, SYMBOL_TRADE_TICK_SIZE);
                  if(tick_size > 0)
                  {
                     double riskAmount = MathAbs(open_price - sl) * lots * (tick_value / tick_size);
                     totalRisk += (riskAmount / accountEquity) * 100.0;
                  }
               }
               break; 
            }
         }
      }
   }
   
   // Calculate risk for pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(OrderGetTicket(i)))
      {
         string order_symbol = OrderGetString(ORDER_SYMBOL);
          for(int j=0; j < ArraySize(symbol_array); j++)
         {
            if(order_symbol == symbol_array[j])
            {
               double open_price = OrderGetDouble(ORDER_PRICE_OPEN);
               double sl = OrderGetDouble(ORDER_SL);
               double lots = OrderGetDouble(ORDER_VOLUME_INITIAL);
               if(sl != 0)
               {
                  double tick_value = SymbolInfoDouble(order_symbol, SYMBOL_TRADE_TICK_VALUE);
                  double tick_size = SymbolInfoDouble(order_symbol, SYMBOL_TRADE_TICK_SIZE);
                  if(tick_size > 0)
                  {
                     double riskAmount = MathAbs(open_price - sl) * lots * (tick_value / tick_size);
                     totalRisk += (riskAmount / accountEquity) * 100.0;
                  }
               }
               break;
            }
         }
      }
   }
   
   if(totalRisk + newTradeRiskPercent > MaxCorrelatedRiskPercent)
   {
      string details = "Current:" + DoubleToString(totalRisk,2) + "% New:" + DoubleToString(newTradeRiskPercent, 2) + "% Limit:" + DoubleToString(MaxCorrelatedRiskPercent, 2) + "%";
      LogDecision(context, "Trade Skipped", "Max Correlation Risk", details, 0, 0);
      return false;
   }
   
   return true;
}
   
//+------------------------------------------------------------------+
//| NEWS FILTER FUNCTIONS                                            |
//+------------------------------------------------------------------+
void FetchNewsData()
{
   lastNewsFetchTime = TimeCurrent();
   ArrayFree(UpcomingNews);
   
   string cookie=NULL,headers;
   char post[],result[];
   int res;
   string url = DayTrade_NewsURL;

   ResetLastError();
   res = WebRequest("GET", url, NULL, NULL, 5000, post, 0, result, headers);

   if(res == -1)
   {
      Print("Error in WebRequest. Error code: ", GetLastError());
      return;
   }
   
   string html_content = CharArrayToString(result);
   ParseNewsHTML(html_content);
}

void ParseNewsHTML(string html)
{
   int pos = 0;
   datetime eventDate = 0;
   long gmt_offset = TimeGMTOffset();

   while((pos = StringFind(html, "calendar__row", pos)) != -1)
   {
      string row_html = StringSubstr(html, pos, StringFind(html, "</tr>", pos) - pos);
      
      // Get Date
      int date_pos = StringFind(row_html, "calendar__date");
      if(date_pos != -1)
      {
         string date_str_full = GetSubstring(row_html, "calendar__date", ">", "<");
         string date_parts[];
         StringSplit(date_str_full, ' ', date_parts);
         if(ArraySize(date_parts) >= 3)
         {
            MqlDateTime dt;
            dt.mon = MonthToInt(date_parts[1]);
            dt.day = (int)StringToInteger(date_parts[2]);
            
            MqlDateTime current_server_time;
            TimeToStruct(TimeCurrent(), current_server_time);
            dt.year = current_server_time.year; // Assume current year based on server time
            
            eventDate = StructToTime(dt);
         }
      }

      if(eventDate == 0) 
      {
         pos++;
         continue;
      }

      // Get Time
      string time_str = GetSubstring(row_html, "calendar__time", ">", "<");
      if(StringFind(time_str, ":") == -1) // Skip "All Day" or invalid times
      {
         pos++;
         continue;
      }
      
      string time_parts[];
      StringSplit(time_str, ':', time_parts);
      int hour = (int)StringToInteger(time_parts[0]);
      int min = (int)StringToInteger(StringSubstr(time_parts[1],0,2));
      if(StringFind(StringToUpper(time_parts[1]), "PM") > -1 && hour != 12) hour += 12;
      if(StringFind(StringToUpper(time_parts[1]), "AM") > -1 && hour == 12) hour = 0;

      MqlDateTime dt;
      TimeToStruct(eventDate, dt);
      dt.hour = hour;
      dt.min = min;
      
      datetime event_gmt_time = StructToTime(dt);
      datetime event_server_time = (datetime)(event_gmt_time + gmt_offset);

      // Get Currency
      string currency = GetSubstring(row_html, "calendar__currency", ">", "<");

      // Get Impact
      ENUM_IMPACT_LEVEL impact = IMPACT_LOW;
      if(StringFind(row_html, "impact--high") != -1) impact = IMPACT_HIGH;
      else if(StringFind(row_html, "impact--medium") != -1) impact = IMPACT_MEDIUM;
      else if(StringFind(row_html, "impact--low") != -1) impact = IMPACT_LOW;

      // Get Title
      string title = GetSubstring(row_html, "calendar__event-title", ">", "<");

      // Add to array
      int size = ArraySize(UpcomingNews);
      ArrayResize(UpcomingNews, size + 1);
      UpcomingNews[size].time = event_server_time;
      UpcomingNews[size].currency = currency;
      UpcomingNews[size].impact = impact;
      UpcomingNews[size].title = title;
      
      pos++;
   }
}

string GetSubstring(string source, string start_marker, string open_tag, string close_tag)
{
    int start_pos = StringFind(source, start_marker);
    if(start_pos == -1) return "";
    
    int open_pos = StringFind(source, open_tag, start_pos);
    if(open_pos == -1) return "";
    
    int close_pos = StringFind(source, close_tag, open_pos + 1);
    if(close_pos == -1) return "";
    
    return StringSubstr(source, open_pos + 1, close_pos - open_pos - 1);
}

int MonthToInt(string month)
{
    month = StringToUpper(StringSubstr(month, 0, 3));
    if(month == "JAN") return 1; if(month == "FEB") return 2;
    if(month == "MAR") return 3; if(month == "APR") return 4;
    if(month == "MAY") return 5; if(month == "JUN") return 6;
    if(month == "JUL") return 7; if(month == "AUG") return 8;
    if(month == "SEP") return 9; if(month == "OCT") return 10;
    if(month == "NOV") return 11; if(month == "DEC") return 12;
    return 0;
}


bool IsInNewsEmbargo()
{
   string base_currency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   string quote_currency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);

   for(int i = 0; i < ArraySize(UpcomingNews); i++)
   {
      // Check if currency matches
      if(UpcomingNews[i].currency != base_currency && UpcomingNews[i].currency != quote_currency) continue;
      
      // Check if impact level is one we care about
      bool impact_match = false;
      if(DayTradeStrategy.filterHighImpact && UpcomingNews[i].impact == IMPACT_HIGH) impact_match = true;
      if(DayTradeStrategy.filterMediumImpact && UpcomingNews[i].impact == IMPACT_MEDIUM) impact_match = true;
      if(DayTradeStrategy.filterLowImpact && UpcomingNews[i].impact == IMPACT_LOW) impact_match = true;
      if(!impact_match) continue;
      
      long seconds_to_news = (long)UpcomingNews[i].time - (long)TimeCurrent();
      
      // Check if we are in the before/after window
      if(seconds_to_news > -(DayTradeStrategy.minutesAfterNewsResume * 60) && 
         seconds_to_news < (DayTradeStrategy.minutesBeforeNewsStop * 60))
      {
         return true; // We are inside the news embargo period
      }
   }
   return false;
}

void ManageNewsClosures()
{
   string base_currency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   string quote_currency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);

   for(int i = 0; i < ArraySize(UpcomingNews); i++)
   {
      // Check if currency matches
      if(UpcomingNews[i].currency != base_currency && UpcomingNews[i].currency != quote_currency) continue;

      // Check impact level
      bool impact_match = false;
      if(DayTradeStrategy.filterHighImpact && UpcomingNews[i].impact == IMPACT_HIGH) impact_match = true;
      if(DayTradeStrategy.filterMediumImpact && UpcomingNews[i].impact == IMPACT_MEDIUM) impact_match = true;
      if(DayTradeStrategy.filterLowImpact && UpcomingNews[i].impact == IMPACT_LOW) impact_match = true;
      if(!impact_match) continue;
      
      long seconds_to_news = (long)UpcomingNews[i].time - (long)TimeCurrent();
      
      // If news is within the "close before" window, close DayTrade positions
      if(seconds_to_news > 0 && seconds_to_news < (DayTradeStrategy.minutesBeforeNewsStop * 60))
      {
         for(int j = PositionsTotal() - 1; j >= 0; j--)
         {
            ulong ticket = PositionGetTicket(j);
            if(PositionSelectByTicket(ticket))
            {
               if(PositionGetInteger(POSITION_MAGIC) == MagicNumber_DayTrade)
               {
                  LogDecision(DayTradeStrategy, "Position Closed", "Pre-News Closure", UpcomingNews[i].title, 0, PositionGetDouble(POSITION_VOLUME));
                  trade.PositionClose(ticket);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| LOGGING FUNCTION                                                 |
//+------------------------------------------------------------------+
void LogDecision(const StrategyContext &context, string decision, string reason, string details, double risk_percent, double lot_size)
{
   if(hLogFile != INVALID_HANDLE)
   {
      FileWrite(hLogFile, 
                TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                context.name,
                decision,
                _Symbol,
                reason,
                details,
                DoubleToString(risk_percent, 2),
                DoubleToString(lot_size, 2)
               );
      FileFlush(hLogFile); // Ensure data is written immediately
   }
}

