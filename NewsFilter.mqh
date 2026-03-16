#property strict

// NewsFilter.mqh - Economic News Filter with FFCal Integration
// Manages trading suspension and position closing around economic news

class CNewsFilter
{
private:
    // Configuration inputs
    bool m_UseNewsFilter;
    int m_NewsMinutesBefore;
    int m_NewsMinutesAfter;
    int m_NewsImpactLevel;
    bool m_CloseOnHighImpact;
    
    // Trading session parameters
    int m_LondonOpenHour;  // 8:00 GMT
    int m_FridayCloseHour; // 21:00 GMT
    
    // Indicator handles for filtering
    int m_ATRHandle;
    int m_BBHandle;
    int m_EMAHandle;
    int m_ADXHandle;
    int m_RSIHandle;
    int m_VolumeHandle;
    
    // Indicator parameters
    int m_ATRPeriod;
    int m_BBPeriod;
    int m_BBDeviation;
    int m_EMAPeriod;
    int m_ADXPeriod;
    int m_RSIPeriod;
    int m_VolumePeriod;
    
    // Filter thresholds
    double m_MinATR;
    double m_MaxATR;
    double m_MinBBWidth;
    double m_MaxBBWidth;
    double m_ADXThreshold;
    double m_RSIOverbought;
    double m_RSIOversold;
    double m_VolumeThreshold;
    
    // News event tracking
    datetime m_NextNewsTime;
    int m_NextNewsImpact;
    string m_NextNewsCurrency;
    string m_NextNewsEvent;
    
    // Trading state
    bool m_TradingSuspended;
    datetime m_SuspendUntil;
    
public:
    // Constructor
    CNewsFilter() :
        m_UseNewsFilter(true),
        m_NewsMinutesBefore(60),
        m_NewsMinutesAfter(30),
        m_NewsImpactLevel(3),
        m_CloseOnHighImpact(true),
        m_LondonOpenHour(8),
        m_FridayCloseHour(21),
        m_ATRPeriod(14),
        m_BBPeriod(20),
        m_BBDeviation(2),
        m_EMAPeriod(200),
        m_ADXPeriod(14),
        m_RSIPeriod(14),
        m_VolumePeriod(20),
        m_MinATR(0.0005),
        m_MaxATR(0.0020),
        m_MinBBWidth(0.0010),
        m_MaxBBWidth(0.0050),
        m_ADXThreshold(20.0),
        m_RSIOverbought(70.0),
        m_RSIOversold(30.0),
        m_VolumeThreshold(1.5),
        m_TradingSuspended(false),
        m_SuspendUntil(0)
    {
        InitializeIndicators();
    }
    
    // Destructor
    ~CNewsFilter()
    {
        ReleaseIndicators();
    }
    
