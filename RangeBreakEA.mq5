//+------------------------------------------------------------------+
//|                                                      RangeBreakEA.mq5 |
//|                        Copyright 2023, MetaQuotes Ltd.             |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- includes
#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Indicators/Trend.mqh>
#include <Arrays/ArrayObj.mqh>

//--- input parameters
input int      MagicNumber = 12345;          // Magic Number
input double   LotSize = 0.1;                // Lot Size
input int      StopLossPips = 50;            // Stop Loss (pips)
input int      TakeProfitPips = 100;         // Take Profit (pips)
input int      Slippage = 3;                 // Slippage (points)
input bool     UseTrailingStop = false;      // Use Trailing Stop
input int      TrailingStopPips = 30;        // Trailing Stop (pips)
input int      TrailingStepPips = 10;        // Trailing Step (pips)

//--- Breakout parameters
input int      BreakoutType = 0;             // 0=Range, 1=BollingerBands, 2=ATR
input bool     AllowLong = true;             // Allow long positions
input bool     AllowShort = true;            // Allow short positions
input bool     RequireVolumeConfirm = true;  // Require volume confirmation
input bool     RequireRetest = false;        // Wait for retest before entry
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1;   // Timeframe for range calculation
input int      TrendFilterEMA = 200;         // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15;   // Timeframe for trade execution

//--- News filter parameters
input bool     UseNewsFilter = true;         // Enable economic news filter
input int      NewsMinutesBefore = 60;       // Minutes before news to suspend trading
input int      NewsMinutesAfter = 30;        // Minutes after news to resume trading
input int      NewsImpactLevel = 3;          // Minimum impact level: 1=low, 2=medium, 3=high
input bool     CloseOnHighImpact = true;     // Close positions before high-impact news

//--- Indicator filter parameters
input bool     UseATRFilter = true;          // Enable ATR filter
input int      ATRPeriod = 14;               // ATR period
input double   MinATRPips = 20;              // Minimum ATR required (pips)
input double   MaxATRPips = 150;             // Maximum ATR allowed (pips)
input double   ATR_Mult_Min = 1.25;          // Minimum ATR multiplier for breakout
input double   ATR_Mult_Max = 3.0;           // Maximum ATR multiplier
input bool     UseBBFilter = true;           // Enable Bollinger Bands filter
input int      BBPeriod = 20;                // Bollinger Bands period
input double   BBDeviation = 2.0;            // Bollinger Bands standard deviation
input double   Min_Width_Pips = 30;          // Minimum BB width (pips)
input double   Max_Width_Pips = 120;         // Maximum BB width (pips)
input bool     UseEMAFilter = true;          // Enable EMA filter
input int      EMAPeriod = 200;              // EMA period for trend filter
input ENUM_TIMEFRAMES EMATf = PERIOD_H1;     // EMA timeframe
input bool     UseADXFilter = true;          // Enable ADX filter
input int      ADXPeriod = 14;               // ADX period
input double   ADXThreshold = 20.0;          // Minimum ADX threshold
input bool     UseRSIFilter = false;         // Enable RSI filter
input int      RSIPeriod = 14;               // RSI period
input double   RSIOverbought = 70;           // RSI overbought level
input double   RSIOversold = 30;             // RSI oversold level
input bool     UseVolumeFilter = true;       // Enable volume filter
input int      VolumeMAPeriod = 20;          // Volume moving average period
input double   VolumeThreshold = 1.5;        // Volume threshold multiplier

//--- Global variables
CTrade          trade;
CSymbolInfo     symbolInfo;
double          point;
double          pipValue;
datetime        lastBarTime = 0;
double          rangeHigh = 0;
double          rangeLow = 0;
bool            isNewsBlocked = false;
bool            isHighImpactNews = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize symbol info
   if(!symbolInfo.Name(_Symbol))
      return INIT_FAILED;
   symbolInfo.RefreshRates();
   point = symbolInfo.Point();
   pipValue = point * 10;
   
   //--- Set trade parameters
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   
   //--- Initialize indicators
   if(!InitializeIndicators())
      return INIT_FAILED;
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up if needed
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar on execution timeframe
   if(!IsNewBar(ExecTF))
      return;
   
   //--- Update symbol info
   symbolInfo.RefreshRates();
   
   //--- Check news filter
   CheckNewsFilter();
   
   //--- Close positions if high impact news is approaching
   if(isHighImpactNews && CloseOnHighImpact)
   {
      CloseAllPositions();
      return;
   }
   
   //--- Skip trading if news blocked
   if(isNewsBlocked)
      return;
   
   //--- Calculate range levels
   CalculateRangeLevels();
   
   //--- Check for breakout signals
   CheckBreakoutSignals();
   
   //--- Manage trailing stop
   if(UseTrailingStop)
      ManageTrailingStop();
}

