#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| BreakoutLogic.mqh - Breakout detection logic                     |
//+------------------------------------------------------------------+

// Input parameters
input int      BreakoutType = 0;           // 0=Range, 1=BollingerBands, 2=ATR
input bool     AllowLong = true;           // Allow long positions
input bool     AllowShort = true;          // Allow short positions
input bool     RequireVolumeConfirm = true;// Require volume confirmation
input bool     RequireRetest = false;      // Wait for retest before entry
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1; // Timeframe for range calculation
input int      TrendFilterEMA = 200;       // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15; // Timeframe for trade execution
input bool     UseNewsFilter = true;       // Enable economic news filter
input int      NewsMinutesBefore = 60;     // Minutes before news to suspend trading
input int      NewsMinutesAfter = 30;      // Minutes after news to resume trading
input int      NewsImpactLevel = 3;        // Minimum impact level: 1=low, 2=medium, 3=high
input bool     CloseOnHighImpact = true;   // Close positions before high impact news
input bool     UseATRFilter = true;        // Enable ATR filter
input int      ATRPeriod = 14;             // ATR period
input double   MinATRPips = 20;            // Minimum ATR required (pips)
input double   MaxATRPips = 150;           // Maximum ATR allowed (pips)
input double   ATR_Mult_Min = 1.25;        // Minimum ATR multiplier for breakout validation
input double   ATR_Mult_Max = 3.0;         // Maximum ATR multiplier
input bool     UseBBFilter = true;         // Enable Bollinger Bands filter
input int      BBPeriod = 20;              // Bollinger Bands period
input double   BBDeviation = 2.0;          // Bollinger Bands standard deviation
input double   Min_Width_Pips = 30;        // Minimum BB width (pips)
input bool     UseADXFilter = true;        // Enable ADX filter
input int      ADXPeriod = 14;             // ADX period
input double   MinADX = 20;                // Minimum ADX value
input bool     UseRSIFilter = true;        // Enable RSI filter
input int      RSIPeriod = 14;             // RSI period
input double   RSI_Overbought = 70;        // Overbought level
input double   RSI_Oversold = 30;          // Oversold level
input int      VolumeMAPeriod = 20;        // Volume moving average period
input double   VolumeThreshold = 1.5;      // Volume threshold multiplier
input double   RetestTolerancePips = 5;    // Retest tolerance in pips
input int      SignalShift = 0;            // Signal shift for indicators

// Global variables
datetime lastBarTime = 0;
int ffcalHandle = INVALID_HANDLE;
int emaHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
int bbHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int volumeMAHandle = INVALID_HANDLE;

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
//| Breakout entry detection                                         |
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
bool IsRetestLong(double level)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = RetestTolerancePips * point * 10;
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level)
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
   if(CopyBuffer(handle, buffer, shift, 1, value) == 1)
      return value[0];
   return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Trend filter using EMA                                           |
//+------------------------------------------------------------------+
bool IsTrendLong()
{
   if(TrendFilterEMA <= 0) return true;
   
   if(emaHandle == INVALID_HANDLE)
      emaHandle = iMA(_Symbol, PERIOD_H1, TrendFilterEMA, 0, MODE_EMA, PRICE_CLOSE);
   
   double emaValue = GetIndicatorValue(emaHandle, 0, 0);
   double closePrice = iClose(_Symbol, PERIOD_H1, 0);
   
   return (closePrice > emaValue);
}

bool IsTrendShort()
{
   if(TrendFilterEMA <= 0) return true;
   
   if(emaHandle == INVALID_HANDLE)
      emaHandle = iMA(_Symbol, PERIOD_H1, TrendFilterEMA, 0, MODE_EMA, PRICE_CLOSE);
   
   double emaValue = GetIndicatorValue(emaHandle, 0, 0);
   double closePrice = iClose(_Symbol, PERIOD_H1, 0);
   
   return (closePrice < emaValue);
}

//+------------------------------------------------------------------+
//| ATR filter                                                       |
//+------------------------------------------------------------------+
bool CheckATRFilter()
{
   if(!UseATRFilter) return true;
   
   if(atrHandle == INVALID_HANDLE)
      atrHandle = iATR(_Symbol, ExecTF, ATRPeriod);
   
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atrPips = atrValue / point / 10;
   
   return (atrPips >= MinATRPips && atrPips <= MaxATRPips);
}

