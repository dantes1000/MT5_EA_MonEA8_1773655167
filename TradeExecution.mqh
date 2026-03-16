#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| TradeExecution.mqh - Handles order placement with retries,       |
//| slippage, magic number, and comments                             |
//+------------------------------------------------------------------+

// Input parameters
input int      MagicNumber = 12345;          // Magic number for orders
input double   Slippage = 3;                 // Slippage in points
input int      MaxRetries = 3;               // Maximum order retries
input int      RetryDelay = 100;             // Delay between retries (ms)
input string   OrderComment = "Breakout";    // Order comment
input double   LotSize = 0.1;                // Fixed lot size (use 0 for auto)
input bool     UseMoneyManagement = false;   // Use money management
input double   RiskPercent = 2.0;            // Risk percentage per trade
input double   MinLot = 0.01;                // Minimum lot size
input double   MaxLot = 10.0;                // Maximum lot size
input int      StopLossPips = 50;            // Stop loss in pips
input int      TakeProfitPips = 100;         // Take profit in pips
input bool     UseTrailingStop = false;      // Use trailing stop
input int      TrailingStopPips = 30;        // Trailing stop distance
input int      TrailingStepPips = 10;        // Trailing step

// Breakout parameters
input int      BreakoutType = 0;             // 0=Range, 1=BollingerBands, 2=ATR
input bool     AllowLong = true;             // Allow long positions
input bool     AllowShort = true;            // Allow short positions
input bool     RequireVolumeConfirm = true;  // Require volume confirmation
input bool     RequireRetest = false;        // Wait for retest before entry
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1;   // Timeframe for range calculation
input int      TrendFilterEMA = 200;         // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15;   // Timeframe for trade execution

// News filter parameters
input bool     UseNewsFilter = true;         // Enable economic news filter
input int      NewsMinutesBefore = 60;       // Minutes before news to suspend trading
input int      NewsMinutesAfter = 30;        // Minutes after news to resume trading
input int      NewsImpactLevel = 3;          // Minimum impact level: 1=low, 2=medium, 3=high
input bool     CloseOnHighImpact = true;     // Close positions before high impact news

// Indicator filter parameters
input bool     UseATRFilter = true;          // Enable ATR filter
input int      ATRPeriod = 14;               // ATR period
input double   MinATRPips = 20;              // Minimum ATR required (pips)
input double   MaxATRPips = 150;             // Maximum ATR allowed (pips)
input double   ATR_Mult_Min = 1.25;          // Minimum ATR multiplier for breakout validation
input double   ATR_Mult_Max = 3.0;           // Maximum ATR multiplier
input bool     UseBBFilter = true;           // Enable Bollinger Bands filter
input int      BBPeriod = 20;                // Bollinger Bands period
input double   BBDeviation = 2.0;            // BB standard deviation
input double   Min_Width_Pips = 30;          // Minimum BB width (pips)

//+------------------------------------------------------------------+
//| Class CTradeExecution                                            |
//+------------------------------------------------------------------+
class CTradeExecution
{
private:
   int               m_magic;
   double            m_slippage;
   int               m_maxRetries;
   int               m_retryDelay;
   string            m_comment;
   double            m_lotSize;
   bool              m_useMoneyManagement;
   double            m_riskPercent;
   double            m_minLot;
   double            m_maxLot;
   int               m_stopLossPips;
   int               m_takeProfitPips;
   bool              m_useTrailingStop;
   int               m_trailingStopPips;
   int               m_trailingStepPips;
   
   // Breakout parameters
   int               m_breakoutType;
   bool              m_allowLong;
   bool              m_allowShort;
   bool              m_requireVolumeConfirm;
   bool              m_requireRetest;
   ENUM_TIMEFRAMES   m_rangeTF;
   int               m_trendFilterEMA;
   ENUM_TIMEFRAMES   m_execTF;
   
   // News filter parameters
   bool              m_useNewsFilter;
   int               m_newsMinutesBefore;
   int               m_newsMinutesAfter;
   int               m_newsImpactLevel;
   bool              m_closeOnHighImpact;
   
