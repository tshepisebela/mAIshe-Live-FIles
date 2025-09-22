//+------------------------------------------------------------------+
//|  mAIshe V23.1 (Compiler Fix)                                     |
//|                      Copyright 2025, The Pro Trader              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, The Pro Trader"
#property link      ""
#property version   "23.1" // Version with compiler fix for ProcessMarketStructure
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
//--- EA Inputs
input group "Global Trade Settings"
input bool   EnableTrendStrategy     = true;         // MASTER SWITCH for Trend-Following Strategy
input bool   AllowHedging            = false;        // If true, EA can open buy and sell trades at the same time

input group "Trade Execution Settings"
input ulong  MaxSlippagePoints       = 30;           // Max allowed slippage for market orders (in points)
input double MaxSpreadPips           = 3.0;          // Abort trade if spread exceeds this (in pips)
input uint   SimulatedSlippagePoints = 2;            // For backtesting: simulate X points of slippage on pending orders
input int    OrderRetries            = 3;            // Number of retries on requote/server error
input int    RetryDelayMs            = 250;          // Milliseconds to wait between retries

input group "Time & Session Filters"
input bool   EnableTimeFilter            = true;
input int    TradeAllowedFromHour        = 1;          // Server hour to start trading (e.g., 1 = after first hour)
input int    TradeAllowedToHour          = 23;         // Server hour to stop trading (e.g., 23 = before last hour)
input int    BlockMinutesAfterMarketOpen = 15;         // Don't trade for N minutes after daily bar open

input group "Performance Settings"
input int    HistoryScanBars = 2000;
input int    AtrPeriod       = 14;

input group "Equity Protection"
input bool   EnableEquityStop      = true;
input double MaxEquityLossPercent  = 5.0;

input group "Daily and Weekly Risk Management"
input bool   EnableProfitLossLimits = true;
input double MaxDailyLossPercent    = 3.0;
input double MaxDailyProfitPercent  = 10.0;
input double MaxWeeklyProfitPercent = 20.0;

input group "Overall Exposure Management"
input double MaxTotalRiskPercent  = 4.0;              // Max total risk across ALL open/pending trades

input group "Adaptive Risk Management"
input bool   EnableAdaptiveRisk      = true;
input double PrimeRiskPercentage     = 1.5;            // Risk % to use for A+ "Prime" setups
input double ImpulseCandleMultiplier = 1.5;            // Multiplier for avg candle body to qualify a strong impulse
input int    AvgBodyPeriod           = 50;             // Period for calculating average candle body size
double       PrimeMinAtrMult         = 2.0;
input double SwingConfirmationAtrMult = 0.5;           // ATR multiplier to confirm a swing point's significance

input group "Multi-Timeframe Confluence (Trend Strategy)"
input bool   EnableMultiHtfFilter = true;
input ENUM_HTF_COUNT NumberOfHtfs = HTF_COUNT_3;
input ENUM_TIMEFRAMES Htf1_Timeframe = PERIOD_D1;
input ENUM_TIMEFRAMES Htf2_Timeframe = PERIOD_H4;
input ENUM_TIMEFRAMES Htf3_Timeframe = PERIOD_H1;

input group "Multi-Timeframe EMA Filters (Trend Strategy)"
input bool   Htf1_EnableEmaFilter = true;
input int    Htf1_EmaPeriod       = 50;
input ENUM_MA_METHOD Htf1_EmaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE Htf1_EmaPrice = PRICE_CLOSE;
input bool   Htf2_EnableEmaFilter = true;
input int    Htf2_EmaPeriod       = 50;
input ENUM_MA_METHOD Htf2_EmaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE Htf2_EmaPrice = PRICE_CLOSE;
input bool   Htf3_EnableEmaFilter = true;
input int    Htf3_EmaPeriod       = 50;
input ENUM_MA_METHOD Htf3_EmaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE Htf3_EmaPrice = PRICE_CLOSE;

input group "Adaptive Trend Parameters"
double Trend_LowVolRRMultiplier     = 0.75;
double Trend_HighVolRRMultiplier    = 1.5;
double Trend_HighVolSlAtrMultiplier = 1.25;

input group "LTF Trend Confirmation"
input bool   EnableEmaFilter = true;
input int    EmaFilterPeriod = 50;
input ENUM_MA_METHOD EmaFilterMethod = MODE_EMA;
input ENUM_APPLIED_PRICE EmaFilterPrice = PRICE_CLOSE;

input group "Trend Strategy Settings"
input double RiskPerEntryPercent     = 0.5;
input int    MaxRunningTrades        = 6;
input int    MagicNumber_Trend       = 12345;
input double Trend_BaseTakeProfitRR  = 6.0;
input double Trend_BaseSlAtrMult     = 0.5;
double       MinPullbackAtrMult      = 1.0;

input group "Institutional Trade Management"
input bool   EnableAdvancedManagement = true;
input double BreakEvenTriggerR      = 2.0;
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
int      atrHandle;
int      runnerAtrHandle;
int      longAtrHandle;
int      shortAtrOnHtfHandle;
int      ltfEmaHandle;

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

struct ManagedPosition
{
   ulong             ticket;
   double            initialRiskPoints;
   double            entryPrice;
   ENUM_MANAGE_PHASE managementPhase;
};

