//+------------------------------------------------------------------+
//| RiskManagement.mqh                                              |
//| Handles position sizing, stop loss, take profit, and partial close |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property strict

//+------------------------------------------------------------------+
//| Input parameters                                                |
//+------------------------------------------------------------------+
input int      MagicNumber = 123456;           // Magic number
input string   OrderComment = "RangeBreakEA";  // Order comment
input int      MaxSlippage = 3;                // Max slippage (points)
input int      MaxOrderRetries = 3;            // Max order retries
input bool     UsePartialClose = false;        // Enable partial close
input double   PartialCloseRR = 1.0;           // R:R for partial close
input double   PartialClosePct = 50;           // Percentage to close (%)
input bool     AllowAddPosition = false;       // Allow adding to position
input double   AddPositionRR = 1.0;            // Min R:R to add position
input double   RiskPercent = 2.0;              // Risk per trade (%)
input double   FixedLotSize = 0.0;             // Fixed lot size (0=auto)
input double   MaxLotSize = 100.0;             // Maximum lot size
input double   MinLotSize = 0.01;              // Minimum lot size
input int      StopLossPips = 50;              // Stop loss in pips
input int      TakeProfitPips = 100;           // Take profit in pips
input bool     UseATRStop = false;             // Use ATR for stop loss
input int      ATRPeriod = 14;                 // ATR period
input double   ATRMultiplier = 2.0;            // ATR multiplier
input bool     UseTrailingStop = false;        // Enable trailing stop
input int      TrailingStopPips = 30;          // Trailing stop distance
input int      TrailingStepPips = 5;           // Trailing step

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
int atrHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
void RiskManagementInit()
{
   if(UseATRStop)
   {
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
      if(atrHandle == INVALID_HANDLE)
         Print("Failed to create ATR handle");
   }
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void RiskManagementDeinit()
{
   if(atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(atrHandle);
      atrHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPips, double riskPercent = 0.0)
{
   if(riskPercent <= 0) riskPercent = RiskPercent;
   
   if(FixedLotSize > 0)
      return MathMin(MathMax(FixedLotSize, MinLotSize), MaxLotSize);
   
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(tickSize <= 0 || tickValue <= 0 || lotStep <= 0)
      return MinLotSize;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * riskPercent / 100.0;
   
   double stopLossPoints = stopLossPips * 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double lossPerLot = stopLossPoints / tickSize * tickValue;
   
   if(lossPerLot <= 0)
      return MinLotSize;
   
   double lots = riskAmount / lossPerLot;
   lots = MathFloor(lots / lotStep) * lotStep;
   
   return MathMin(MathMax(lots, MinLotSize), MaxLotSize);
}

//+------------------------------------------------------------------+
//| Calculate stop loss price                                        |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice, double stopLossPips = 0.0)
{
   if(stopLossPips <= 0) stopLossPips = StopLossPips;
   
   if(UseATRStop && atrHandle != INVALID_HANDLE)
   {
      double atrValue[1];
      if(CopyBuffer(atrHandle, 0, 0, 1, atrValue) == 1)
      {
         stopLossPips = atrValue[0] * ATRMultiplier / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 10;
      }
   }
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopDistance = stopLossPips * point * 10;
   
   switch(orderType)
   {
      case ORDER_TYPE_BUY:
         return entryPrice - stopDistance;
      case ORDER_TYPE_SELL:
         return entryPrice + stopDistance;
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate take profit price                                      |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice, double takeProfitPips = 0.0)
{
   if(takeProfitPips <= 0) takeProfitPips = TakeProfitPips;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tpDistance = takeProfitPips * point * 10;
   
   switch(orderType)
   {
      case ORDER_TYPE_BUY:
         return entryPrice + tpDistance;
      case ORDER_TYPE_SELL:
         return entryPrice - tpDistance;
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Check if partial close should be executed                        |
//+------------------------------------------------------------------+
bool ShouldPartialClose(ulong ticket, double currentRR)
{
   if(!UsePartialClose) return false;
   
   if(OrderSelect(ticket))
   {
      if(currentRR >= PartialCloseRR)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Execute partial close                                            |
//+------------------------------------------------------------------+
bool ExecutePartialClose(ulong ticket)
{
   if(!OrderSelect(ticket))
      return false;
   
   double volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
   double closeVolume = volume * PartialClosePct / 100.0;
   
   // Adjust to lot step size
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
   
   if(closeVolume < MinLotSize)
      return false;
   
   if(closeVolume >= volume)
      return false;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = closeVolume;
   request.deviation = MaxSlippage;
   request.magic = MagicNumber;
   request.comment = OrderComment + " Partial Close";
   
   if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY)
   {
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   else
   {
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }
   
   for(int i = 0; i < MaxOrderRetries; i++)
   {
      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE)
            return true;
      }
      Sleep(100);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if position should be added                                |
//+------------------------------------------------------------------+
bool ShouldAddPosition(ulong ticket, double currentRR)
{
   if(!AllowAddPosition) return false;
   
   if(OrderSelect(ticket))
   {
      if(currentRR >= AddPositionRR)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update trailing stop                                             |
//+------------------------------------------------------------------+
void UpdateTrailingStop(ulong ticket)
{
   if(!UseTrailingStop || !OrderSelect(ticket))
      return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double trailingDistance = TrailingStopPips * point * 10;
   double stepDistance = TrailingStepPips * point * 10;
   
   double currentStop = OrderGetDouble(ORDER_SL);
   double currentPrice = 0;
   double newStop = 0;
   
   if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      newStop = currentPrice - trailingDistance;
      
      if(newStop > currentStop + stepDistance)
      {
         ModifyStopLoss(ticket, newStop);
      }
   }
   else
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      newStop = currentPrice + trailingDistance;
      
      if(newStop < currentStop - stepDistance)
      {
         ModifyStopLoss(ticket, newStop);
      }
   }
}

//+------------------------------------------------------------------+
//| Modify stop loss                                                 |
//+------------------------------------------------------------------+
bool ModifyStopLoss(ulong ticket, double newStopLoss)
{
   if(!OrderSelect(ticket))
      return false;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = _Symbol;
   request.sl = newStopLoss;
   request.deviation = MaxSlippage;
   request.magic = MagicNumber;
   
   for(int i = 0; i < MaxOrderRetries; i++)
   {
      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE)
            return true;
      }
      Sleep(100);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate current risk:reward ratio                              |
//+------------------------------------------------------------------+
double CalculateCurrentRR(ulong ticket)
{
   if(!OrderSelect(ticket))
      return 0.0;
   
   double entryPrice = OrderGetDouble(ORDER_PRICE_OPEN);
   double stopLoss = OrderGetDouble(ORDER_SL);
   double takeProfit = OrderGetDouble(ORDER_TP);
   double currentPrice = 0;
   
   if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(takeProfit > 0 && stopLoss > 0)
         return (currentPrice - entryPrice) / (entryPrice - stopLoss);
   }
   else
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(takeProfit > 0 && stopLoss > 0)
         return (entryPrice - currentPrice) / (stopLoss - entryPrice);
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Check if position is profitable                                  |
//+------------------------------------------------------------------+
bool IsPositionProfitable(ulong ticket)
{
   if(!OrderSelect(ticket))
      return false;
   
   double profit = OrderGetDouble(ORDER_PROFIT);
   return profit > 0;
}

//+------------------------------------------------------------------+
//| Get total exposure percentage                                    |
//+------------------------------------------------------------------+
double GetTotalExposurePercent()
{
   double totalRisk = 0;
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double stopLoss = PositionGetDouble(POSITION_SL);
            
            if(stopLoss > 0)
            {
               double riskPerLot = MathAbs(openPrice - stopLoss);
               double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
               
               if(tickSize > 0 && tickValue > 0)
               {
                  double loss = riskPerLot / tickSize * tickValue * volume;
                  totalRisk += loss;
               }
            }
         }
      }
   }
   
   if(accountBalance > 0)
      return (totalRisk / accountBalance) * 100;
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Check if new trade is allowed based on exposure                  |
//+------------------------------------------------------------------+
bool IsNewTradeAllowed(double additionalRiskPercent)
{
   double currentExposure = GetTotalExposurePercent();
   double maxExposure = 100.0; // Maximum total exposure
   
   return (currentExposure + additionalRiskPercent) <= maxExposure;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.position = PositionGetTicket(i);
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.deviation = MaxSlippage;
            request.magic = MagicNumber;
            request.comment = OrderComment + " Close All";
            
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

//+------------------------------------------------------------------+
//| Helper function to select order by ticket                        |
//+------------------------------------------------------------------+
bool OrderSelect(ulong ticket)
{
   return PositionSelectByTicket(ticket);
}

//+------------------------------------------------------------------+
