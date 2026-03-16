#property strict

//+------------------------------------------------------------------+
//| Utilities.mqh - Helper functions for trading systems            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Pip calculation functions                                        |
//+------------------------------------------------------------------+

/**
 * Get point value for current symbol
 */
double GetPointValue()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

/**
 * Convert pips to points
 */
double PipsToPoints(double pips)
{
   double point = GetPointValue();
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // For 5-digit brokers (most common)
   if(digits == 5 || digits == 3)
      return pips * 10;
   // For 4-digit brokers
   else if(digits == 4 || digits == 2)
      return pips;
   
   return pips;
}

/**
 * Convert points to pips
 */
double PointsToPips(double points)
{
   double point = GetPointValue();
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // For 5-digit brokers (most common)
   if(digits == 5 || digits == 3)
      return points / 10;
   // For 4-digit brokers
   else if(digits == 4 || digits == 2)
      return points;
   
   return points;
}

/**
 * Calculate price difference in pips
 */
double PriceDiffInPips(double price1, double price2)
{
   double point = GetPointValue();
   double diff = MathAbs(price1 - price2);
   return PointsToPips(diff / point);
}

//+------------------------------------------------------------------+
//| Timeframe conversion functions                                   |
//+------------------------------------------------------------------+

/**
 * Convert timeframe enum to string
 */
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
      default: return "Current";
   }
}

/**
 * Convert string to timeframe enum
 */
ENUM_TIMEFRAMES StringToTimeframe(string tfStr)
{
   if(tfStr == "M1") return PERIOD_M1;
   if(tfStr == "M5") return PERIOD_M5;
   if(tfStr == "M15") return PERIOD_M15;
   if(tfStr == "M30") return PERIOD_M30;
   if(tfStr == "H1") return PERIOD_H1;
   if(tfStr == "H4") return PERIOD_H4;
   if(tfStr == "D1") return PERIOD_D1;
   if(tfStr == "W1") return PERIOD_W1;
   if(tfStr == "MN1") return PERIOD_MN1;
   return PERIOD_CURRENT;
}

/**
 * Get timeframe multiplier (how many base periods in target timeframe)
 */
int GetTimeframeMultiplier(ENUM_TIMEFRAMES baseTF, ENUM_TIMEFRAMES targetTF)
{
   int baseMinutes = PeriodSeconds(baseTF) / 60;
   int targetMinutes = PeriodSeconds(targetTF) / 60;
   
   if(baseMinutes == 0 || targetMinutes == 0) return 1;
   return targetMinutes / baseMinutes;
}

/**
 * Check if it's a new bar on specified timeframe
 */
bool IsNewBar(ENUM_TIMEFRAMES tf)
{
   static datetime lastBarTime = 0;
   datetime currentBar = iTime(_Symbol, tf, 0);
   if(lastBarTime != currentBar)
   {
      lastBarTime = currentBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Logging functions                                                |
//+------------------------------------------------------------------+

/**
 * Log message with timestamp
 */
void LogMessage(string message, bool printToJournal = true)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string logMsg = StringFormat("[%s] %s", timestamp, message);
   
   if(printToJournal)
      Print(logMsg);
}

/**
 * Log error message
 */
void LogError(string functionName, string errorMsg, int errorCode = 0)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string logMsg;
   
   if(errorCode != 0)
      logMsg = StringFormat("[%s] ERROR in %s: %s (Code: %d)", timestamp, functionName, errorMsg, errorCode);
   else
      logMsg = StringFormat("[%s] ERROR in %s: %s", timestamp, functionName, errorMsg);
   
   Print(logMsg);
}

/**
 * Log trade information
 */
void LogTrade(string action, double price, double volume, string comment = "")
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string symbol = _Symbol;
   
   string logMsg;
   if(comment != "")
      logMsg = StringFormat("[%s] TRADE %s %s @ %.5f (%.2f lots) - %s", 
                           timestamp, action, symbol, price, volume, comment);
   else
      logMsg = StringFormat("[%s] TRADE %s %s @ %.5f (%.2f lots)", 
                           timestamp, action, symbol, price, volume);
   
   Print(logMsg);
}

/**
 * Log indicator values for debugging
 */
void LogIndicator(string indicatorName, double value, int bar = 0)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string logMsg = StringFormat("[%s] INDICATOR %s[%d] = %.5f", 
                               timestamp, indicatorName, bar, value);
   Print(logMsg);
}

//+------------------------------------------------------------------+
//| Price level functions                                            |
//+------------------------------------------------------------------+

/**
 * Check for breakout long
 */
bool IsBreakoutLong(double level, double tolerancePips = 0)
{
   double point = GetPointValue();
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ask > level + tolerancePips * point * 10;
}

/**
 * Check for breakout short
 */
bool IsBreakoutShort(double level, double tolerancePips = 0)
{
   double point = GetPointValue();
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return bid < level - tolerancePips * point * 10;
}

/**
 * Check for retest after breakout (long)
 */
bool IsRetestLong(double level, double tolerancePips = 0, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double point   = GetPointValue();
   double tol     = tolerancePips * point * 10;
   double lowBar  = iLow(_Symbol, tf, 1);
   double closeBar = iClose(_Symbol, tf, 1);
   return (lowBar <= level + tol && closeBar > level);
}

/**
 * Check for retest after breakout (short)
 */