//--- State Variables
ManagedPosition        ManagedPositions[];
ENUM_VOLATILITY_REGIME CurrentVolatilityRegime = VOL_NORMAL;
double                 currentVolatilityIndex  = 1.0;
ENUM_TREND             CurrentTrend            = NO_TREND;
ENUM_STATE             CurrentState            = TRACKING_IMPULSE;
datetime               lastTradeSetupTime      = 0;
SwingPoint             SwingLowAnchor, SwingHighAnchor, CurrentImpulseHigh, CurrentImpulseLow, CurrentPullbackLow, CurrentPullbackHigh;
TimeframeState         HtfStates[3];
bool                   Htf_EnableEmaFilter_Inputs[3];
int                    Htf_EmaPeriod_Inputs[3];
ENUM_MA_METHOD         Htf_EmaMethod_Inputs[3];
ENUM_APPLIED_PRICE     Htf_EmaPrice_Inputs[3];
datetime               currentDayStart;
datetime               currentWeekStart;
double                 startOfDayBalance;
double                 startOfWeekBalance;
bool                   isTradingStoppedForDay  = false;
bool                   isTradingStoppedForWeek = false;
bool                   isVolatilityFilterActive = true;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber_Trend);
   trade.SetDeviationInPoints(MaxSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   atrHandle = iATR(_Symbol, _Period, AtrPeriod);
   runnerAtrHandle = iATR(_Symbol, _Period, RunnerAtrPeriod);
   
   isVolatilityFilterActive = EnableVolatilityFilter;
   if(isVolatilityFilterActive)
   {
      longAtrHandle = iATR(_Symbol, VolatilityFilterTimeframe, LongAtrPeriod);
      shortAtrOnHtfHandle = iATR(_Symbol, VolatilityFilterTimeframe, AtrPeriod);
      if(longAtrHandle == INVALID_HANDLE || shortAtrOnHtfHandle == INVALID_HANDLE)
      {
         Print("Error creating ATR indicator handles for volatility filter. Disabling feature.");
         isVolatilityFilterActive = false;
      }
   }

   if(EnableEmaFilter) ltfEmaHandle = iMA(_Symbol, _Period, EmaFilterPeriod, 0, EmaFilterMethod, EmaFilterPrice);

   Htf_EnableEmaFilter_Inputs[0] = Htf1_EnableEmaFilter; Htf_EmaPeriod_Inputs[0] = Htf1_EmaPeriod; Htf_EmaMethod_Inputs[0] = Htf1_EmaMethod; Htf_EmaPrice_Inputs[0] = Htf1_EmaPrice;
   Htf_EnableEmaFilter_Inputs[1] = Htf2_EnableEmaFilter; Htf_EmaPeriod_Inputs[1] = Htf2_EmaPeriod;
   Htf_EmaMethod_Inputs[1] = Htf2_EmaMethod; Htf_EmaPrice_Inputs[1] = Htf2_EmaPrice;
   Htf_EnableEmaFilter_Inputs[2] = Htf3_EnableEmaFilter; Htf_EmaPeriod_Inputs[2] = Htf3_EmaPeriod; Htf_EmaMethod_Inputs[2] = Htf3_EmaMethod; Htf_EmaPrice_Inputs[2] = Htf3_EmaPrice;

   HtfStates[0].timeframe = Htf1_Timeframe; HtfStates[0].objectPrefix = "EA_HTF1_"; HtfStates[0].emaHandle = Htf1_EnableEmaFilter ?
   iMA(_Symbol, Htf1_Timeframe, Htf1_EmaPeriod, 0, Htf1_EmaMethod, Htf1_EmaPrice) : INVALID_HANDLE;
   HtfStates[1].timeframe = Htf2_Timeframe; HtfStates[1].objectPrefix = "EA_HTF2_"; HtfStates[1].emaHandle = Htf2_EnableEmaFilter ?
   iMA(_Symbol, Htf2_Timeframe, Htf2_EmaPeriod, 0, Htf2_EmaMethod, Htf2_EmaPrice) : INVALID_HANDLE;
   HtfStates[2].timeframe = Htf3_Timeframe; HtfStates[2].objectPrefix = "EA_HTF3_"; HtfStates[2].emaHandle = Htf3_EnableEmaFilter ?
   iMA(_Symbol, Htf3_Timeframe, Htf3_EmaPeriod, 0, Htf3_EmaMethod, Htf3_EmaPrice) : INVALID_HANDLE;

   for(int i=0; i<ArraySize(HtfStates); i++) InitializeHtfStateFromHistory(HtfStates[i]);

   TimeCurrent();
   currentDayStart = TimeCurrent() - (TimeCurrent() % 86400);
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   int day_of_week = dt.day_of_week == 0 ? 7 : dt.day_of_week;
   currentWeekStart = TimeCurrent() - ((day_of_week - 1) * 86400) - (TimeCurrent() % 86400);
   startOfDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   startOfWeekBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   ObjectsDeleteAll(0, "EA_");
   InitializeStateFromHistory();  
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) 
{
   ObjectsDeleteAll(0, "EA_");
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(runnerAtrHandle != INVALID_HANDLE) IndicatorRelease(runnerAtrHandle);
   if(longAtrHandle != INVALID_HANDLE) IndicatorRelease(longAtrHandle);
   if(shortAtrOnHtfHandle != INVALID_HANDLE) IndicatorRelease(shortAtrOnHtfHandle);
   if(ltfEmaHandle != INVALID_HANDLE) IndicatorRelease(ltfEmaHandle);
   for(int i = 0; i < ArraySize(HtfStates); i++) if(HtfStates[i].emaHandle != INVALID_HANDLE) IndicatorRelease(HtfStates[i].emaHandle);
}

