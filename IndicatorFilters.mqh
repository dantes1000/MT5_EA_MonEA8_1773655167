#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| IndicatorFilters.mqh                                             |
//| Implements ATR, Bollinger Bands, EMA, ADX, RSI, and volume filters |
//+------------------------------------------------------------------+

// Input parameters
input bool     AllowLong = true;                // Allow long positions
input bool     AllowShort = true;               // Allow short positions
input bool     RequireVolumeConfirm = true;     // Require volume confirmation
input bool     RequireRetest = false;           // Wait for retest before entry
input int      BreakoutType = 0;                // 0=Range, 1=BollingerBands, 2=ATR
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1;      // Timeframe for range calculation
input int      TrendFilterEMA = 200;            // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15;      // Timeframe for trade execution
input bool     UseNewsFilter = true;            // Enable economic news filter
input int      NewsMinutesBefore = 60;          // Minutes before news to suspend trading
input int      NewsMinutesAfter = 30;           // Minutes after news to resume trading
input int      NewsImpactLevel = 3;             // Minimum impact level: 1=low, 2=medium, 3=high
input bool     CloseOnHighImpact = true;        // Close positions before high impact news

// Filter thresholds
input double   MinATR = 0.0005;                 // Minimum ATR for volatility filter
input double   MaxATR = 0.0050;                 // Maximum ATR for volatility filter
input double   ATRBreakoutMultiplier = 1.0;     // ATR multiplier for breakout confirmation
input double   MinBBWidth = 0.0010;             // Minimum Bollinger Bands width
input double   MaxBBWidth = 0.0100;             // Maximum Bollinger Bands width
input double   MinADX = 20.0;                   // Minimum ADX for trend strength
input double   RSIOverbought = 70.0;            // RSI overbought level
input double   RSIOversold = 30.0;              // RSI oversold level
input double   VolumeThreshold = 1.5;           // Volume multiplier threshold
input int      VolumeSMAPeriod = 20;            // Volume SMA period

// Trading hours
input int      LondonOpenHour = 8;              // London open hour (GMT)
input int      LondonOpenMinute = 0;            // London open minute (GMT)
input int      FridayCloseHour = 21;            // Friday close hour (GMT)
input int      FridayCloseMinute = 0;           // Friday close minute (GMT)

// Global variables
int            atrHandle;
int            bbHandle;
int            emaHandle;
int            adxHandle;
int            rsiHandle;
int            volumeSMAHandle;
datetime       lastBarTime = 0;

//+------------------------------------------------------------------+
//| New bar detection                                                |
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
//| Breakout entry                                                   |
//+------------------------------------------------------------------+
bool IsBreakoutLong(double level, double tolerancePips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ask > level + tolerancePips * point * 10;
}

bool IsBreakoutShort(double level, double tolerancePips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return bid < level - tolerancePips * point * 10;
}

//+------------------------------------------------------------------+
//| Retest check after breakout                                      |
//+------------------------------------------------------------------+
bool IsRetestLong(double level, double RetestTolerancePips = 5)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = RetestTolerancePips * point * 10;
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level, double RetestTolerancePips = 5)
{
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol      = RetestTolerancePips * point * 10;
   double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Get indicator value                                              |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value[1];
   if(CopyBuffer(handle, buffer, shift, 1, value) <= 0)
      return 0.0;
   return value[0];
}

//+------------------------------------------------------------------+
//| Trend entry (MA crossover)                                       |
//+------------------------------------------------------------------+
bool IsTrendLong(int fastHandle, int slowHandle, int SignalShift = 0)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, SignalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, SignalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, SignalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, SignalShift + 1);
   return (fast1 <= slow1 && fast0 > slow0);
}

bool IsTrendShort(int fastHandle, int slowHandle, int SignalShift = 0)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, SignalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, SignalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, SignalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, SignalShift + 1);
   return (fast1 >= slow1 && fast0 < slow0);
}