    // Initialize indicator handles
    void InitializeIndicators()
    {
        m_ATRHandle = iATR(_Symbol, PERIOD_H1, m_ATRPeriod);
        m_BBHandle = iBands(_Symbol, PERIOD_H1, m_BBPeriod, m_BBDeviation, 0, PRICE_CLOSE);
        m_EMAHandle = iMA(_Symbol, PERIOD_H1, m_EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_ADXHandle = iADX(_Symbol, PERIOD_H1, m_ADXPeriod);
        m_RSIHandle = iRSI(_Symbol, PERIOD_H1, m_RSIPeriod, PRICE_CLOSE);
        m_VolumeHandle = iMA(_Symbol, PERIOD_H1, m_VolumePeriod, 0, MODE_SMA, VOLUME_TICK);
    }
    
    // Release indicator handles
    void ReleaseIndicators()
    {
        if(m_ATRHandle != INVALID_HANDLE) IndicatorRelease(m_ATRHandle);
        if(m_BBHandle != INVALID_HANDLE) IndicatorRelease(m_BBHandle);
        if(m_EMAHandle != INVALID_HANDLE) IndicatorRelease(m_EMAHandle);
        if(m_ADXHandle != INVALID_HANDLE) IndicatorRelease(m_ADXHandle);
        if(m_RSIHandle != INVALID_HANDLE) IndicatorRelease(m_RSIHandle);
        if(m_VolumeHandle != INVALID_HANDLE) IndicatorRelease(m_VolumeHandle);
    }
    
    // Set configuration parameters
    void Configure(bool useNewsFilter, int minutesBefore, int minutesAfter, 
                   int impactLevel, bool closeOnHighImpact)
    {
        m_UseNewsFilter = useNewsFilter;
        m_NewsMinutesBefore = minutesBefore;
        m_NewsMinutesAfter = minutesAfter;
        m_NewsImpactLevel = impactLevel;
        m_CloseOnHighImpact = closeOnHighImpact;
    }
    
    // Set filter thresholds
    void SetFilterThresholds(double minATR, double maxATR, double minBBWidth, double maxBBWidth,
                            double adxThreshold, double rsiOverbought, double rsiOversold,
                            double volumeThreshold)
    {
        m_MinATR = minATR;
        m_MaxATR = maxATR;
        m_MinBBWidth = minBBWidth;
        m_MaxBBWidth = maxBBWidth;
        m_ADXThreshold = adxThreshold;
        m_RSIOverbought = rsiOverbought;
        m_RSIOversold = rsiOversold;
        m_VolumeThreshold = volumeThreshold;
    }
    
    // Main update method - call in OnTick()
    void Update()
    {
        if(!m_UseNewsFilter) return;
        
        // Check for upcoming news
        CheckNewsEvents();
        
        // Update trading suspension status
        UpdateTradingSuspension();
        
        // Check for weekend closing
        CheckWeekendClosing();
    }
    
    // Check if trading is allowed
    bool IsTradingAllowed()
    {
        if(!m_UseNewsFilter) return true;
        
        // Check trading session
        if(!IsTradingSession()) return false;
        
        // Check news suspension
        if(m_TradingSuspended) return false;
        
        return true;
    }
    
    // Check if position should be closed due to news
    bool ShouldClosePositions()
    {
        if(!m_UseNewsFilter || !m_CloseOnHighImpact) return false;
        
        if(m_NextNewsImpact >= 3 && m_NextNewsTime > 0)
        {
            datetime now = TimeCurrent();
            int minutesToNews = (int)((m_NextNewsTime - now) / 60);
            
            // Close positions within the specified time before high impact news
            if(minutesToNews <= m_NewsMinutesBefore && minutesToNews > 0)
            {
                return true;
            }
        }
        
        return false;
    }
    
    // Apply indicator filters
    bool CheckIndicatorFilters(ENUM_ORDER_TYPE orderType)
    {
        // ATR volatility filter
        double atrValue = GetIndicatorValue(m_ATRHandle, 0, 0);
        if(atrValue < m_MinATR || atrValue > m_MaxATR) return false;
        
        // Bollinger Bands width filter
        double bbUpper = GetIndicatorValue(m_BBHandle, 1, 0); // Upper band
        double bbLower = GetIndicatorValue(m_BBHandle, 2, 0); // Lower band
        double bbWidth = bbUpper - bbLower;
        if(bbWidth < m_MinBBWidth || bbWidth > m_MaxBBWidth) return false;
        
        // EMA trend filter
        double emaValue = GetIndicatorValue(m_EMAHandle, 0, 0);
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        if(orderType == ORDER_TYPE_BUY && currentPrice <= emaValue) return false;
        if(orderType == ORDER_TYPE_SELL && currentPrice >= emaValue) return false;
        
        // ADX trend strength filter
        double adxValue = GetIndicatorValue(m_ADXHandle, 0, 0); // ADX main line
        if(adxValue < m_ADXThreshold) return false;
        
        // RSI overbought/oversold filter
        double rsiValue = GetIndicatorValue(m_RSIHandle, 0, 0);
        if(orderType == ORDER_TYPE_BUY && rsiValue >= m_RSIOverbought) return false;
        if(orderType == ORDER_TYPE_SELL && rsiValue <= m_RSIOversold) return false;
        
        // Volume confirmation filter
        double volumeValue = GetIndicatorValue(m_VolumeHandle, 0, 0);
        double volumeSMA = GetIndicatorValue(m_VolumeHandle, 0, 1);
        
        if(volumeSMA > 0)
        {
            double volumeRatio = volumeValue / volumeSMA;
            if(volumeRatio < m_VolumeThreshold) return false;
        }
        
        return true;
    }
    
    // Check breakout confirmation with ATR
    bool IsBreakoutConfirmed(ENUM_ORDER_TYPE orderType, double breakoutLevel)
    {
        double atrValue = GetIndicatorValue(m_ATRHandle, 0, 0);
        double currentPrice = SymbolInfoDouble(_Symbol, 
            (orderType == ORDER_TYPE_BUY) ? SYMBOL_ASK : SYMBOL_BID);
        
        if(orderType == ORDER_TYPE_BUY)
        {
            return currentPrice > breakoutLevel + atrValue;
        }
        else // ORDER_TYPE_SELL
        {
            return currentPrice < breakoutLevel - atrValue;
        }
    }
    
private:
    // Check for upcoming news events using FFCal
    void CheckNewsEvents()
    {
        // Reset news tracking
        m_NextNewsTime = 0;
        m_NextNewsImpact = 0;
        m_NextNewsCurrency = "";
        m_NextNewsEvent = "";
        
        // In a real implementation, this would connect to FFCal API
        // For this example, we'll simulate news checking
        SimulateNewsCheck();
    }
    
    // Simulate news checking (replace with actual FFCal integration)
    void SimulateNewsCheck()
    {
        datetime now = TimeCurrent();
        
        // Check next 24 hours for news events
        for(int i = 0; i < 24; i++)
        {
            datetime checkTime = now + (i * 3600);
            
            // Simulate finding a news event
            // In real implementation, query FFCal for events at checkTime
            if(i == 2) // Simulate news in 2 hours
            {
                m_NextNewsTime = checkTime;
                m_NextNewsImpact = 3; // High impact
                m_NextNewsCurrency = "USD";
                m_NextNewsEvent = "NFP Data";
                break;
            }
        }
    }
    
    // Update trading suspension status
    void UpdateTradingSuspension()
    {
        if(m_NextNewsTime == 0)
        {
            m_TradingSuspended = false;
            m_SuspendUntil = 0;
            return;
        }
        
        datetime now = TimeCurrent();
        
        // Check if we're in the news window
        if(m_NextNewsImpact >= m_NewsImpactLevel)
        {
            int minutesToNews = (int)((m_NextNewsTime - now) / 60);
            int minutesAfterNews = (int)((now - m_NextNewsTime) / 60);
            
            // Suspend trading before news
            if(minutesToNews <= m_NewsMinutesBefore && minutesToNews > 0)
            {
                m_TradingSuspended = true;
                m_SuspendUntil = m_NextNewsTime + (m_NewsMinutesAfter * 60);
                return;
            }
            
            // Suspend trading after news
            if(minutesAfterNews >= 0 && minutesAfterNews <= m_NewsMinutesAfter)
            {
                m_TradingSuspended = true;
                m_SuspendUntil = m_NextNewsTime + (m_NewsMinutesAfter * 60);
                return;
            }
        }
        
        // Check if suspension period has ended
        if(m_SuspendUntil > 0 && now > m_SuspendUntil)
        {
            m_TradingSuspended = false;
            m_SuspendUntil = 0;
        }
    }
    
    // Check for weekend closing
    void CheckWeekendClosing()
    {
        MqlDateTime timeStruct;
        TimeToStruct(TimeCurrent(), timeStruct);
        
        // Friday 21:00 GMT closing
        if(timeStruct.day_of_week == 5 && timeStruct.hour >= m_FridayCloseHour)
        {
            // Close all positions (this would be called from EA)
            // Position closing logic should be implemented in the main EA
        }
    }
    
    // Check if current time is within trading session
    bool IsTradingSession()
    {
        MqlDateTime timeStruct;
        TimeGMT(timeStruct);
        
        // Check if after London open (8:00 GMT)
        if(timeStruct.hour < m_LondonOpenHour) return false;
        
        // All weekdays are allowed
        if(timeStruct.day_of_week == 0 || timeStruct.day_of_week == 6) return false;
        
        return true;
    }
    
    // Helper function to get indicator values
    double GetIndicatorValue(int handle, int buffer, int shift)
    {
        if(handle == INVALID_HANDLE) return 0.0;
        
        double value[1];
        if(CopyBuffer(handle, buffer, shift, 1, value) > 0)
        {
            return value[0];
        }
        return 0.0;
    }
    
    // New bar detection (from reference patterns)
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
    
    // Breakout entry functions (from reference patterns)
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
    
    // Retest check after breakout (from reference patterns)
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
    
    // Trend entry (MA crossover) - adapted from reference patterns
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
};