//+------------------------------------------------------------------+
//| OnTick - Main Loop                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(ShowDashboard) UpdateDashboard();
   if(EnableVolatilityEngine) UpdateVolatilityRegime();

   CheckEquityStopLoss();
   if(EnableAdvancedManagement) ManageOpenPositions();
   if(EnableProfitLossLimits)
   {
      CheckProfitLossLimits();
      if(isTradingStoppedForDay || isTradingStoppedForWeek) return;
   }
     
   // Always analyze HTF market structure
   for(int i=0; i < ArraySize(HtfStates); i++){ datetime newHtfBarTime = (datetime)SeriesInfoInteger(_Symbol, HtfStates[i].timeframe, SERIES_LASTBAR_DATE);
   if(newHtfBarTime != HtfStates[i].lastBarTime) { HtfStates[i].lastBarTime = newHtfBarTime; AnalyzeHtfMarketStructure(HtfStates[i]); } }
   
   // --- CORE LOGIC FLOW ---
   // On a new LTF bar, check for trend continuation setups
   static datetime lastLtfBarTime = 0;
   datetime newLtfBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(newLtfBarTime != lastLtfBarTime)
   {
       lastLtfBarTime = newLtfBarTime;
       if(EnableTrendStrategy)
       {
           AnalyzeLtfTrendContinuation();
       }
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
void AnalyzeLtfTrendContinuation()
{ 
   MqlRates rates[]; if(CopyRates(_Symbol, _Period, 0, 5, rates) < 5) return; ArraySetAsSeries(rates, true);
   MqlRates pivot_bar = rates[2];
   double currentAtr = GetAtrValue(); if(currentAtr == 0) return;
   
   if(CurrentState == TRACKING_IMPULSE){ if(CurrentTrend == UP){ if(pivot_bar.high > CurrentImpulseHigh.price) { CurrentImpulseHigh.price = pivot_bar.high;
   CurrentImpulseHigh.time = pivot_bar.time;
   } if(IsUpTrendPullback(0) && pivot_bar.time > lastTradeSetupTime) { double pullbackDepth = (CurrentImpulseHigh.price - pivot_bar.low);
   if(pullbackDepth >= MinPullbackAtrMult * currentAtr){ CurrentPullbackLow.price = pivot_bar.low; CurrentPullbackLow.time = pivot_bar.time; lastTradeSetupTime = pivot_bar.time; CurrentState = AWAITING_CONTINUATION; if(IsValidPullbackStructure(2, UP)) PlaceTrendTrade();
   } } } else if(CurrentTrend == DOWN){ if(pivot_bar.low < CurrentImpulseLow.price) { CurrentImpulseLow.price = pivot_bar.low; CurrentImpulseLow.time = pivot_bar.time;
   } if(IsDownTrendPullback(0) && pivot_bar.time > lastTradeSetupTime){ double pullbackDepth = (pivot_bar.high - CurrentImpulseLow.price); if(pullbackDepth >= MinPullbackAtrMult * currentAtr){ CurrentPullbackHigh.price = pivot_bar.high;
   CurrentPullbackHigh.time = pivot_bar.time; lastTradeSetupTime = pivot_bar.time; CurrentState = AWAITING_CONTINUATION; if(IsValidPullbackStructure(2, DOWN)) PlaceTrendTrade();
   } } } } else if(CurrentState == AWAITING_CONTINUATION){ if(CurrentTrend == UP){ if(pivot_bar.low < CurrentPullbackLow.price) { CurrentPullbackLow.price = pivot_bar.low;
   CurrentPullbackLow.time = pivot_bar.time; } if(pivot_bar.low < SwingLowAnchor.price){ CancelPendingOrders(MagicNumber_Trend); CurrentTrend = DOWN; SwingHighAnchor = CurrentImpulseHigh; CurrentImpulseLow.price = pivot_bar.low; CurrentImpulseLow.time = pivot_bar.time;
   CurrentState = TRACKING_IMPULSE; lastTradeSetupTime = 0; return; } else if(pivot_bar.high > CurrentImpulseHigh.price){ TrailEarlyStopsToNewSwing(CurrentPullbackLow.price, UP); CancelPendingOrders(MagicNumber_Trend); SwingLowAnchor = CurrentPullbackLow;
   CurrentImpulseHigh.price = pivot_bar.high; CurrentImpulseHigh.time = pivot_bar.time; CurrentState = TRACKING_IMPULSE; lastTradeSetupTime = 0; return;
   } if(IsUpTrendPullback(0) && pivot_bar.time > lastTradeSetupTime){ double pullbackDepth = (CurrentImpulseHigh.price - pivot_bar.low); if(pullbackDepth >= MinPullbackAtrMult * currentAtr){ if(IsValidPullbackStructure(2, UP)) PlaceTrendTrade();
   lastTradeSetupTime = pivot_bar.time; } } } else if(CurrentTrend == DOWN){ if(pivot_bar.high > CurrentPullbackHigh.price) { CurrentPullbackHigh.price = pivot_bar.high; CurrentPullbackHigh.time = pivot_bar.time;
   } if(pivot_bar.high > SwingHighAnchor.price){ CancelPendingOrders(MagicNumber_Trend); CurrentTrend = UP; SwingLowAnchor = CurrentImpulseLow; CurrentImpulseHigh.price = pivot_bar.high; CurrentImpulseHigh.time = pivot_bar.time; CurrentState = TRACKING_IMPULSE;
   lastTradeSetupTime = 0; return; } else if(pivot_bar.low < CurrentImpulseLow.price){ TrailEarlyStopsToNewSwing(CurrentPullbackHigh.price, DOWN); CancelPendingOrders(MagicNumber_Trend); SwingHighAnchor = CurrentPullbackHigh; CurrentImpulseLow.price = pivot_bar.low;
   CurrentImpulseLow.time = pivot_bar.time; CurrentState = TRACKING_IMPULSE; lastTradeSetupTime = 0; return;
   } if(IsDownTrendPullback(0) && pivot_bar.time > lastTradeSetupTime){ double pullbackDepth = (pivot_bar.high - CurrentImpulseLow.price); if(pullbackDepth >= MinPullbackAtrMult * currentAtr){ if(IsValidPullbackStructure(2, DOWN)) PlaceTrendTrade();
   lastTradeSetupTime = pivot_bar.time; } } } } }

void PlaceTrendTrade()
{ 
   double totalRiskPercent = (EnableAdaptiveRisk && IsPrimeSetup()) ?
   PrimeRiskPercentage : RiskPerEntryPercent;
   if(!PerformPreFlightChecks(totalRiskPercent)) return;
   
   if(!IsVolatilityFavorable()) return; 
   double adaptiveTakeProfitRR = Trend_BaseTakeProfitRR; double adaptiveSlAtrMult = Trend_BaseSlAtrMult;
   if(EnableVolatilityEngine){ switch(CurrentVolatilityRegime){ case VOL_LOW: adaptiveTakeProfitRR *= Trend_LowVolRRMultiplier; break; case VOL_HIGH: adaptiveTakeProfitRR *= Trend_HighVolRRMultiplier; adaptiveSlAtrMult *= Trend_HighVolSlAtrMultiplier; break; case VOL_EXTREME: return;
   } } 
   if(!EnableMultiHtfFilter || NumberOfHtfs < HTF_COUNT_1) return; 
   ENUM_TREND requiredTrend = NO_TREND; TimeframeState htf1 = HtfStates[0];
   if(htf1.currentTrend == UP && IsPriceAlignedWithEma(htf1.timeframe, htf1.emaHandle, UP, Htf_EnableEmaFilter_Inputs[0])) requiredTrend = UP;
   else if(htf1.currentTrend == DOWN && IsPriceAlignedWithEma(htf1.timeframe, htf1.emaHandle, DOWN, Htf_EnableEmaFilter_Inputs[0])) requiredTrend = DOWN; 
   if(requiredTrend == NO_TREND) return;
   for(int i = 1; i < (int)NumberOfHtfs; i++){ if(HtfStates[i].currentTrend != requiredTrend || !IsPriceAlignedWithEma(HtfStates[i].timeframe, HtfStates[i].emaHandle, requiredTrend, Htf_EnableEmaFilter_Inputs[i])) return;
   } 
   if(CurrentTrend != requiredTrend || !IsPriceAlignedWithEma(_Period, ltfEmaHandle, requiredTrend, EnableEmaFilter)) return; 
   
   trade.SetExpertMagicNumber(MagicNumber_Trend);
   double stopLoss=0, takeProfit=0, range_val=0;
   double stopLossBuffer = GetAtrValue() * adaptiveSlAtrMult;
   double retracements[] = {0.61, 0.705, 0.75}; double weights[] = {0.6, 0.3, 0.1};
   
   if(CurrentTrend == UP)
   { 
      if(!AllowHedging && HasOppositePosition(ORDER_TYPE_BUY)) return;
      range_val = CurrentImpulseHigh.price - SwingLowAnchor.price; if(range_val <= 0) return; 
      stopLoss = SwingLowAnchor.price - stopLossBuffer; 
      UpdatePendingOrders(stopLoss, MagicNumber_Trend, adaptiveTakeProfitRR);
      for(int i = 0; i < ArraySize(retracements); i++)
      { 
         double entryPrice = CurrentImpulseHigh.price - (range_val * retracements[i]);
         double riskDistance = entryPrice - stopLoss; if(riskDistance <= 0) continue; 
         takeProfit = entryPrice + (riskDistance * adaptiveTakeProfitRR);
         double thisRiskPercent = totalRiskPercent * weights[i]; 
         double lotSize = CalculateLotSize(stopLoss, entryPrice, thisRiskPercent);
         if(lotSize > 0 && entryPrice < SymbolInfoDouble(_Symbol, SYMBOL_ASK)) 
         {
            if(!IsMarginSufficient(lotSize, ORDER_TYPE_BUY_LIMIT)) { Print("Trend: Insufficient margin for limit order, skipping.");
            continue; }
            ExecutePendingOrder(ORDER_TYPE_BUY_LIMIT, lotSize, entryPrice, stopLoss, takeProfit, "");
         }
      } 
   } 
   else if(CurrentTrend == DOWN)
   { 
      if(!AllowHedging && HasOppositePosition(ORDER_TYPE_SELL)) return;
      range_val = SwingHighAnchor.price - CurrentImpulseLow.price; if(range_val <= 0) return;
      stopLoss = SwingHighAnchor.price + stopLossBuffer; 
      UpdatePendingOrders(stopLoss, MagicNumber_Trend, adaptiveTakeProfitRR);
      for(int i = 0; i < ArraySize(retracements); i++)
      { 
         double entryPrice = CurrentImpulseLow.price + (range_val * retracements[i]);
         double riskDistance = stopLoss - entryPrice; if(riskDistance <= 0) continue; 
         takeProfit = entryPrice - (riskDistance * adaptiveTakeProfitRR);
         double thisRiskPercent = totalRiskPercent * weights[i]; 
         double lotSize = CalculateLotSize(stopLoss, entryPrice, thisRiskPercent);
         if(lotSize > 0 && entryPrice > SymbolInfoDouble(_Symbol, SYMBOL_BID))
         {
            if(!IsMarginSufficient(lotSize, ORDER_TYPE_SELL_LIMIT)) { Print("Trend: Insufficient margin for limit order, skipping.");
            continue; }
            ExecutePendingOrder(ORDER_TYPE_SELL_LIMIT, lotSize, entryPrice, stopLoss, takeProfit, "");
         } 
      } 
   } 
}

void AnalyzeHtfMarketStructure(TimeframeState &state)
{
    MqlRates htf_rates[];
    int barsToScan = MathMin(Bars(_Symbol, state.timeframe), HistoryScanBars);
    if(CopyRates(_Symbol, state.timeframe, 0, barsToScan, htf_rates) < 100) return;
    
    ProcessMarketStructure(state, htf_rates, barsToScan, false);
}

void ManageOpenPositions(){ SyncManagedPositions();
   for(int i = 0; i < ArraySize(ManagedPositions); i++){ if(!PositionSelectByTicket(ManagedPositions[i].ticket)) continue;
   long magic = PositionGetInteger(POSITION_MAGIC);
   if(magic != MagicNumber_Trend) continue; double currentProfitPoints = 0; long positionType = PositionGetInteger(POSITION_TYPE); double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
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
   if(PositionSelectByTicket(ticket)){ long magic = PositionGetInteger(POSITION_MAGIC); if(magic == MagicNumber_Trend && PositionGetString(POSITION_SYMBOL) == _Symbol){ bool isTracked = false;
   for(int j = 0; j < ArraySize(ManagedPositions); j++) if(ManagedPositions[j].ticket == ticket) isTracked = true;
   if(!isTracked){ int newSize = ArraySize(ManagedPositions) + 1; ArrayResize(ManagedPositions, newSize); ManagedPositions[newSize-1].ticket = ticket; ManagedPositions[newSize-1].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   ManagedPositions[newSize-1].initialRiskPoints = MathAbs(ManagedPositions[newSize-1].entryPrice - PositionGetDouble(POSITION_SL)) / _Point; ManagedPositions[newSize-1].managementPhase = PHASE_INITIAL;
   } } } } for(int i = ArraySize(ManagedPositions) - 1; i >= 0; i--){ if(!PositionSelectByTicket(ManagedPositions[i].ticket)){ for(int j = i; j < ArraySize(ManagedPositions) - 1; j++) ManagedPositions[j] = ManagedPositions[j+1];
   ArrayResize(ManagedPositions, ArraySize(ManagedPositions) - 1); } } }

void UpdateDashboard(){ static datetime last_update = 0; if(TimeCurrent() - last_update < 1) return;
   last_update = TimeCurrent(); string status_text; color status_color; if(isTradingStoppedForWeek) { status_text = "STOPPED (WEEKLY)"; status_color = clrRed;
   } else if(isTradingStoppedForDay) { status_text = "STOPPED (DAILY)"; status_color = clrRed; } else { status_text = "ACTIVE"; status_color = clrLimeGreen;
   } 
   int y_pos = 15, y_step = 16; DrawDashboardLabel("Title", 15, y_pos, "MAIshe (Trend Only)", clrWhite, 10);
   y_pos += y_step + 5;
   DrawDashboardLabel("Status", 15, y_pos, "Status: " + status_text, status_color); y_pos += y_step;
   ChartRedraw(0);
}
void DrawDashboardLabel(string name, int x, int y, string text, color clr, int font_size=9){ string obj_name = "EA_DASH_" + name;
   if(ObjectFind(0, obj_name) < 0){ ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER); ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, font_size); ObjectSetString(0, obj_name, OBJPROP_FONT, "Calibri"); } ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr); }