   // Indicator filter parameters
   bool              m_useATRFilter;
   int               m_atrPeriod;
   double            m_minATRPips;
   double            m_maxATRPips;
   double            m_atrMultMin;
   double            m_atrMultMax;
   bool              m_useBBFilter;
   int               m_bbPeriod;
   double            m_bbDeviation;
   double            m_minWidthPips;
   
   // Handles
   int               m_atrHandle;
   int               m_bbHandle;
   int               m_emaHandle;
   
   // State variables
   datetime          m_lastBarTime;
   
public:
   // Constructor
   CTradeExecution() :
      m_magic(MagicNumber),
      m_slippage(Slippage),
      m_maxRetries(MaxRetries),
      m_retryDelay(RetryDelay),
      m_comment(OrderComment),
      m_lotSize(LotSize),
      m_useMoneyManagement(UseMoneyManagement),
      m_riskPercent(RiskPercent),
      m_minLot(MinLot),
      m_maxLot(MaxLot),
      m_stopLossPips(StopLossPips),
      m_takeProfitPips(TakeProfitPips),
      m_useTrailingStop(UseTrailingStop),
      m_trailingStopPips(TrailingStopPips),
      m_trailingStepPips(TrailingStepPips),
      m_breakoutType(BreakoutType),
      m_allowLong(AllowLong),
      m_allowShort(AllowShort),
      m_requireVolumeConfirm(RequireVolumeConfirm),
      m_requireRetest(RequireRetest),
      m_rangeTF(RangeTF),
      m_trendFilterEMA(TrendFilterEMA),
      m_execTF(ExecTF),
      m_useNewsFilter(UseNewsFilter),
      m_newsMinutesBefore(NewsMinutesBefore),
      m_newsMinutesAfter(NewsMinutesAfter),
      m_newsImpactLevel(NewsImpactLevel),
      m_closeOnHighImpact(CloseOnHighImpact),
      m_useATRFilter(UseATRFilter),
      m_atrPeriod(ATRPeriod),
      m_minATRPips(MinATRPips),
      m_maxATRPips(MaxATRPips),
      m_atrMultMin(ATR_Mult_Min),
      m_atrMultMax(ATR_Mult_Max),
      m_useBBFilter(UseBBFilter),
      m_bbPeriod(BBPeriod),
      m_bbDeviation(BBDeviation),
      m_minWidthPips(Min_Width_Pips),
      m_atrHandle(INVALID_HANDLE),
      m_bbHandle(INVALID_HANDLE),
      m_emaHandle(INVALID_HANDLE),
      m_lastBarTime(0)
   {
   }
   
   // Destructor
   ~CTradeExecution()
   {
      if(m_atrHandle != INVALID_HANDLE)
         IndicatorRelease(m_atrHandle);
      if(m_bbHandle != INVALID_HANDLE)
         IndicatorRelease(m_bbHandle);
      if(m_emaHandle != INVALID_HANDLE)
         IndicatorRelease(m_emaHandle);
   }
   
   // Initialization
   bool Init()
   {
      // Initialize indicator handles
      if(m_useATRFilter)
      {
         m_atrHandle = iATR(_Symbol, m_execTF, m_atrPeriod);
         if(m_atrHandle == INVALID_HANDLE)
         {
            Print("Failed to create ATR indicator");
            return false;
         }
      }
      
      if(m_useBBFilter)
      {
         m_bbHandle = iBands(_Symbol, m_execTF, m_bbPeriod, 0, m_bbDeviation, PRICE_CLOSE);
         if(m_bbHandle == INVALID_HANDLE)
         {
            Print("Failed to create Bollinger Bands indicator");
            return false;
         }
      }
      
      if(m_trendFilterEMA > 0)
      {
         m_emaHandle = iMA(_Symbol, PERIOD_H1, m_trendFilterEMA, 0, MODE_EMA, PRICE_CLOSE);
         if(m_emaHandle == INVALID_HANDLE)
         {
            Print("Failed to create EMA indicator");
            return false;
         }
      }
      
      return true;
   }
   
   // Check if new bar
   bool IsNewBar(ENUM_TIMEFRAMES tf)
   {
      datetime currentBar = iTime(_Symbol, tf, 0);
      if(m_lastBarTime != currentBar)
      {
         m_lastBarTime = currentBar;
         return true;
      }
      return false;
   }
   