//+------------------------------------------------------------------+
//| Initialize indicators                                            |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   // ATR
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(atrHandle == INVALID_HANDLE)
      return false;
   
   // Bollinger Bands
   bbHandle = iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
   if(bbHandle == INVALID_HANDLE)
      return false;
   
   // EMA for trend filter
   if(TrendFilterEMA > 0)
   {
      emaHandle = iMA(_Symbol, PERIOD_H1, TrendFilterEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(emaHandle == INVALID_HANDLE)
         return false;
   }
   
   // ADX
   adxHandle = iADX(_Symbol, PERIOD_CURRENT, 14);
   if(adxHandle == INVALID_HANDLE)
      return false;
   
   // RSI
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
      return false;
   
   // Volume SMA
   volumeSMAHandle = iMA(_Symbol, PERIOD_CURRENT, VolumeSMAPeriod, 0, MODE_SMA, VOLUME_TICK);
   if(volumeSMAHandle == INVALID_HANDLE)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| ATR filter                                                       |
//+------------------------------------------------------------------+
bool CheckATRFilter()
{
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   
   // Check minimum/maximum volatility
   if(atrValue < MinATR || atrValue > MaxATR)
      return false;
   
   // Check breakout confirmation
   if(BreakoutType == 2) // ATR breakout
   {
      double rangeHigh = iHigh(_Symbol, RangeTF, 0);
      double rangeLow = iLow(_Symbol, RangeTF, 0);
      double atrThreshold = atrValue * ATRBreakoutMultiplier;
      
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // For long: price must be above range high + ATR threshold
      // For short: price must be below range low - ATR threshold
      if(AllowLong && ask < (rangeHigh + atrThreshold))
         return false;
      if(AllowShort && bid > (rangeLow - atrThreshold))
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Bollinger Bands filter                                           |
//+------------------------------------------------------------------+
bool CheckBBFilter()
{
   double upperBand = GetIndicatorValue(bbHandle, 1, 0);
   double lowerBand = GetIndicatorValue(bbHandle, 2, 0);
   double bbWidth = upperBand - lowerBand;
   
   // Check band width
   if(bbWidth < MinBBWidth || bbWidth > MaxBBWidth)
      return false;
   
   // Check breakout type
   if(BreakoutType == 1) // Bollinger Bands breakout
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // For long: price must be above upper band
      // For short: price must be below lower band
      if(AllowLong && ask <= upperBand)
         return false;
      if(AllowShort && bid >= lowerBand)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| EMA trend filter                                                 |
//+------------------------------------------------------------------+
bool CheckEMAFilter()
{
   if(TrendFilterEMA == 0)
      return true;
   
   double emaValue = GetIndicatorValue(emaHandle, 0, 0);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Strict trend filter: price > EMA200 for long, price < EMA200 for short
   if(AllowLong && ask <= emaValue)
      return false;
   if(AllowShort && bid >= emaValue)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| ADX trend strength filter                                        |
//+------------------------------------------------------------------+
bool CheckADXFilter()
{
   double adxValue = GetIndicatorValue(adxHandle, 0, 0);
   
   // Minimum trend strength
   if(adxValue < MinADX)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| RSI filter                                                       |
//+------------------------------------------------------------------+
bool CheckRSIFilter()
{
   double rsiValue = GetIndicatorValue(rsiHandle, 0, 0);
   
   // Exclude overbought/oversold zones
   if(AllowLong && rsiValue >= RSIOverbought)
      return false;
   if(AllowShort && rsiValue <= RSIOversold)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Volume filter                                                    |
//+------------------------------------------------------------------+
bool CheckVolumeFilter()
{
   if(!RequireVolumeConfirm)
      return true;
   
   double currentVolume = iVolume(_Symbol, PERIOD_CURRENT, 0);
   double volumeSMA = GetIndicatorValue(volumeSMAHandle, 0, 0);
   
   // Volume must be > 1.5x SMA
   if(currentVolume <= (volumeSMA * VolumeThreshold))
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Trading time filter                                              |
//+------------------------------------------------------------------+
bool CheckTradingTime()
{
   MqlDateTime timeStruct;
   TimeGMT(timeStruct);
   
   // Check day of week (all days allowed)
   // Check London session (after 8:00 GMT)
   if(timeStruct.hour < LondonOpenHour || 
      (timeStruct.hour == LondonOpenHour && timeStruct.min < LondonOpenMinute))
      return false;
   
   // Check Friday close (before 21:00 GMT)
   if(timeStruct.day_of_week == 5) // Friday
   {
      if(timeStruct.hour > FridayCloseHour || 
         (timeStruct.hour == FridayCloseHour && timeStruct.min >= FridayCloseMinute))
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| News filter (simplified implementation)                          |
//+------------------------------------------------------------------+
bool CheckNewsFilter()
{
   if(!UseNewsFilter)
      return true;
   
   // This is a simplified implementation
   // In real implementation, you would connect to economic calendar
   // and check for upcoming news events
   
   // Placeholder logic
   MqlDateTime timeStruct;
   TimeGMT(timeStruct);
   
   // Simulate news events (for demonstration only)
   // In practice, you would query an economic calendar
   bool hasHighImpactNews = false;
   
   if(hasHighImpactNews && CloseOnHighImpact)
   {
      // Close positions logic would go here
      return false;
   }
   
   // Check if we're within news suspension period
   // This would be based on actual news event times
   
   return true;
}

//+------------------------------------------------------------------+
//| Main filter validation function                                  |
//+------------------------------------------------------------------+
bool ValidateFilters()
{
   // Check if new bar on execution timeframe
   if(!IsNewBar(ExecTF))
      return false;
   
   // Initialize indicators if needed
   static bool indicatorsInitialized = false;
   if(!indicatorsInitialized)
   {
      indicatorsInitialized = InitIndicators();
      if(!indicatorsInitialized)
         return false;
   }
   
   // Apply all filters
   if(!CheckATRFilter())
      return false;
   
   if(!CheckBBFilter())
      return false;
   
   if(!CheckEMAFilter())
      return false;
   
   if(!CheckADXFilter())
      return false;
   
   if(!CheckRSIFilter())
      return false;
   
   if(!CheckVolumeFilter())
      return false;
   
   if(!CheckTradingTime())
      return false;
   
   if(!CheckNewsFilter())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for long entry signal                                      |
//+------------------------------------------------------------------+
bool CheckLongEntry()
{
   if(!AllowLong)
      return false;
   
   if(!ValidateFilters())
      return false;
   
   // Additional entry logic based on breakout type
   switch(BreakoutType)
   {
      case 0: // Range breakout
         double rangeHigh = iHigh(_Symbol, RangeTF, 0);
         if(RequireRetest)
            return IsRetestLong(rangeHigh);
         else
            return IsBreakoutLong(rangeHigh);
         
      case 1: // Bollinger Bands breakout
         double bbUpper = GetIndicatorValue(bbHandle, 1, 0);
         if(RequireRetest)
            return IsRetestLong(bbUpper);
         else
            return IsBreakoutLong(bbUpper);
         
      case 2: // ATR breakout
         double atrValue = GetIndicatorValue(atrHandle, 0, 0);
         double rangeHighATR = iHigh(_Symbol, RangeTF, 0);
         double breakoutLevel = rangeHighATR + (atrValue * ATRBreakoutMultiplier);
         if(RequireRetest)
            return IsRetestLong(breakoutLevel);
         else
            return IsBreakoutLong(breakoutLevel);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for short entry signal                                     |
//+------------------------------------------------------------------+
bool CheckShortEntry()
{
   if(!AllowShort)
      return false;
   
   if(!ValidateFilters())
      return false;
   
   // Additional entry logic based on breakout type
   switch(BreakoutType)
   {
      case 0: // Range breakout
         double rangeLow = iLow(_Symbol, RangeTF, 0);
         if(RequireRetest)
            return IsRetestShort(rangeLow);
         else
            return IsBreakoutShort(rangeLow);
         
      case 1: // Bollinger Bands breakout
         double bbLower = GetIndicatorValue(bbHandle, 2, 0);
         if(RequireRetest)
            return IsRetestShort(bbLower);
         else
            return IsBreakoutShort(bbLower);
         
      case 2: // ATR breakout
         double atrValue = GetIndicatorValue(atrHandle, 0, 0);
         double rangeLowATR = iLow(_Symbol, RangeTF, 0);
         double breakoutLevel = rangeLowATR - (atrValue * ATRBreakoutMultiplier);
         if(RequireRetest)
            return IsRetestShort(breakoutLevel);
         else
            return IsBreakoutShort(breakoutLevel);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Clean up indicator handles                                       |
//+------------------------------------------------------------------+
void CleanupIndicators()
{
   if(atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(atrHandle);
      atrHandle = INVALID_HANDLE;
   }
   
   if(bbHandle != INVALID_HANDLE)
   {
      IndicatorRelease(bbHandle);
      bbHandle = INVALID_HANDLE;
   }
   
   if(emaHandle != INVALID_HANDLE)
   {
      IndicatorRelease(emaHandle);
      emaHandle = INVALID_HANDLE;
   }
   
   if(adxHandle != INVALID_HANDLE)
   {
      IndicatorRelease(adxHandle);
      adxHandle = INVALID_HANDLE;
   }
   
   if(rsiHandle != INVALID_HANDLE)
   {
      IndicatorRelease(rsiHandle);
      rsiHandle = INVALID_HANDLE;
   }
   
   if(volumeSMAHandle != INVALID_HANDLE)
   {
      IndicatorRelease(volumeSMAHandle);
      volumeSMAHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