void CheckEquityStopLoss(){ if(!EnableEquityStop || isTradingStoppedForDay || isTradingStoppedForWeek) return; double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double stopLossLevel = startOfDayBalance * (1 - (MaxEquityLossPercent / 100.0)); if(currentEquity <= stopLossLevel) CloseAllAndStopTrading(false); }

void CheckProfitLossLimits(){ datetime now = TimeCurrent();
   if(now >= currentWeekStart + (7 * 86400)){ MqlDateTime dt; TimeToStruct(now, dt); int day_of_week = dt.day_of_week == 0 ?
   7 : dt.day_of_week; currentWeekStart = now - ((day_of_week - 1) * 86400) - (now % 86400); startOfWeekBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   isTradingStoppedForWeek = false; isTradingStoppedForDay = false; } if(now >= currentDayStart + 86400){ currentDayStart = now - (now % 86400);
   startOfDayBalance = AccountInfoDouble(ACCOUNT_BALANCE); isTradingStoppedForDay = false; } if(isTradingStoppedForWeek || isTradingStoppedForDay) return; double weeklyProfitPercent = (startOfWeekBalance > 0) ?
   (CalculateProfitForPeriod(currentWeekStart) / startOfWeekBalance) * 100 : 0; if(MaxWeeklyProfitPercent > 0 && weeklyProfitPercent >= MaxWeeklyProfitPercent){ if(!isTradingStoppedForWeek) CloseAllAndStopTrading(true); return;
   } double dailyProfitPercent = (startOfDayBalance > 0) ? (CalculateProfitForPeriod(currentDayStart) / startOfDayBalance) * 100 : 0;
   if(MaxDailyProfitPercent > 0 && dailyProfitPercent >= MaxDailyProfitPercent){ if(!isTradingStoppedForDay) CloseAllAndStopTrading(false); return; } if(MaxDailyLossPercent > 0 && dailyProfitPercent <= -MaxDailyLossPercent){ if(!isTradingStoppedForDay) CloseAllAndStopTrading(false);
   return; } }