   // Calculate lot size
   double CalcLotSize()
   {
      if(!m_useMoneyManagement)
         return NormalizeDouble(m_lotSize, 2);
      
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * m_riskPercent / 100.0;
      
      // For simplicity, using fixed stop loss distance
      double stopLossPoints = m_stopLossPips * 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      if(stopLossPoints == 0 || tickValue == 0)
         return NormalizeDouble(m_lotSize, 2);
      
      double lotSize = riskAmount / (stopLossPoints / SymbolInfoDouble(_Symbol, SYMBOL_POINT) * tickValue);
      
      // Apply min/max limits
      lotSize = MathMax(lotSize, m_minLot);
      lotSize = MathMin(lotSize, m_maxLot);
      
      return NormalizeDouble(lotSize, 2);
   }
   
   // Check breakout long
   bool IsBreakoutLong(double level, double tolerancePips = 0)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      return ask > level + tolerancePips * point * 10;
   }
   
   // Check breakout short
   bool IsBreakoutShort(double level, double tolerancePips = 0)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return bid < level - tolerancePips * point * 10;
   }
   
   // Check retest long
   bool IsRetestLong(double level)
   {
      double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tol     = 10 * point * 10; // 10 pips tolerance
      double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
      double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
      return (lowBar <= level + tol && closeBar > level);
   }
   
   // Check retest short
   bool IsRetestShort(double level)
   {
      double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tol      = 10 * point * 10; // 10 pips tolerance
      double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
      double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
      return (highBar >= level - tol && closeBar < level);
   }
   
   // Check volume confirmation
   bool CheckVolumeConfirm()
   {
      if(!m_requireVolumeConfirm)
         return true;
      
      // Get current volume
      long volume = iVolume(_Symbol, m_execTF, 0);
      
      // Calculate SMA of volume (20 periods)
      double sumVolume = 0;
      for(int i = 0; i < 20; i++)
         sumVolume += iVolume(_Symbol, m_execTF, i);
      
      double avgVolume = sumVolume / 20.0;
      
      // Check if current volume > 1.5x average
      return volume > avgVolume * 1.5;
   }
   
   // Check ATR filter
   bool CheckATRFilter()
   {
      if(!m_useATRFilter || m_atrHandle == INVALID_HANDLE)
         return true;
      
      double atrValue[1];
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atrValue) <= 0)
         return false;
      
      double atrPips = atrValue[0] / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 10;
      
      // Check ATR range
      if(atrPips < m_minATRPips || atrPips > m_maxATRPips)
         return false;
      
      return true;
   }
   
   // Check Bollinger Bands filter
   bool CheckBBFilter()
   {
      if(!m_useBBFilter || m_bbHandle == INVALID_HANDLE)
         return true;
      
      double upperBand[1], lowerBand[1];
      if(CopyBuffer(m_bbHandle, 1, 0, 1, upperBand) <= 0 ||
         CopyBuffer(m_bbHandle, 2, 0, 1, lowerBand) <= 0)
         return false;
      
      double bbWidth = upperBand[0] - lowerBand[0];
      double bbWidthPips = bbWidth / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 10;
      
      // Check minimum width
      return bbWidthPips >= m_minWidthPips;
   }
   
   // Check trend filter
   bool CheckTrendFilter(bool isLong)
   {
      if(m_trendFilterEMA <= 0 || m_emaHandle == INVALID_HANDLE)
         return true;
      
      double emaValue[1];
      if(CopyBuffer(m_emaHandle, 0, 0, 1, emaValue) <= 0)
         return false;
      
      double currentPrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(isLong)
         return currentPrice > emaValue[0];
      else
         return currentPrice < emaValue[0];
   }
   
   // Check news filter
   bool CheckNewsFilter()
   {
      if(!m_useNewsFilter)
         return true;
      
      // This is a simplified implementation
      // In real implementation, you would integrate with FFCal or other news API
      
      // For now, always return true (no news blocking)
      // You would need to implement actual news checking logic here
      return true;
   }
   
   // Close positions before high impact news
   void ClosePositionsBeforeNews()
   {
      if(!m_closeOnHighImpact)
         return;
      
      // Check if high impact news is coming
      bool highImpactNewsComing = false; // Implement actual news checking
      
      if(highImpactNewsComing)
      {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
               if(PositionGetInteger(POSITION_MAGIC) == m_magic)
               {
                  // Close position
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  
                  request.action = TRADE_ACTION_DEAL;
                  request.position = ticket;
                  request.symbol = _Symbol;
                  request.volume = PositionGetDouble(POSITION_VOLUME);
                  request.deviation = (uint)m_slippage;
                  request.magic = m_magic;
                  request.comment = m_comment + " News Close";
                  
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                  {
                     request.type = ORDER_TYPE_SELL;
                     request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  }
                  else
                  {
                     request.type = ORDER_TYPE_BUY;
                     request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  }
                  
                  OrderSend(request, result);
               }
            }
         }
      }
   }
   
   // Execute buy order
   bool ExecuteBuy(double level = 0)
   {
      if(!m_allowLong)
         return false;
      
      // Check all filters
      if(!CheckVolumeConfirm() || !CheckATRFilter() || !CheckBBFilter() || 
         !CheckTrendFilter(true) || !CheckNewsFilter())
         return false;
      
      // Check breakout if level provided
      if(level > 0)
      {
         if(!IsBreakoutLong(level))
            return false;
            
         if(m_requireRetest && !IsRetestLong(level))
            return false;
      }
      
      double lotSize = CalcLotSize();
      if(lotSize <= 0)
         return false;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = lotSize;
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      request.deviation = (uint)m_slippage;
      request.magic = m_magic;
      request.comment = m_comment;
      
      // Calculate stop loss and take profit
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(m_stopLossPips > 0)
         request.sl = request.price - m_stopLossPips * point * 10;
      if(m_takeProfitPips > 0)
         request.tp = request.price + m_takeProfitPips * point * 10;
      
      // Try multiple times
      for(int i = 0; i < m_maxRetries; i++)
      {
         if(OrderSend(request, result))
         {
            if(result.retcode == TRADE_RETCODE_DONE)
               return true;
         }
         
         Sleep(m_retryDelay);
      }
      
      Print("Failed to execute buy order. Error: ", GetLastError());
      return false;
   }
   
   // Execute sell order
   bool ExecuteSell(double level = 0)
   {
      if(!m_allowShort)
         return false;
      
      // Check all filters
      if(!CheckVolumeConfirm() || !CheckATRFilter() || !CheckBBFilter() || 
         !CheckTrendFilter(false) || !CheckNewsFilter())
         return false;
      
      // Check breakout if level provided
      if(level > 0)
      {
         if(!IsBreakoutShort(level))
            return false;
            
         if(m_requireRetest && !IsRetestShort(level))
            return false;
      }
      
      double lotSize = CalcLotSize();
      if(lotSize <= 0)
         return false;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = lotSize;
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      request.deviation = (uint)m_slippage;
      request.magic = m_magic;
      request.comment = m_comment;
      
      // Calculate stop loss and take profit
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(m_stopLossPips > 0)
         request.sl = request.price + m_stopLossPips * point * 10;
      if(m_takeProfitPips > 0)
         request.tp = request.price - m_takeProfitPips * point * 10;
      
      // Try multiple times
      for(int i = 0; i < m_maxRetries; i++)
      {
         if(OrderSend(request, result))
         {
            if(result.retcode == TRADE_RETCODE_DONE)
               return true;
         }
         
         Sleep(m_retryDelay);
      }
      
      Print("Failed to execute sell order. Error: ", GetLastError());
      return false;
   }
   
   // Execute pending buy stop order
   bool ExecuteBuyStop(double price, double level = 0)
   {
      if(!m_allowLong)
         return false;
      
      // Check all filters
      if(!CheckVolumeConfirm() || !CheckATRFilter() || !CheckBBFilter() || 
         !CheckTrendFilter(true) || !CheckNewsFilter())
         return false;
      
      double lotSize = CalcLotSize();
      if(lotSize <= 0)
         return false;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = lotSize;
      request.type = ORDER_TYPE_BUY_STOP;
      request.price = NormalizeDouble(price, _Digits);
      request.deviation = (uint)m_slippage;
      request.magic = m_magic;
      request.comment = m_comment;
      
      // Calculate stop loss and take profit
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(m_stopLossPips > 0)
         request.sl = request.price - m_stopLossPips * point * 10;
      if(m_takeProfitPips > 0)
         request.tp = request.price + m_takeProfitPips * point * 10;
      
      // Try multiple times
      for(int i = 0; i < m_maxRetries; i++)
      {
         if(OrderSend(request, result))
         {
            if(result.retcode == TRADE_RETCODE_DONE)
               return true;
         }
         
         Sleep(m_retryDelay);
      }
      
      Print("Failed to execute buy stop order. Error: ", GetLastError());
      return false;
   }
   
   // Execute pending sell stop order
   bool ExecuteSellStop(double price, double level = 0)
   {
      if(!m_allowShort)
         return false;
      
      // Check all filters
      if(!CheckVolumeConfirm() || !CheckATRFilter() || !CheckBBFilter() || 
         !CheckTrendFilter(false) || !CheckNewsFilter())
         return false;
      
      double lotSize = CalcLotSize();
      if(lotSize <= 0)
         return false;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = lotSize;
      request.type = ORDER_TYPE_SELL_STOP;
      request.price = NormalizeDouble(price, _Digits);
      request.deviation = (uint)m_slippage;
      request.magic = m_magic;
      request.comment = m_comment;
      
      // Calculate stop loss and take profit
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(m_stopLossPips > 0)
         request.sl = request.price + m_stopLossPips * point * 10;
      if(m_takeProfitPips > 0)
         request.tp = request.price - m_takeProfitPips * point * 10;
      
      // Try multiple times
      for(int i = 0; i < m_maxRetries; i++)
      {
         if(OrderSend(request, result))
         {
            if(result.retcode == TRADE_RETCODE_DONE)
               return true;
         }
         
         Sleep(m_retryDelay);
      }
      
      Print("Failed to execute sell stop order. Error: ", GetLastError());
      return false;
   }
   
   // Update trailing stops
   void UpdateTrailingStops()
   {
      if(!m_useTrailingStop)
         return;
      
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double trailingDistance = m_trailingStopPips * point * 10;
      double trailingStep = m_trailingStepPips * point * 10;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magic)
            {
               double currentSL = PositionGetDouble(POSITION_SL);
               double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
               double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               {
                  double newSL = currentPrice - trailingDistance;
                  if(newSL > currentSL && (newSL - currentSL) >= trailingStep)
                  {
                     MqlTradeRequest request = {};
                     MqlTradeResult result = {};
                     
                     request.action = TRADE_ACTION_SLTP;
                     request.position = ticket;
                     request.symbol = _Symbol;
                     request.sl = newSL;
                     request.magic = m_magic;
                     
                     OrderSend(request, result);
                  }
               }
               else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               {
                  double newSL = currentPrice + trailingDistance;
                  if(newSL < currentSL && (currentSL - newSL) >= trailingStep)
                  {
                     MqlTradeRequest request = {};
                     MqlTradeResult result = {};
                     
                     request.action = TRADE_ACTION_SLTP;
                     request.position = ticket;
                     request.symbol = _Symbol;
                     request.sl = newSL;
                     request.magic = m_magic;
                     
                     OrderSend(request, result);
                  }
               }
            }
         }
      }
   }
   
   // Close all positions
   void CloseAllPositions()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magic)
            {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_DEAL;
               request.position = ticket;
               request.symbol = _Symbol;
               request.volume = PositionGetDouble(POSITION_VOLUME);
               request.deviation = (uint)m_slippage;
               request.magic = m_magic;
               request.comment = m_comment + " Close All";
               
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               {
                  request.type = ORDER_TYPE_SELL;
                  request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               }
               else
               {
                  request.type = ORDER_TYPE_BUY;
                  request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               }
               
               OrderSend(request, result);
            }
         }
      }
   }
   
   // Delete all pending orders
   void DeleteAllPendingOrders()
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket))
         {
            if(OrderGetInteger(ORDER_MAGIC) == m_magic)
            {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_REMOVE;
               request.order = ticket;
               request.symbol = _Symbol;
               request.magic = m_magic;
               
               OrderSend(request, result);
            }
         }
      }
   }
};

//+------------------------------------------------------------------+