//+------------------------------------------------------------------+
//| Initialize indicators                                            |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
   // This function would initialize all required indicators
   // For simplicity, we assume indicators are created on-demand
   return true;
}

//+------------------------------------------------------------------+
//| Check for new bar                                                |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES tf)
{
   datetime currentBar = iTime(_Symbol, tf, 0);
   if(lastBarTime != currentBar)
   {
      lastBarTime = currentBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check news filter                                                |
//+------------------------------------------------------------------+
void CheckNewsFilter()
{
   if(!UseNewsFilter)
   {
      isNewsBlocked = false;
      isHighImpactNews = false;
      return;
   }
   
   // This is a placeholder for actual news checking logic
   // In real implementation, you would use FFCal or another news source
   // For this example, we'll simulate the logic
   
   // Simulated news check - always returns false for this example
   isNewsBlocked = false;
   isHighImpactNews = false;
   
   // Actual implementation would:
   // 1. Get upcoming news events
   // 2. Check if any high impact news is within NewsMinutesBefore
   // 3. Set isHighImpactNews accordingly
   // 4. Set isNewsBlocked if within NewsMinutesBefore or NewsMinutesAfter
}

//+------------------------------------------------------------------+
//| Calculate range levels                                           |
//+------------------------------------------------------------------+
void CalculateRangeLevels()
{
   if(BreakoutType != 0)  // Only for range breakout
      return;
   
   // Calculate daily range high and low
   rangeHigh = iHigh(_Symbol, RangeTF, 1);
   rangeLow = iLow(_Symbol, RangeTF, 1);
}

//+------------------------------------------------------------------+
//| Check breakout signals                                           |
//+------------------------------------------------------------------+
void CheckBreakoutSignals()
{
   //--- Check if we can open new positions
   if(PositionsTotal() > 0)
      return;
   
   //--- Check indicator filters
   if(!CheckIndicatorFilters())
      return;
   
   //--- Check volume confirmation
   if(RequireVolumeConfirm && !CheckVolumeConfirmation())
      return;
   
   //--- Check for long breakout
   if(AllowLong && CheckLongBreakout())
   {
      OpenPosition(ORDER_TYPE_BUY);
      return;
   }
   
   //--- Check for short breakout
   if(AllowShort && CheckShortBreakout())
   {
      OpenPosition(ORDER_TYPE_SELL);
      return;
   }
}

//+------------------------------------------------------------------+
//| Check indicator filters                                          |
//+------------------------------------------------------------------+
bool CheckIndicatorFilters()
{
   //--- ATR filter
   if(UseATRFilter)
   {
      double atrValue = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod, 0);
      double atrPips = atrValue / pipValue;
      
      if(atrPips < MinATRPips || atrPips > MaxATRPips)
         return false;
   }
   
   //--- Bollinger Bands filter
   if(UseBBFilter && BreakoutType == 1)
   {
      double bbUpper = iBands(_Symbol, PERIOD_CURRENT, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
      double bbLower = iBands(_Symbol, PERIOD_CURRENT, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
      double bbWidth = (bbUpper - bbLower) / pipValue;
      
      if(bbWidth < Min_Width_Pips || bbWidth > Max_Width_Pips)
         return false;
   }
   
   //--- EMA filter
   if(UseEMAFilter && TrendFilterEMA > 0)
   {
      double emaValue = iMA(_Symbol, EMATf, TrendFilterEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
      double currentPrice = symbolInfo.Ask();
      
      // For long positions, price must be above EMA
      // For short positions, price must be below EMA
      // This check is done in individual breakout checks
   }
   
   //--- ADX filter
   if(UseADXFilter)
   {
      double adxValue = iADX(_Symbol, PERIOD_CURRENT, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 0);
      
      if(adxValue < ADXThreshold)
         return false;
   }
   
   //--- RSI filter
   if(UseRSIFilter)
   {
      double rsiValue = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE, 0);
      
      // Don't buy when overbought, don't sell when oversold
      // This check is done in individual breakout checks
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check volume confirmation                                        |
//+------------------------------------------------------------------+
bool CheckVolumeConfirmation()
{
   if(!UseVolumeFilter)
      return true;
   
   double currentVolume = iVolume(_Symbol, PERIOD_CURRENT, 0);
   double volumeMA = iMAOnArray(/* volume array */, 0, VolumeMAPeriod, 0, MODE_SMA, 0);
   
   // Simplified volume check
   // In real implementation, you would need to calculate volume MA properly
   return currentVolume > (volumeMA * VolumeThreshold);
}

//+------------------------------------------------------------------+
//| Check long breakout                                              |
//+------------------------------------------------------------------+
bool CheckLongBreakout()
{
   double breakoutLevel = 0;
   
   // Determine breakout level based on breakout type
   switch(BreakoutType)
   {
      case 0:  // Range
         breakoutLevel = rangeHigh;
         break;
      case 1:  // Bollinger Bands
         breakoutLevel = iBands(_Symbol, PERIOD_CURRENT, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
         break;
      case 2:  // ATR
         double atrValue = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod, 0);
         breakoutLevel = iClose(_Symbol, PERIOD_CURRENT, 1) + (atrValue * ATR_Mult_Min);
         break;
   }
   
   // Check if price has broken above the level
   if(!IsBreakoutLong(breakoutLevel))
      return false;
   
   // Check retest if required
   if(RequireRetest && !IsRetestLong(breakoutLevel))
      return false;
   
   // Check EMA filter for long
   if(UseEMAFilter && TrendFilterEMA > 0)
   {
      double emaValue = iMA(_Symbol, EMATf, TrendFilterEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
      if(symbolInfo.Ask() <= emaValue)
         return false;
   }
   
   // Check RSI filter for long
   if(UseRSIFilter)
   {
      double rsiValue = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE, 0);
      if(rsiValue >= RSIOverbought)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check short breakout                                             |
//+------------------------------------------------------------------+
bool CheckShortBreakout()
{
   double breakoutLevel = 0;
   
   // Determine breakout level based on breakout type
   switch(BreakoutType)
   {
      case 0:  // Range
         breakoutLevel = rangeLow;
         break;
      case 1:  // Bollinger Bands
         breakoutLevel = iBands(_Symbol, PERIOD_CURRENT, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
         break;
      case 2:  // ATR
         double atrValue = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod, 0);
         breakoutLevel = iClose(_Symbol, PERIOD_CURRENT, 1) - (atrValue * ATR_Mult_Min);
         break;
   }
   
   // Check if price has broken below the level
   if(!IsBreakoutShort(breakoutLevel))
      return false;
   
   // Check retest if required
   if(RequireRetest && !IsRetestShort(breakoutLevel))
      return false;
   
   // Check EMA filter for short
   if(UseEMAFilter && TrendFilterEMA > 0)
   {
      double emaValue = iMA(_Symbol, EMATf, TrendFilterEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
      if(symbolInfo.Bid() >= emaValue)
         return false;
   }
   
   // Check RSI filter for short
   if(UseRSIFilter)
   {
      double rsiValue = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE, 0);
      if(rsiValue <= RSIOversold)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for long breakout                                          |
//+------------------------------------------------------------------+
bool IsBreakoutLong(double level, double tolerancePips = 0)
{
   double ask = symbolInfo.Ask();
   return ask > level + tolerancePips * pipValue;
}

//+------------------------------------------------------------------+
//| Check for short breakout                                         |
//+------------------------------------------------------------------+
bool IsBreakoutShort(double level, double tolerancePips = 0)
{
   double bid = symbolInfo.Bid();
   return bid < level - tolerancePips * pipValue;
}

//+------------------------------------------------------------------+
//| Check retest for long                                            |
//+------------------------------------------------------------------+
bool IsRetestLong(double level)
{
   double tol = 0;  // Retest tolerance would be an input parameter
   double lowBar = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

//+------------------------------------------------------------------+
//| Check retest for short                                           |
//+------------------------------------------------------------------+
bool IsRetestShort(double level)
{
   double tol = 0;  // Retest tolerance would be an input parameter
   double highBar = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Open position                                                    |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   double price = (orderType == ORDER_TYPE_BUY) ? symbolInfo.Ask() : symbolInfo.Bid();
   double sl = 0;
   double tp = 0;
   
   // Calculate stop loss and take profit
   if(StopLossPips > 0)
   {
      sl = (orderType == ORDER_TYPE_BUY) ? price - StopLossPips * pipValue : price + StopLossPips * pipValue;
   }
   
   if(TakeProfitPips > 0)
   {
      tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfitPips * pipValue : price - TakeProfitPips * pipValue;
   }
   
   // Open the position
   trade.PositionOpen(_Symbol, orderType, LotSize, price, sl, tp, "Range Breakout");
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            trade.PositionClose(PositionGetTicket(i));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stop                                             |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            ulong ticket = PositionGetTicket(i);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            if(posType == POSITION_TYPE_BUY)
            {
               double newSL = currentPrice - TrailingStopPips * pipValue;
               if(newSL > currentSL && newSL > openPrice)
               {
                  trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
               }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               double newSL = currentPrice + TrailingStopPips * pipValue;
               if(newSL < currentSL && newSL < openPrice)
               {
                  trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+