double CalculateProfitForPeriod(datetime startTime){ HistorySelect(startTime, TimeCurrent()); double totalProfit = 0;
   for(int i = 0; i < HistoryDealsTotal(); i++){ ulong ticket = HistoryDealGetTicket(i); long magic = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
   if(magic == MagicNumber_Trend && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) totalProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
   } for(int i = PositionsTotal() - 1; i >= 0; i--){ if(PositionSelectByTicket(PositionGetTicket(i))){ long magic = PositionGetInteger(POSITION_MAGIC);
   if(magic == MagicNumber_Trend) totalProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP); } } return totalProfit;
   }
void CloseAllAndStopTrading(bool stopForWeek){ if(stopForWeek) isTradingStoppedForWeek = true;
   isTradingStoppedForDay = true; CancelPendingOrders(MagicNumber_Trend);
   for(int i = PositionsTotal() - 1; i >= 0; i--){ ulong ticket = PositionGetTicket(i);
   if(PositionSelectByTicket(ticket)){ long magic = PositionGetInteger(POSITION_MAGIC);
   if(magic == MagicNumber_Trend) trade.PositionClose(ticket); } } }
void UpdateVolatilityRegime(){ if(!EnableVolatilityEngine || !isVolatilityFilterActive) return; double short_atr_buffer[], long_atr_buffer[];
   if(CopyBuffer(shortAtrOnHtfHandle, 0, 1, 1, short_atr_buffer) < 1 || CopyBuffer(longAtrHandle, 0, 1, 1, long_atr_buffer) < 1 || long_atr_buffer[0] <= 0){ currentVolatilityIndex = 1.0;
   CurrentVolatilityRegime = VOL_NORMAL; return; } currentVolatilityIndex = short_atr_buffer[0] / long_atr_buffer[0]; ENUM_VOLATILITY_REGIME previousRegime = CurrentVolatilityRegime; if(currentVolatilityIndex < Volatility_LowThreshold) CurrentVolatilityRegime = VOL_LOW;
   else if(currentVolatilityIndex < Volatility_NormalThreshold) CurrentVolatilityRegime = VOL_NORMAL; else if(currentVolatilityIndex < Volatility_HighThreshold) CurrentVolatilityRegime = VOL_HIGH; else CurrentVolatilityRegime = VOL_EXTREME;
}

void InitializeHtfStateFromHistory(TimeframeState &state)
{
   MqlRates htf_rates[];
   int barsToScan = MathMin(Bars(_Symbol, state.timeframe), HistoryScanBars);
   if(CopyRates(_Symbol, state.timeframe, 0, barsToScan, htf_rates) < 100) return;
   
   ProcessMarketStructure(state, htf_rates, barsToScan, false);
}

void InitializeStateFromHistory()
{
   MqlRates rates[];
   int barsToScan = MathMin(Bars(_Symbol, _Period), HistoryScanBars);
   if(CopyRates(_Symbol, _Period, 0, barsToScan, rates) < 100) return;

   TimeframeState ltfState;
   ltfState.timeframe = _Period;

   ProcessMarketStructure(ltfState, rates, barsToScan, true);

   CurrentTrend = ltfState.currentTrend;
   CurrentState = ltfState.currentState;
   SwingLowAnchor = ltfState.swingLowAnchor;
   SwingHighAnchor = ltfState.swingHighAnchor;
   CurrentImpulseHigh = ltfState.currentImpulseHigh;
   CurrentImpulseLow = ltfState.currentImpulseLow;
   CurrentPullbackLow = ltfState.currentPullbackLow;
   CurrentPullbackHigh = ltfState.currentPullbackHigh;
}