bool IsRetestShort(double level, double tolerancePips = 0, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double point    = GetPointValue();
   double tol      = tolerancePips * point * 10;
   double highBar  = iHigh(_Symbol, tf, 1);
   double closeBar = iClose(_Symbol, tf, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Indicator helper functions                                       |
//+------------------------------------------------------------------+

/**
 * Get indicator value from handle
 */
double GetIndicatorValue(int handle, int buffer = 0, int shift = 0)
{
   double value[1];
   if(CopyBuffer(handle, buffer, shift, 1, value) > 0)
      return value[0];
   return EMPTY_VALUE;
}

/**
 * Check for MA crossover (long)
 */
bool IsTrendLong(int fastHandle, int slowHandle, int signalShift = 0)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
   
   if(fast0 == EMPTY_VALUE || slow0 == EMPTY_VALUE || 
      fast1 == EMPTY_VALUE || slow1 == EMPTY_VALUE)
      return false;
      
   return (fast1 <= slow1 && fast0 > slow0);
}

/**
 * Check for MA crossover (short)
 */
bool IsTrendShort(int fastHandle, int slowHandle, int signalShift = 0)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
   
   if(fast0 == EMPTY_VALUE || slow0 == EMPTY_VALUE || 
      fast1 == EMPTY_VALUE || slow1 == EMPTY_VALUE)
      return false;
      
   return (fast1 >= slow1 && fast0 < slow0);
}

//+------------------------------------------------------------------+
//| Volume functions                                                 |
//+------------------------------------------------------------------+

/**
 * Check volume confirmation
 */
bool IsVolumeConfirmed(ENUM_TIMEFRAMES tf = PERIOD_CURRENT, double multiplier = 1.5, int maPeriod = 20)
{
   // Get current volume
   long currentVolume = iVolume(_Symbol, tf, 0);
   
   // Calculate MA of volume
   double volumeMA = 0;
   for(int i = 0; i < maPeriod; i++)
   {
      volumeMA += iVolume(_Symbol, tf, i);
   }
   volumeMA /= maPeriod;
   
   // Check if current volume is above threshold
   return (currentVolume > volumeMA * multiplier);
}

//+------------------------------------------------------------------+
//| Position and order helper functions                              |
//+------------------------------------------------------------------+

/**
 * Calculate lot size based on risk percentage
 */
double CalcLotSize(double riskPercent, double stopLossPips, double accountBalance = 0)
{
   if(accountBalance <= 0)
      accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   double riskAmount = accountBalance * riskPercent / 100;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = GetPointValue();
   
   if(stopLossPips <= 0 || tickValue <= 0 || point <= 0)
      return 0.01; // Default minimum lot
   
   double lotSize = riskAmount / (stopLossPips * point * 10 * tickValue);
   
   // Normalize lot size to broker requirements
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   
   return lotSize;
}

/**
 * Count open positions
 */
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
         count++;
   }
   return count;
}

/**
 * Check if position is profitable
 */
bool IsPositionProfitable(ulong ticket)
{
   if(PositionSelectByTicket(ticket))
      return PositionGetDouble(POSITION_PROFIT) > 0;
   return false;
}

//+------------------------------------------------------------------+
//| Math and utility functions                                       |
//+------------------------------------------------------------------+

/**
 * Normalize price to broker digits
 */
double NormalizePrice(double price)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   return NormalizeDouble(price / tickSize, 0) * tickSize;
}

/**
 * Calculate stop loss price for long position
 */
double CalculateStopLossLong(double entryPrice, double stopLossPips)
{
   double point = GetPointValue();
   return entryPrice - stopLossPips * point * 10;
}

/**
 * Calculate stop loss price for short position
 */
double CalculateStopLossShort(double entryPrice, double stopLossPips)
{
   double point = GetPointValue();
   return entryPrice + stopLossPips * point * 10;
}

/**
 * Calculate take profit price for long position
 */
double CalculateTakeProfitLong(double entryPrice, double takeProfitPips)
{
   double point = GetPointValue();
   return entryPrice + takeProfitPips * point * 10;
}

/**
 * Calculate take profit price for short position
 */
double CalculateTakeProfitShort(double entryPrice, double takeProfitPips)
{
   double point = GetPointValue();
   return entryPrice - takeProfitPips * point * 10;
}

//+------------------------------------------------------------------+
//| Array helper functions                                           |
//+------------------------------------------------------------------+

/**
 * Find highest value in array
 */
double ArrayHighest(const double &array[], int start = 0, int count = WHOLE_ARRAY)
{
   if(count == WHOLE_ARRAY) count = ArraySize(array);
   
   double highest = -DBL_MAX;
   for(int i = start; i < start + count && i < ArraySize(array); i++)
   {
      if(array[i] > highest)
         highest = array[i];
   }
   return highest;
}

/**
 * Find lowest value in array
 */
double ArrayLowest(const double &array[], int start = 0, int count = WHOLE_ARRAY)
{
   if(count == WHOLE_ARRAY) count = ArraySize(array);
   
   double lowest = DBL_MAX;
   for(int i = start; i < start + count && i < ArraySize(array); i++)
   {
      if(array[i] < lowest)
         lowest = array[i];
   }
   return lowest;
}

//+------------------------------------------------------------------+
//| Date and time functions                                          |
//+------------------------------------------------------------------+

/**
 * Check if current time is within trading hours
 */
bool IsTradingHours(int startHour, int startMinute, int endHour, int endMinute)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes = startHour * 60 + startMinute;
   int endMinutes = endHour * 60 + endMinute;
   
   return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
}

/**
 * Get time until next bar
 */
int SecondsUntilNextBar(ENUM_TIMEFRAMES tf)
{
   datetime currentTime = TimeCurrent();
   datetime nextBarTime = iTime(_Symbol, tf, 0) + PeriodSeconds(tf);
   return (int)(nextBarTime - currentTime);
}

//+------------------------------------------------------------------+