//+------------------------------------------------------------------+
//| Bollinger Bands filter                                           |
//+------------------------------------------------------------------+
bool CheckBBFilter()
{
   if(!UseBBFilter) return true;
   
   if(bbHandle == INVALID_HANDLE)
      bbHandle = iBands(_Symbol, ExecTF, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   
   double upperBand = GetIndicatorValue(bbHandle, 1, 0);
   double lowerBand = GetIndicatorValue(bbHandle, 2, 0);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double widthPips = (upperBand - lowerBand) / point / 10;
   
   return (widthPips >= Min_Width_Pips);
}

//+------------------------------------------------------------------+
//| ADX filter                                                       |
//+------------------------------------------------------------------+
bool CheckADXFilter()
{
   if(!UseADXFilter) return true;
   
   if(adxHandle == INVALID_HANDLE)
      adxHandle = iADX(_Symbol, ExecTF, ADXPeriod);
   
   double adxValue = GetIndicatorValue(adxHandle, 0, 0);
   
   return (adxValue >= MinADX);
}

//+------------------------------------------------------------------+
//| RSI filter                                                       |
//+------------------------------------------------------------------+
bool CheckRSIFilter(bool isLong)
{
   if(!UseRSIFilter) return true;
   
   if(rsiHandle == INVALID_HANDLE)
      rsiHandle = iRSI(_Symbol, ExecTF, RSIPeriod, PRICE_CLOSE);
   
   double rsiValue = GetIndicatorValue(rsiHandle, 0, 0);
   
   if(isLong)
      return (rsiValue < RSI_Overbought);
   else
      return (rsiValue > RSI_Oversold);
}

//+------------------------------------------------------------------+
//| Volume confirmation                                              |
//+------------------------------------------------------------------+
bool CheckVolumeConfirm()
{
   if(!RequireVolumeConfirm) return true;
   
   if(volumeMAHandle == INVALID_HANDLE)
      volumeMAHandle = iMA(_Symbol, ExecTF, VolumeMAPeriod, 0, MODE_SMA, VOLUME_TICK);
   
   double currentVolume = iVolume(_Symbol, ExecTF, 0);
   double maVolume = GetIndicatorValue(volumeMAHandle, 0, 0);
   
   return (currentVolume > maVolume * VolumeThreshold);
}

//+------------------------------------------------------------------+
//| News filter using FFCal                                          |
//+------------------------------------------------------------------+
bool IsNewsFilterActive()
{
   if(!UseNewsFilter) return false;
   
   if(ffcalHandle == INVALID_HANDLE)
      ffcalHandle = iCustom(_Symbol, PERIOD_CURRENT, "FFCal");
   
   if(ffcalHandle == INVALID_HANDLE) return false;
   
   datetime currentTime = TimeCurrent();
   
   // Check for upcoming high impact news
   for(int i = 0; i < 10; i++)
   {
      double impact = GetIndicatorValue(ffcalHandle, 0, i);
      datetime newsTime = (datetime)GetIndicatorValue(ffcalHandle, 1, i);
      
      if(impact >= NewsImpactLevel && newsTime > 0)
      {
         int minutesDiff = (int)((newsTime - currentTime) / 60);
         
         // Check if we're within the news window
         if(minutesDiff <= NewsMinutesBefore && minutesDiff >= -NewsMinutesAfter)
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Range breakout detection                                         |
//+------------------------------------------------------------------+
bool CheckRangeBreakout(bool &isLongSignal, double &entryLevel)
{
   if(BreakoutType != 0) return false;
   
   double rangeHigh = iHigh(_Symbol, RangeTF, 1);
   double rangeLow = iLow(_Symbol, RangeTF, 1);
   
   // Check ATR validation for breakout
   if(UseATRFilter)
   {
      if(atrHandle == INVALID_HANDLE)
         atrHandle = iATR(_Symbol, ExecTF, ATRPeriod);
      
      double atrValue = GetIndicatorValue(atrHandle, 0, 0);
      
      // Check long breakout
      if(AllowLong && IsBreakoutLong(rangeHigh, atrValue * ATR_Mult_Min))
      {
         if(IsBreakoutLong(rangeHigh, atrValue * ATR_Mult_Max))
            return false; // Too strong breakout
            
         isLongSignal = true;
         entryLevel = rangeHigh;
         return true;
      }
      
      // Check short breakout
      if(AllowShort && IsBreakoutShort(rangeLow, atrValue * ATR_Mult_Min))
      {
         if(IsBreakoutShort(rangeLow, atrValue * ATR_Mult_Max))
            return false; // Too strong breakout
            
         isLongSignal = false;
         entryLevel = rangeLow;
         return true;
      }
   }
   else
   {
      // Simple breakout without ATR validation
      if(AllowLong && IsBreakoutLong(rangeHigh))
      {
         isLongSignal = true;
         entryLevel = rangeHigh;
         return true;
      }
      
      if(AllowShort && IsBreakoutShort(rangeLow))
      {
         isLongSignal = false;
         entryLevel = rangeLow;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Bollinger Bands breakout detection                               |
//+------------------------------------------------------------------+
bool CheckBBBreakout(bool &isLongSignal, double &entryLevel)
{
   if(BreakoutType != 1) return false;
   
   if(bbHandle == INVALID_HANDLE)
      bbHandle = iBands(_Symbol, ExecTF, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   
   double upperBand = GetIndicatorValue(bbHandle, 1, 0);
   double lowerBand = GetIndicatorValue(bbHandle, 2, 0);
   
   if(AllowLong && IsBreakoutLong(upperBand))
   {
      isLongSignal = true;
      entryLevel = upperBand;
      return true;
   }
   
   if(AllowShort && IsBreakoutShort(lowerBand))
   {
      isLongSignal = false;
      entryLevel = lowerBand;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| ATR-based breakout detection                                     |
//+------------------------------------------------------------------+
bool CheckATRBreakout(bool &isLongSignal, double &entryLevel)
{
   if(BreakoutType != 2) return false;
   
   if(atrHandle == INVALID_HANDLE)
      atrHandle = iATR(_Symbol, ExecTF, ATRPeriod);
   
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   double closePrice = iClose(_Symbol, ExecTF, 1);
   
   double upperLevel = closePrice + atrValue * ATR_Mult_Min;
   double lowerLevel = closePrice - atrValue * ATR_Mult_Min;
   
   if(AllowLong && IsBreakoutLong(upperLevel))
   {
      if(IsBreakoutLong(upperLevel, atrValue * (ATR_Mult_Max - ATR_Mult_Min)))
         return false; // Too strong breakout
         
      isLongSignal = true;
      entryLevel = upperLevel;
      return true;
   }
   
   if(AllowShort && IsBreakoutShort(lowerLevel))
   {
      if(IsBreakoutShort(lowerLevel, atrValue * (ATR_Mult_Max - ATR_Mult_Min)))
         return false; // Too strong breakout
         
      isLongSignal = false;
      entryLevel = lowerLevel;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Main breakout detection function                                 |
//+------------------------------------------------------------------+
bool CheckBreakoutSignal(bool &isLongSignal, double &entryLevel)
{
   // Check for new bar on execution timeframe
   if(!IsNewBar(ExecTF))
      return false;
   
   // Check news filter
   if(IsNewsFilterActive())
      return false;
   
   // Check trend filter
   bool trendOK = false;
   if(isLongSignal)
      trendOK = IsTrendLong();
   else
      trendOK = IsTrendShort();
   
   if(!trendOK)
      return false;
   
   // Check ATR filter
   if(!CheckATRFilter())
      return false;
   
   // Check Bollinger Bands filter
   if(!CheckBBFilter())
      return false;
   
   // Check ADX filter
   if(!CheckADXFilter())
      return false;
   
   // Check volume confirmation
   if(!CheckVolumeConfirm())
      return false;
   
   // Detect breakout based on type
   bool breakoutDetected = false;
   
   switch(BreakoutType)
   {
      case 0: // Range breakout
         breakoutDetected = CheckRangeBreakout(isLongSignal, entryLevel);
         break;
      
      case 1: // Bollinger Bands breakout
         breakoutDetected = CheckBBBreakout(isLongSignal, entryLevel);
         break;
      
      case 2: // ATR breakout
         breakoutDetected = CheckATRBreakout(isLongSignal, entryLevel);
         break;
   }
   
   if(!breakoutDetected)
      return false;
   
   // Check RSI filter
   if(!CheckRSIFilter(isLongSignal))
      return false;
   
   // Check retest if required
   if(RequireRetest)
   {
      if(isLongSignal)
      {
         if(!IsRetestLong(entryLevel))
            return false;
      }
      else
      {
         if(!IsRetestShort(entryLevel))
            return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Cleanup function                                                 |
//+------------------------------------------------------------------+
void Cleanup()
{
   if(ffcalHandle != INVALID_HANDLE)
   {
      IndicatorRelease(ffcalHandle);
      ffcalHandle = INVALID_HANDLE;
   }
   
   if(emaHandle != INVALID_HANDLE)
   {
      IndicatorRelease(emaHandle);
      emaHandle = INVALID_HANDLE;
   }
   
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
   
   if(volumeMAHandle != INVALID_HANDLE)
   {
      IndicatorRelease(volumeMAHandle);
      volumeMAHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