// --- REPAIRED --- The 'const' keyword was removed from MqlRates &rates[] to fix the compiler error.
void ProcessMarketStructure(TimeframeState &state, MqlRates &rates[], int barsToScan, bool isLtf)
{
   int tempAtrHandle = iATR(_Symbol, state.timeframe, AtrPeriod);
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

   for(int i = startBar; i < bars_to_process; i++)
   {
      MqlRates bar_curr = rates[i];
      MqlRates bar_pivot = rates[i - 2];

      if(state.currentState == TRACKING_IMPULSE)
      {
         if(state.currentTrend == UP)
         {
            if(bar_curr.high > state.currentImpulseHigh.price) { state.currentImpulseHigh.price = bar_curr.high; state.currentImpulseHigh.time = bar_curr.time; }
            if(IsUpTrendPullback_Historical(i, rates, atr_values[i-2]))
            {
               state.currentPullbackLow.price = bar_pivot.low; state.currentPullbackLow.time = bar_pivot.time; state.currentState = AWAITING_CONTINUATION;
            }
         }
         else if(state.currentTrend == DOWN)
         {
            if(bar_curr.low < state.currentImpulseLow.price) { state.currentImpulseLow.price = bar_curr.low; state.currentImpulseLow.time = bar_curr.time; }
            if(IsDownTrendPullback_Historical(i, rates, atr_values[i-2]))
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
               if(isLtf) DrawChoChLine("EA_", state.swingLowAnchor.time, state.swingLowAnchor.price, bar_curr.time, state.swingLowAnchor.price, "ChoCh Down");
               state.currentTrend = DOWN; state.swingHighAnchor = state.currentImpulseHigh; state.currentImpulseLow.price = bar_curr.low;
               state.currentImpulseLow.time = bar_curr.time; state.currentState = TRACKING_IMPULSE; state.lastBmsTime = bar_curr.time; state.lastChochTime = bar_curr.time;
            }
            else if(bar_curr.high > state.currentImpulseHigh.price) // BMS
            {
               if(isLtf) DrawBMSLine("EA_", state.currentImpulseHigh.time, state.currentImpulseHigh.price, bar_curr.time, state.currentImpulseHigh.price, "BMS Up");
               state.swingLowAnchor = state.currentPullbackLow; state.currentImpulseHigh.price = bar_curr.high; state.currentImpulseHigh.time = bar_curr.time;
               state.currentState = TRACKING_IMPULSE; state.lastBmsTime = bar_curr.time;
            }
         }
         else if(state.currentTrend == DOWN)
         {
            if(bar_curr.high > state.currentPullbackHigh.price) { state.currentPullbackHigh.price = bar_curr.high; state.currentPullbackHigh.time = bar_curr.time; }
            if(bar_curr.high > state.swingHighAnchor.price) // ChoCh
            {
               if(isLtf) DrawChoChLine("EA_", state.swingHighAnchor.time, state.swingHighAnchor.price, bar_curr.time, state.swingHighAnchor.price, "ChoCh Up");
               state.currentTrend = UP; state.swingLowAnchor = state.currentImpulseLow; state.currentImpulseHigh.price = bar_curr.high;
               state.currentImpulseHigh.time = bar_curr.time; state.currentState = TRACKING_IMPULSE; state.lastBmsTime = bar_curr.time; state.lastChochTime = bar_curr.time;
            }
            else if(bar_curr.low < state.currentImpulseLow.price) // BMS
            {
               if(isLtf) DrawBMSLine("EA_", state.currentImpulseLow.time, state.currentImpulseLow.price, bar_curr.time, state.currentImpulseLow.price, "BMS Down");
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
double GetAtrValue(){ double atr_buffer[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atr_buffer) > 0) return atr_buffer[0]; return 0; }
   
double GetAtrValueAtBar(int shift, ENUM_TIMEFRAMES tf, int handle) {
    double atr_buffer[1];
    if (CopyBuffer(handle, 0, shift + 1, 1, atr_buffer) > 0) return atr_buffer[0]; // shift+1 to get value of previous bar
    return 0;
}

bool IsVolatilityFavorable(){ if(!isVolatilityFilterActive) return true;
   if(EnableVolatilityEngine && CurrentVolatilityRegime == VOL_EXTREME) return false; double short_atr_buffer[], long_atr_buffer[];
   if(CopyBuffer(shortAtrOnHtfHandle, 0, 1, 1, short_atr_buffer) < 1 || CopyBuffer(longAtrHandle, 0, 1, 1, long_atr_buffer) < 1) return false;
   if(short_atr_buffer[0] <= 0 || long_atr_buffer[0] <= 0) return false; if(short_atr_buffer[0] < long_atr_buffer[0] * MinVolatilityMultiplier) return false;
   if(short_atr_buffer[0] > long_atr_buffer[0] * MaxVolatilityMultiplier) return false; return true; }
   
bool IsPriceAlignedWithEma(ENUM_TIMEFRAMES timeframe, int handle, ENUM_TREND requiredTrend, bool isEnabled){ if(!isEnabled || handle == INVALID_HANDLE) return true;
   double ema_buffer[]; MqlRates rates[]; if(CopyBuffer(handle, 0, 1, 1, ema_buffer) > 0 && CopyRates(_Symbol, timeframe, 1, 1, rates) > 0){ if(requiredTrend == UP && rates[0].close < ema_buffer[0]) return false;
   if(requiredTrend == DOWN && rates[0].close > ema_buffer[0]) return false; } else return false; return true;
}
bool HasOppositePosition(ENUM_ORDER_TYPE orderType){ bool has_buy = false, has_sell = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--){ if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetString(POSITION_SYMBOL) == _Symbol){ if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) has_buy = true;
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) has_sell = true; } } if(orderType == ORDER_TYPE_BUY && has_sell) return true;
   if(orderType == ORDER_TYPE_SELL && has_buy) return true; return false; }

bool IsPrimeSetup()
{
    if(NumberOfHtfs < HTF_COUNT_3) return false;
    if(HtfStates[0].currentTrend != CurrentTrend || HtfStates[1].currentTrend != CurrentTrend || HtfStates[2].currentTrend != CurrentTrend) return false;
    if(CurrentVolatilityRegime != VOL_NORMAL) return false;
    datetime lastBmsOnHtf1 = HtfStates[0].lastBmsTime;
    if(lastBmsOnHtf1 > 0)
    {
      int barsSinceBms = iBarShift(_Symbol, _Period, lastBmsOnHtf1);
      if(barsSinceBms < 0 || barsSinceBms > (int)(PeriodSeconds(HtfStates[0].timeframe)/PeriodSeconds(_Period)) * 3) return false;
    }
    double avgBody = GetAverageBodySize(AvgBodyPeriod);
    if(avgBody <= 0) return false;
    if(CurrentTrend == UP) { if((CurrentImpulseHigh.price - SwingLowAnchor.price) < (avgBody * ImpulseCandleMultiplier)) return false; }
    else if(CurrentTrend == DOWN) { if((SwingHighAnchor.price - CurrentImpulseLow.price) < (avgBody * ImpulseCandleMultiplier)) return false; }
    return true;
}

double GetAverageBodySize(int period)
{
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, period, rates) < period) return 0.0;
    double totalBodySize = 0;
    for(int i = 0; i < period; i++) { totalBodySize += MathAbs(rates[i].open - rates[i].close); }
    return totalBodySize / period;
}


void TrailEarlyStopsToNewSwing(double newSwingPrice, ENUM_TREND direction){ double stopLossBuffer = GetAtrValue() * Trend_BaseSlAtrMult;
   for(int i = 0; i < ArraySize(ManagedPositions); i++){ if(PositionSelectByTicket(ManagedPositions[i].ticket) && PositionGetInteger(POSITION_MAGIC) == MagicNumber_Trend && ManagedPositions[i].managementPhase == PHASE_INITIAL){ long positionType = PositionGetInteger(POSITION_TYPE);
   double newStopLoss = 0; if(direction == UP && positionType == POSITION_TYPE_BUY){ newStopLoss = newSwingPrice - stopLossBuffer;
   if(newStopLoss > PositionGetDouble(POSITION_SL)){ if(trade.PositionModify(ManagedPositions[i].ticket, newStopLoss, PositionGetDouble(POSITION_TP))) ManagedPositions[i].initialRiskPoints = MathAbs(ManagedPositions[i].entryPrice - newStopLoss) / _Point;
   } } else if(direction == DOWN && positionType == POSITION_TYPE_SELL){ newStopLoss = newSwingPrice + stopLossBuffer;
   if(newStopLoss < PositionGetDouble(POSITION_SL)){ if(trade.PositionModify(ManagedPositions[i].ticket, newStopLoss, PositionGetDouble(POSITION_TP))) ManagedPositions[i].initialRiskPoints = MathAbs(ManagedPositions[i].entryPrice - newStopLoss) / _Point;
   } } } } }

bool IsUpTrendPullback(int shift)
{
    MqlRates r[]; if(CopyRates(_Symbol, _Period, shift, 5, r) < 5) return false; ArraySetAsSeries(r, true);
    bool isFractal = (r[2].low < r[0].low && r[2].low < r[1].low && r[2].low < r[3].low && r[2].low < r[4].low);
    if(!isFractal || iBarShift(_Symbol, _Period, CurrentImpulseHigh.time) <= shift + 2) return false;
    double swingAtr = GetAtrValueAtBar(shift, _Period, atrHandle); if(swingAtr <= 0) return false;
    double swingRange = r[1].high - r[2].low; if(swingRange < (swingAtr * SwingConfirmationAtrMult)) return false;
    return true;
}

bool IsDownTrendPullback(int shift)
{
    MqlRates r[]; if(CopyRates(_Symbol, _Period, shift, 5, r) < 5) return false; ArraySetAsSeries(r, true);
    bool isFractal = (r[2].high > r[0].high && r[2].high > r[1].high && r[2].high > r[3].high && r[2].high > r[4].high);
    if(!isFractal || iBarShift(_Symbol, _Period, CurrentImpulseLow.time) <= shift + 2) return false;
    double swingAtr = GetAtrValueAtBar(shift, _Period, atrHandle); if(swingAtr <= 0) return false;
    double swingRange = r[2].high - r[1].low; if(swingRange < (swingAtr * SwingConfirmationAtrMult)) return false;
    return true;
}

bool IsUpTrendPullback_Historical(int i, const MqlRates &rates[], double atr_value)
{
    if(i < 4) return false;
    bool isFractal = (rates[i - 2].low < rates[i - 4].low && rates[i - 2].low < rates[i - 3].low && rates[i - 2].low < rates[i - 1].low && rates[i - 2].low < rates[i].low);
    if(!isFractal) return false;
    
    if(atr_value <= 0) return false;
    double swingRange = rates[i - 3].high - rates[i - 2].low;
    if(swingRange < (atr_value * SwingConfirmationAtrMult)) return false;
    
    return true;
}

bool IsDownTrendPullback_Historical(int i, const MqlRates &rates[], double atr_value)
{
    if(i < 4) return false;
    bool isFractal = (rates[i - 2].high > rates[i - 4].high && rates[i - 2].high > rates[i - 3].high && rates[i - 2].high > rates[i - 1].high && rates[i - 2].high > rates[i].high);
    if(!isFractal) return false;

    if(atr_value <= 0) return false;
    double swingRange = rates[i - 2].high - rates[i - 3].low;
    if(swingRange < (atr_value * SwingConfirmationAtrMult)) return false;
    
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
int CountCurrentTrades(){ int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--){ if(PositionSelectByTicket(PositionGetTicket(i))){ long magic = PositionGetInteger(POSITION_MAGIC);
   if(magic == MagicNumber_Trend){ count++;
   } } } for(int i = OrdersTotal() - 1; i >= 0; i--){ if(OrderSelect(OrderGetTicket(i))){ long magic = OrderGetInteger(ORDER_MAGIC);
   if(magic == MagicNumber_Trend){ count++;
   } } } return count;}
bool IsValidPullbackStructure(int pivotBarShift, ENUM_TREND trendDirection){ int barsToCopy = pivotBarShift + 10;
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, pivotBarShift, barsToCopy, rates) < 5) return false; ArraySetAsSeries(rates, true); int consecutiveCandles = 0;
   for(int i = 1; i < ArraySize(rates); i++){ bool isCounterCandle = (trendDirection == UP) ?
   (rates[i].close < rates[i].open) : (rates[i].close > rates[i].open); if(isCounterCandle){ consecutiveCandles++; if(consecutiveCandles >= 3) return true; } else consecutiveCandles = 0;
   } return false; }
void DrawBMSLine(string prefix, datetime t1, double p1, datetime t2, double p2, string txt){ string name = prefix + "BMS_" + (string)t1;
   if(ObjectFind(0, name) < 0){ ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2); ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue); ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT); } }
void DrawChoChLine(string prefix, datetime t1, double p1, datetime t2, double p2, string txt){ string name = prefix + "ChoCh_" + (string)t1;
   if(ObjectFind(0, name) < 0){ ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2); ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrangeRed); ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT); } }
void DrawHtfBMSLine(string prefix, datetime t1, double p1, datetime t2, double p2, string txt){ string name = prefix + "BMS_" + (string)t1;
   if(ObjectFind(0, name) < 0){ ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2); ObjectSetInteger(0, name, OBJPROP_COLOR, clrCornflowerBlue); ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); } }
void DrawHtfChoChLine(string prefix, datetime t1, double p1, datetime t2, double p2, string txt){ string name = prefix + "ChoCh_" + (string)t1;
   if(ObjectFind(0, name) < 0){ ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2); ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange); ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); } }
bool PerformPreFlightChecks(double newTradeRiskPercent){ if(!IsTradingTime()) return false; if(!IsSpreadOK()) return false;
   if(CountCurrentTrades() >= MaxRunningTrades){ Print("Trade aborted: Max running trades (", MaxRunningTrades, ") reached."); return false; } if(!IsTotalRiskOK(newTradeRiskPercent)) return false;
   return true;
}
bool ExecuteMarketOrder(ENUM_ORDER_TYPE orderType, double lot, double sl, double tp, string comment){ trade.SetDeviationInPoints(MaxSlippagePoints);
   for(int i = 0; i < OrderRetries; i++){ bool result = (orderType == ORDER_TYPE_BUY) ?
   trade.Buy(lot, _Symbol, 0, sl, tp, comment) : trade.Sell(lot, _Symbol, 0, sl, tp, comment);
   if(result){ Print("Market order successful. Ticket: ", trade.ResultOrder());
   return true; } else { uint retcode = trade.ResultRetcode();
   Print("Market order failed attempt #", i+1, ". Reason: ", trade.ResultComment(), " (Code: ", retcode, ")");
   if(retcode == 10004 || retcode == 10006 || retcode == 10008){ Sleep(RetryDelayMs); continue; } else { return false;
   } } } return false; }
bool ExecutePendingOrder(ENUM_ORDER_TYPE orderType, double lot, double entry, double sl, double tp, string comment){ if(MQLInfoInteger(MQL_TESTER) && SimulatedSlippagePoints > 0){ double slippage = SimulatedSlippagePoints * _Point;
   if(orderType == ORDER_TYPE_BUY_LIMIT) entry += slippage; if(orderType == ORDER_TYPE_SELL_LIMIT) entry -= slippage; } bool result = false;
   if(orderType == ORDER_TYPE_BUY_LIMIT) result = trade.BuyLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
   if(orderType == ORDER_TYPE_SELL_LIMIT) result = trade.SellLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
   if(result){ Print("Pending order placed successfully. Ticket: ", trade.ResultOrder());
   } else { Print("Pending order failed. Reason: ", trade.ResultComment(), " (Code: ", trade.ResultRetcode(), ")");
   } return result;
   }
bool IsSpreadOK(){ double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pipSize = _Point * ( (_Digits == 3 || _Digits == 5) ? 10 : 1 );
   double maxAllowedSpread = MaxSpreadPips * pipSize; if(spread > maxAllowedSpread){ Print("Trade aborted: Spread (", spread/_Point, " pts) exceeds max allowed (", maxAllowedSpread/_Point, " pts).");
   return false; } return true; }
bool IsMarginSufficient(double lots, ENUM_ORDER_TYPE orderType){ double margin_required = 0;
   if(!OrderCalcMargin(orderType, _Symbol, lots, SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin_required)){ Print("Could not calculate required margin. Aborting trade."); return false;
   } if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin_required){ Print("Trade aborted: Insufficient free margin. Required: ", margin_required, ", Available: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE)); return false;
   } return true; }
bool IsTradingTime(){ if(!EnableTimeFilter) return true; MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < TradeAllowedFromHour || dt.hour >= TradeAllowedToHour){ return false; } if(BlockMinutesAfterMarketOpen > 0){ if(TimeCurrent() < (currentDayStart + (BlockMinutesAfterMarketOpen * 60))){ return false;
   } } return true; }
bool IsTotalRiskOK(double newTradeRiskPercent){ if(MaxTotalRiskPercent <= 0) return true; double totalRisk = 0; double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountEquity <= 0) return false; for(int i = PositionsTotal() - 1; i >= 0; i--){ if(PositionSelectByTicket(PositionGetTicket(i))){ if(PositionGetString(POSITION_SYMBOL) == _Symbol){ long magic = PositionGetInteger(POSITION_MAGIC);
   if(magic == MagicNumber_Trend){ double open_price = PositionGetDouble(POSITION_PRICE_OPEN); double sl = PositionGetDouble(POSITION_SL);
   double lots = PositionGetDouble(POSITION_VOLUME);
   if(sl != 0){ double riskAmount = MathAbs(open_price - sl) * lots * (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
   totalRisk += (riskAmount / accountEquity) * 100.0; } } } } } for(int i = OrdersTotal() - 1; i >= 0; i--){ if(OrderSelect(OrderGetTicket(i))){ if(OrderGetString(ORDER_SYMBOL) == _Symbol){ long magic = (long)OrderGetInteger(ORDER_MAGIC);
   if(magic == MagicNumber_Trend){ double open_price = OrderGetDouble(ORDER_PRICE_OPEN); double sl = OrderGetDouble(ORDER_SL);
   double lots = OrderGetDouble(ORDER_VOLUME_INITIAL);
   if (sl != 0){ double riskAmount = MathAbs(open_price - sl) * lots * (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
   totalRisk += (riskAmount / accountEquity) * 100.0; } } } } } if(totalRisk + newTradeRiskPercent > MaxTotalRiskPercent){ Print("Trade aborted: New trade would exceed max total risk. Current Risk: ", DoubleToString(totalRisk, 2), "%, New Trade Risk: ", DoubleToString(newTradeRiskPercent,2), "%, Limit: ", MaxTotalRiskPercent, "%");
   return false; } return true; }