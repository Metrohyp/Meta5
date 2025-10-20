//+------------------------------------------------------------------+
//|                                         Nodezilla101_EA_BOT      |
//|                                                                  |
//| Automated trading bot using a triple-confirmation strategy.      |
//| Features smart SL/TP placement and instant Telegram alerts.      |
//|                                                                  |
//| Custom bots & advanced settings available upon request.          |
//| Contact: [+2348162150628] | [Nodezilla101@gmail.com]             |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade Trade;

//============================== Inputs ==============================
//================================================================================
//                 --- CORE STRATEGY & RISK CONTROLS ---
//================================================================================
// These are the most important settings you will adjust day-to-day.

// --- General ---
input bool           Auto_Trade       = true;     // MASTER SWITCH: true = place trades, false = signals only

//---- Telegram
input string          TG_BOT_TOKEN         = "7923520753:AAGmdxtRevcxVa_bg3BdNVvkzFj1_4gCoC8";
input string          TG_CHAT_ID           = "394044850";
input bool            TG_Send_Images       = false; // reserved (text only here)

// --- Main Strategy ---
input ENUM_TIMEFRAMES TF_Trade        = PERIOD_H1;    // The timeframe the main strategy runs on.
input double         Risk_Percent     = 1;          // Risk % for main trades. Set to 0 to use Fixed_Lots.
input double         Fixed_Lots       = 0.50;       // Lot size for main trades if Risk_Percent is 0.

// --- Scalp Strategy ---
input bool           Use_Scalp_Mode   = true;     // scalping engine on/off.
input ENUM_TIMEFRAMES TF_Scalp        = PERIOD_M15;   // scalp strategy timeframe.
input bool           Scalp_Use_Fixed_Lot = false;  // true = use fixed lot below, false = use risk %
input double         Fixed_Lots_Scalp = 0.50;      // scalp trades Lot size.
input double         Risk_Percent_Scalp = 1;      // if >0, overrides and uses this absolute % just for scalps

// --- Main Strategy Filters ---
input bool           Use_HTF_Breakout_Filter = true;// Require a breakout on a higher timeframe.
input int            HTF_Filter_Mode = 0;              // 0=Trend Align, 1=Breakout, 2=BOTH (Trend AND Breakout)
input ENUM_TIMEFRAMES TF_HTF_Breakout   = PERIOD_H4;    // Timeframe for the filter.

input bool           Scalp_Gate_By_HTF  = true;     // Require scalp trades to align with HTF breakout.
input ENUM_TIMEFRAMES TF_Scalp_Gate_HTF = PERIOD_H1; // scalp alignment filter Timeframe.

input bool           Cancel_Pending_On_Flip = true; // Cancel pending orders if SuperTrend flips.
input bool           Use_Pending_Stop_Entries = true;
input ENUM_TIMEFRAMES TF_Main_Cancel_Gate  = PERIOD_M15; // Main trade pending orders Timeframe to watch.

input bool           Scalp_Use_Pending_Stop_Entries = true;
input ENUM_TIMEFRAMES TF_Scalp_Cancel_Gate = PERIOD_M5;  // Scalp trade pending orders Timeframe to watch.
// --- NEW: Retracement Limit Entry Settings ---
input bool           Use_Retrace_Limit_Entry = true;    // If true, adds a limit order on pullback.


// HTF divergence filter inputs (add with other 'input' lines)
input bool    Use_HTF_Filter            = true;                    // enable HTF divergence filter

// --- Master Strategy Selection ---
input int            Entry_Mode = 2; // 0=Trend-Following, 1=Reversal (Divergence), 2=BOTH
input int            Directional_Filter_Mode = 0; // 0=HTF Trend/Breakout, 1=HTF Divergence

// --- Settings for HTF Divergence Filter (Directional Mode 1) ---
input ENUM_TIMEFRAMES TF_HTF_Divergence = PERIOD_M4;    // Timeframe to check for directional divergence.
input ENUM_TIMEFRAMES TF_Scalp_HTF_Divergence = PERIOD_H1; // HTF Divergence filter just for scalps

// --- General Entry Filters ---
input bool           Use_OverboughtOversold_Filter = true; // Block entries in extreme WPR zones.
input double         WPR_Overbought_Level          = -15;  // Level above which buys are blocked.
input double         WPR_Oversold_Level            = -90;  // Level below which sells are blocked.

// --- Proactive & Emergency Exits ---
input bool           Use_Momentum_Exit_Filter = true; // If true, exits on signs of trend exhaustion (divergence).
input int            Divergence_Lookback_Bars = 25;   // How many bars to check for divergence.
//================================================================================
//                 --- TRADE MANAGEMENT & EXITS ---
//================================================================================

// --- NEW: Momentum Cooldown After Win ---
input int Cooldown_Momentum_Bars = 5; // momentum after a win, How many bars to check only.

// --- Trailing Stops ---
input bool           Use_ATR_Trailing   = true;    // Dynamic SL that follows price based on volatility.
input int            ATR_Period_Trail   = 10;       // <-- ATR period for the trailing stop
input double         ATR_Trail_Mult     = 2.5;      // Multiplier for ATR Trail. Higher = wider trail.
input bool           Use_HalfStep_Trailing = false;  // Alternative trail: SL moves half the distance to TP.
input bool           HalfTrail_NewBar_Only = true; // <-- Only update half-step on new bars

// --- Break-Even ---
input double         BE_Activation_TP_Percent = 15.0; // Move SL to BE when trade is X% of the way to TP.
input double         BE_Profit_Percent        = 5.0;  // lock in at BE profit (as % of TP).
input double         BE_Buffer_Points         = 100.0; // Profit gap in points for BE (e.g., 100)

// --- NEW: PARTIAL CLOSE AT TP ---
input bool           Use_Partial_Close         = true;  // Enable partial closing near TP
input double         Partial_Close_TP_Percent  = 90.0;  // Trigger partial close at X% of the way to TP
input double         Partial_Close_Volume_Percent = 50.0; // Close X% of the position volume

// --- Emergency Exit ---
input bool           Use_Volatility_Entry_Filter = true; // Block new entries if last candle was too big
input bool           Use_Volatility_CircuitBreaker = true; // Emergency brake for extreme volatility.
input double         CircuitBreaker_ATR_Mult = 4.5;    // Closes all if a candle is > X times the average size.

// --- Profit Targets (Risk/Reward) ---
input double         RR_Min           = 2.0;      // MINIMUM R:R for main trades.
input double         RR_Max           = 10.0;     // MAXIMUM R:R for main trades.
input double         Scalp_RR_Min     = 2.0;      // MINIMUM R:R for scalp trades.
input double         Scalp_RR_Max     = 10.0;     // MAXIMUM R:R for scalp trades.
input double         TP_Pullback_ATR_Mult = 0.5; // NEW: Pulls TP back by this ATR multiple. Set to 0 to disable.


//================================================================================
//                 --- ENTRY FILTERS & QUALITY CONTROLS ---
//================================================================================
// These settings make the EA more selective about which trades to take.

// --- NEW: Breakout Confirmation Filter ---
input bool           Use_Breakout_Confirmation   = true; // Require a sequence of candles to confirm a breakout.
input int            Required_Confirmation_Candles = 2;  // Number of follow-up candles required (2 or 3).

// --- Main Strategy Filters ---
input bool           Use_H1H4_Filter    = true;     // Require main trades to align with H1/H4 SuperTrend.
input bool           Use_ST_Flip_Retest = true;      // Wait for price to pull back to the ST line before entry.
input int            Max_Entry_Stages   = 10;        // Allow adding to a trade up to X times.
input bool           One_Trade_At_A_Time = false;   // If true, only one main trade is allowed at a time.

// --- Scalp Strategy Filters ---
input bool           Scalp_Only_When_No_Main = false; // Block scalps if a main trade is already open.
input int            Scalp_Max_Concurrent = 6;      // Max number of simultaneous scalp trades.

// --- NEW: DYNAMIC SPREAD FILTER ---
input bool           Use_Dynamic_Spread_Filter = true;  // Enable/disable the dynamic spread filter.
input int            Avg_Spread_Lookback_Bars  = 20;    // Number of bars to calculate average spread.
input double         Spread_Filter_Multiplier  = 3.0;   // Block if current spread > AvgSpread * Multiplier.

// --- NEW: TRADING SESSION TIMER ---
//Overnight Sessions: The logic can also handle overnight sessions. For example, if you set the start to 22:00 and the end to 05:00
input bool           Use_Time_Filter   = false;  // true = Only trade during the session below
input int            Trade_Start_Hour  = 9;      // Start hour (server time, e.g., 9)
input int            Trade_Start_Min   = 0;      // Start minute (e.g., 0)
input int            Trade_End_Hour    = 17;     // End hour (server time, e.g., 17)
input int            Trade_End_Min     = 0;      // End minute (e.g., 0)

//================================================================================
//                --- ADVANCED & SYSTEM SETTINGS ---
//================================================================================
// Fine-tuning parameters. Adjust with caution.

// --- Indicator Settings ---
input int            ST_ATR_Period    = 10;
input double         ST_ATR_Mult      = 3.0;
input int            Jaw_Period       = 13;
input int            Jaw_Shift        = 8;
input int            Teeth_Period     = 8;
input int            Teeth_Shift      = 5;
input int            Lips_Period      = 5;
input int            Lips_Shift       = 3;
input double         AO_Min_Strength  = 3.0;
input double         AO_Scalp_Min_Strength = 3;
// --- NEW: Momentum Indicator Filter Settings ---
input bool           Use_Momentum_Filter = true;   // true = require Momentum confirmation
input int            Momentum_Period     = 14;   // Period for the Momentum indicator
input double         Mom_Min_Strength    = 0.5;  // Required strength (distance from 100)
input double         Mom_Scalp_Min_Strength = 0.3; // Required strength for scalps
input bool           Use_WPR_Bias     = true;
input bool           Use_WPR_Cross    = false;

// --- Pending Order Mechanics ---
input double         StopEntry_Offset_ATR = 0.2;
input int            StopEntry_Expiry_Bars = 12;
input double         Scalp_StopEntry_Offset_ATR = 0.02;
input int            Scalp_StopEntry_Expiry_Bars = 12;
input double         Scalp_Market_Entry_ATR_Zone = 3;

// --- Manual Trade Management ---
input bool           ApplyToManualTrades = true;
input bool           Manual_Set_Initial_SLTP = true;
input bool           Manual_Use_Fib_Targets = true;
input bool           Manual_Use_RR_Range = true;
input double         Manual_RR_Min      = 1.5;
input double         Manual_RR_Max      = 10.0;
input double         Manual_TP_Max_ATR_Mult = 6.0;
input double         Manual_TP_Swing_Ext_ATR_Mult = 1.50;

// --- Detailed SL/TP Mechanics ---
input bool           Use_Fib_Targets    = true;
input bool           Use_RR_Range       = true;
input bool           Scalp_Use_RR_Range = true;
input bool           Use_Dynamic_SL_ATR = true;
input double         ATR_SL_Buffer_Mult = 0.1;
input double         SL_ATR_Min         = 1.5;
input double         SL_ATR_Max         = 6.0;
input double         SL_Swing_Pad_ATR   = 0.60;
input double         Min_SL_ATR_Mult    = 0.75;
input int            Min_SL_Points      = 0;
input bool           Use_ST_as_Stop     = true;
input double         ST_Stop_Pad_Mult   = 0.8;
input double         TP_Max_ATR_Mult    = 10.0;
input double         TP_Swing_Ext_ATR_Mult = 1.50;
input double         Scalp_TP_Max_ATR_Mult = 6.0;
input double         Scalp_TP_Swing_Ext_ATR_Mult = 1.50;
input int            Scalp_ATR_Period   = 10;
input double         Scalp_SL_ATR_Mult  = 1;
input bool           Protect_Scalp_SLTP = false;
input bool           Adjust_All_Exclude_Scalps = false;

// --- Detailed Filter Mechanics ---
input int            HTF_Breakout_Lookback = 600;
input double         HTF_Breakout_ATR_Margin = 0.25;
input int            HTF_Breakout_Mode  = 0;
input int            HTF_Breakout_MaxAgeBars = 3;
input double         Retest_ATR_Tolerance = 0.25;
input double         AddEntry_Trigger_Ratio = 0.3;
input bool           Adjust_All_To_Latest = true;
input int            Min_Bars_After_Flip = 1;
input double         Confirm_Close_Dist_ATR = 0.20;
input bool           Require_Retrace_Or_Breakout = false;
input double         Breakout_ATR_Margin = 0.20;
input double         Scalp_Gate_ATR_Margin = 0.20;
input double         Scalp_Risk_Mult    = 2.0;

// --- System & Housekeeping ---
input long           Magic            = 250925;
input long           Magic_Reversal   = 250926; // Magic number for Reversal/Divergence trades
input int            Cooldown_Bars    = 2;
input int            Slippage_Points  = 50;
input bool           Send_Closed_Trade_Alerts = true;
input bool           Send_Weekly_Report = true;
input int            Weekly_Report_DOW = 0;
input int            Weekly_Report_Hour = 22;
input int            Weekly_Report_Min = 0;
input bool           Send_Monthly_Report = true;
input int            Monthly_Report_DOM = 1;
input int            Monthly_Report_Hour = 22;
input int            Monthly_Report_Min = 0;

//============================== Globals =============================
datetime lastTradeBarTime = 0;
// --- Retest/stack state
int      prevDir_ST   = 0;    // previous ST dir on M15
datetime flipBar      = 0;    // bar time when ST flipped
int      stageCount   = 0;    // 0=none, 1=main, 2/3=added retests
datetime lastStageBar = 0;    // bar time of last stage entry
datetime g_lastWeeklyReportSent  = 0;
datetime g_lastMonthlyReportSent = 0;
// ADD THIS NEW GLOBAL VARIABLE
datetime g_eaStartTime;
bool g_trailingActivated = false; // NEW: Flag to track if BE or Trailing has started
bool g_breakoutConfirmed = false; // NEW: Flag to track if a clean breakout is confirmed for the current trend
// NEW: Flags for Momentum Cooldown
bool     g_momentumCooldownActive = false;
datetime g_cooldownStartTime      = 0;
ulong g_partialClosedTickets[]; // Array to track tickets that have been partially closed
bool sent = false;
//============================== Utils ===============================
string tfstr(ENUM_TIMEFRAMES tf)
{
    switch(tf)
    {
        case PERIOD_M1:   return "M1";
        case PERIOD_M5:   return "M5";
        case PERIOD_M15:  return "M15";
        case PERIOD_M30:  return "M30";
        case PERIOD_H1:   return "H1";
        case PERIOD_H4:   return "H4";
        case PERIOD_D1:   return "D1";
    }
    return "TF";
}

// Drop-in replacement for your SendTG(...)
bool SendTG(const string msg)
{
    if(StringLen(TG_BOT_TOKEN)<10 || StringLen(TG_CHAT_ID)<1) return false;
    
    string url   = "https://api.telegram.org/bot"+(string)TG_BOT_TOKEN+"/sendMessage";
    string body  = "chat_id="+(string)TG_CHAT_ID
    + "&parse_mode=HTML&disable_web_page_preview=1&text="+URLEncode(msg);
    
    char post[];
    StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
    
    char   result[];
    string resp_headers;
    
    // Correct MT5 signature: method, url, headers, timeout, data, result, resp_headers
    int res = WebRequest("POST",
                         url,
                         "Content-Type: application/x-www-form-urlencoded\r\n",
                         5000,
                         post,
                         result,
                         resp_headers);
    
    if(res==-1){ Print("WebRequest error: ", GetLastError()); return false; }
    return true;
}

double PointToPrice(double points) { return points * _Point; }

// URL-encode for Telegram (UTF-8 → %XX)
string URLEncode(const string s)
{
    uchar bytes[];
    StringToCharArray(s, bytes, 0, WHOLE_ARRAY, CP_UTF8);
    string out="";
    for(int i=0;i<ArraySize(bytes);i++)
    {
        uchar c = bytes[i];
        bool safe = ( (c>='a' && c<='z') || (c>='A' && c<='Z') ||
                     (c>='0' && c<='9') || c=='-' || c=='_' || c=='.' || c=='~' );
        if(safe) out += StringFormat("%c", c);
        else if(c==' ') out += "%20";
        else out += StringFormat("%%%02X", c);
    }
    return out;
}
//======================== Indicator Helpers =========================

// --- NEW HELPER: Calculates average spread over recent bars ---
double GetAverageSpreadBars(ENUM_TIMEFRAMES tf, int lookbackBars)
{
    if (lookbackBars <= 0) return 0.0;

    MqlRates rates[];
    ArraySetAsSeries(rates, true); // Ensure chronological order for loop

    // Copy rates data including spread for the lookback period + current bar
    if (CopyRates(_Symbol, tf, 0, lookbackBars + 1, rates) <= 0)
    {
        Print("GetAverageSpreadBars: Failed to copy rates for ", _Symbol, " on ", tf);
        return 0.0; // Return 0 if data copying fails
    }

    double totalSpread = 0;
    int    validBars   = 0;

    // Iterate from the oldest bar (index lookbackBars) up to the most recently closed bar (index 1)
    for (int i = lookbackBars; i >= 1; i--)
    {
        // MT5 stores spread in points in the 'spread' field of MqlRates
        if (rates[i].spread > 0)
        {
            totalSpread += rates[i].spread;
            validBars++;
        }
    }

    if (validBars == 0)
    {
        // Print("GetAverageSpreadBars: No valid spread data found in the lookback period for ", _Symbol, " on ", tf);
        return 0.0; // Avoid division by zero
    }

    // Calculate the average spread in points
    double averageSpreadPoints = totalSpread / validBars;

    return averageSpreadPoints; // Return average spread in points
}
// --- END NEW HELPER ---

// --- NEW: Helper function to check if we are within the allowed trading session ---
bool IsTradeTime()
{
    // 1. If the filter is turned off, it's always time to trade.
    if (!Use_Time_Filter)
    {
        return true;
    }

    // 2. Get the server's current time
    MqlDateTime now;
    TimeCurrent(now);
    int currentHour = now.hour;
    int currentMin  = now.min;

    // 3. Convert all times to total minutes since midnight for easy comparison
    int startTime = Trade_Start_Hour * 60 + Trade_Start_Min;
    int endTime   = Trade_End_Hour   * 60 + Trade_End_Min;
    int currentTime = currentHour * 60 + currentMin;

    // Case 1: Normal Day Session (e.g., 09:00 - 17:00)
    if (startTime <= endTime)
    {
        if (currentTime >= startTime && currentTime < endTime)
        {
            return true; // We are within the session
        }
    }
    // Case 2: Overnight Session (e.g., 22:00 - 05:00)
    else
    {
        if (currentTime >= startTime || currentTime < endTime)
        {
            return true; // We are in the overnight session
        }
    }

    // If none of the above, we are outside the allowed trading time
    return false;
}
//======================== Indicator Helpers =========================
// Get Momentum value (oscillates around 100)
double MomentumValue(ENUM_TIMEFRAMES tf, int shift=1)
{
    int h = iMomentum(_Symbol, tf, Momentum_Period, PRICE_CLOSE);
    if(h==INVALID_HANDLE) return 100.0;
    double mom[];
    ArraySetAsSeries(mom,true);
    if(CopyBuffer(h,0,0,shift+3,mom)<=shift){ IndicatorRelease(h); return 100.0; }
    double v = mom[shift];
    IndicatorRelease(h);
    return v;
}

// WPR value ([-100..0]) -> e.g. -20, -50, -80
// ADD THIS MISSING FUNCTION
int GetHTFDivergenceDirection(ENUM_TIMEFRAMES tf, int lookbackBars)
{
    if(lookbackBars < 2) return 0;
    MqlRates prices[];
    if(CopyRates(_Symbol, tf, 0, lookbackBars, prices) < lookbackBars) return 0;
    int hAO = iAO(_Symbol, tf);
    if(hAO == INVALID_HANDLE) return 0;
    double ao_buffer[];
    if(CopyBuffer(hAO, 0, 0, lookbackBars, ao_buffer) < lookbackBars) { IndicatorRelease(hAO); return 0; }
    ArraySetAsSeries(prices, true);
    ArraySetAsSeries(ao_buffer, true);
    
    // Check for bullish divergence (potential BUY)
    int lowest_low_index = -1; double lowest_low_price = 9999999;
    for(int i = 1; i < lookbackBars; i++) {
        if(prices[i].low < lowest_low_price) {
            lowest_low_price = prices[i].low;
            lowest_low_index = i;
        }
    }
    if(lowest_low_index != -1) {
        bool price_makes_new_low = (prices[0].low < lowest_low_price);
        bool momentum_is_higher = (ao_buffer[0] > ao_buffer[lowest_low_index]);
        if(price_makes_new_low && momentum_is_higher) {
            IndicatorRelease(hAO); return -1; // Bullish divergence detected (potential buy)
        }
    }
    
    // Check for bearish divergence (potential SELL)
    int highest_high_index = -1; double highest_high_price = 0;
    for(int i = 1; i < lookbackBars; i++) {
        if(prices[i].high > highest_high_price) {
            highest_high_price = prices[i].high;
            highest_high_index = i;
        }
    }
    if(highest_high_index != -1) {
        bool price_makes_new_high = (prices[0].high > highest_high_price);
        bool momentum_is_lower = (ao_buffer[0] < ao_buffer[highest_high_index]);
        if(price_makes_new_high && momentum_is_lower) {
            IndicatorRelease(hAO); return 1; // Bearish divergence detected (potential sell)
        }
    }
    
    IndicatorRelease(hAO);
    return 0; // No divergence
}

// Function 1: Detects divergence for proactive EXITS (Checks BOTH AO and Momentum)
bool CheckMomentumDivergence(long tradeType, int lookbackBars, ENUM_TIMEFRAMES tf)
{
    if(lookbackBars < 2) return false;

    // --- Get Price Data ---
    MqlRates prices[];
    if(CopyRates(_Symbol, tf, 0, lookbackBars, prices) < lookbackBars) return false;
    ArraySetAsSeries(prices, true);

    // --- Get Awesome Oscillator (AO) Data ---
    int hAO = iAO(_Symbol, tf);
    if(hAO == INVALID_HANDLE) return false;
    double ao_buffer[];
    if(CopyBuffer(hAO, 0, 0, lookbackBars, ao_buffer) < lookbackBars)
    {
        IndicatorRelease(hAO);
        return false;
    }
    ArraySetAsSeries(ao_buffer, true);

    // --- NEW: Get Momentum Indicator Data ---
    int hMom = iMomentum(_Symbol, tf, Momentum_Period, PRICE_CLOSE);
    if(hMom == INVALID_HANDLE)
    {
        IndicatorRelease(hAO);
        return false;
    }
    double mom_buffer[];
    if(CopyBuffer(hMom, 0, 0, lookbackBars, mom_buffer) < lookbackBars)
    {
        IndicatorRelease(hAO);
        IndicatorRelease(hMom);
        return false;
    }
    ArraySetAsSeries(mom_buffer, true);
    
    // --- Check for Divergence ---
    if(tradeType == POSITION_TYPE_BUY) // Look for BEARISH divergence to exit a BUY
    {
        int highest_high_index = -1;
        double highest_high_price = 0;
        for(int i = 1; i < lookbackBars; i++) {
            if(prices[i].high > highest_high_price) {
                highest_high_price = prices[i].high;
                highest_high_index = i;
            }
        }
        if(highest_high_index != -1) {
            bool price_makes_new_high = (prices[0].high > highest_high_price);
            
            // --- UPDATED: Check both indicators ---
            bool ao_momentum_is_lower  = (ao_buffer[0] < ao_buffer[highest_high_index]);
            bool mom_momentum_is_lower = (mom_buffer[0] < mom_buffer[highest_high_index]);
            
            if(price_makes_new_high && (ao_momentum_is_lower || mom_momentum_is_lower)) {
                IndicatorRelease(hAO);
                IndicatorRelease(hMom);
                return true; // Bearish divergence detected on AO or Momentum!
            }
        }
    }
    else // Look for BULLISH divergence to exit a SELL
    {
        int lowest_low_index = -1;
        double lowest_low_price = 9999999;
        for(int i = 1; i < lookbackBars; i++) {
            if(prices[i].low < lowest_low_price) {
                lowest_low_price = prices[i].low;
                lowest_low_index = i;
            }
        }
        if(lowest_low_index != -1) {
            bool price_makes_new_low = (prices[0].low < lowest_low_price);
            
            // --- UPDATED: Check both indicators ---
            bool ao_momentum_is_higher  = (ao_buffer[0] > ao_buffer[lowest_low_index]);
            bool mom_momentum_is_higher = (mom_buffer[0] > mom_buffer[lowest_low_index]);
            
            if(price_makes_new_low && (ao_momentum_is_higher || mom_momentum_is_higher)) {
                IndicatorRelease(hAO);
                IndicatorRelease(hMom);
                return true; // Bullish divergence detected on AO or Momentum!
            }
        }
    }

    // --- Release all handles ---
    IndicatorRelease(hAO);
    IndicatorRelease(hMom);
    return false;
}

// Function 2: Detects divergence for reversal ENTRIES
bool CheckDivergenceForEntry(long tradeType, int lookbackBars, ENUM_TIMEFRAMES tf)
{
    if(lookbackBars < 2) return false;
    MqlRates prices[];
    if(CopyRates(_Symbol, tf, 0, lookbackBars, prices) < lookbackBars) return false;
    int hAO = iAO(_Symbol, tf);
    if(hAO == INVALID_HANDLE) return false;
    double ao_buffer[];
    if(CopyBuffer(hAO, 0, 0, lookbackBars, ao_buffer) < lookbackBars) { IndicatorRelease(hAO); return false; }
    ArraySetAsSeries(prices, true);
    ArraySetAsSeries(ao_buffer, true);
    
    if(tradeType == POSITION_TYPE_BUY) // Look for BULLISH divergence for a BUY ENTRY
    {
        int lowest_low_index = -1; double lowest_low_price = 9999999;
        for(int i = 1; i < lookbackBars; i++) {
            if(prices[i].low < lowest_low_price) {
                lowest_low_price = prices[i].low;
                lowest_low_index = i;
            }
        }
        if(lowest_low_index != -1) {
            // Condition 1: Price makes a new lower low.
            bool price_makes_new_low = (prices[0].low < lowest_low_price);
            // Condition 2: AO makes a higher low.
            bool momentum_is_higher = (ao_buffer[0] > ao_buffer[lowest_low_index]);
            if(price_makes_new_low && momentum_is_higher) {
                IndicatorRelease(hAO); return true; // Bullish divergence detected!
            }
        }
    }
    else // Look for BEARISH divergence for a SELL ENTRY
    {
        int highest_high_index = -1; double highest_high_price = 0;
        for(int i = 1; i < lookbackBars; i++) {
            if(prices[i].high > highest_high_price) {
                highest_high_price = prices[i].high;
                highest_high_index = i;
            }
        }
        if(highest_high_index != -1) {
            // Condition 1: Price makes a new higher high.
            bool price_makes_new_high = (prices[0].high > highest_high_price);
            // Condition 2: AO makes a lower high.
            bool momentum_is_lower = (ao_buffer[0] < ao_buffer[highest_high_index]);
            if(price_makes_new_high && momentum_is_lower) {
                IndicatorRelease(hAO); return true; // Bearish divergence detected!
            }
        }
    }
    IndicatorRelease(hAO);
    return false;
}

// UPGRADED FUNCTION: Adds a limit order at a calculated SuperTrend retest point.
void ManageRetraceLimitOrders()
{
    if (!Use_Retrace_Limit_Entry || CountPendingThisEA() != 1)
    {
        return;
    }
    
    ulong  stop_order_ticket = 0;
    long   stop_order_type = 0;
    double stop_order_sl = 0;
    double stop_order_tp = 0;
    
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(OrderGetTicket(i)))
        {
            if (OrderGetInteger(ORDER_MAGIC) == Magic && OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
                stop_order_ticket = OrderGetTicket(i);
                stop_order_type = OrderGetInteger(ORDER_TYPE);
                stop_order_sl = OrderGetDouble(ORDER_SL);
                stop_order_tp = OrderGetDouble(ORDER_TP);
                break;
            }
        }
    }
    
    if (stop_order_ticket == 0 || stop_order_sl <= 0 || stop_order_tp <= 0) return;
    
    double limit_price = 0;
    if(!FindRetraceEntryWithinRange(stop_order_type, stop_order_sl, stop_order_tp, limit_price))
    {
        return;
    }
    
    double new_sl = 0, new_tp = 0;
    bool isBuy = (stop_order_type == ORDER_TYPE_BUY_STOP);
    
    double pH, pL, atr;
    if(!GetSwingsATR(TF_Main_Cancel_Gate, 300, ST_ATR_Period, pH, pL, atr)) return;
    if(!BuildSLTP_FromSwings(isBuy, limit_price, pH, pL, atr, Use_Fib_Targets, RR_Min, new_sl, new_tp)) return;
    
    double lots = LotsByRisk(Risk_Percent, MathAbs(limit_price - new_sl) / _Point);
    if(lots <= 0) lots = Fixed_Lots;
    
    ENUM_ORDER_TYPE_TIME time_type = Cancel_Pending_On_Flip ? ORDER_TIME_GTC : ORDER_TIME_SPECIFIED;
    datetime expiration = Cancel_Pending_On_Flip ? 0 : TimeCurrent() + (StopEntry_Expiry_Bars * PeriodSeconds(TF_Trade));
    
    if(isBuy)
    {
        Trade.BuyLimit(lots, limit_price, _Symbol, new_sl, new_tp, time_type, expiration, "V25 Buy Retrace Limit");
    }
    else
    {
        Trade.SellLimit(lots, limit_price, _Symbol, new_sl, new_tp, time_type, expiration, "V25 Sell Retrace Limit");
    }
}

// NEW HELPER FUNCTION: Finds a valid SuperTrend retest entry within a given price range.
bool FindRetraceEntryWithinRange(long tradeType, double rangeBottom, double rangeTop, double &retracePriceOut)
{
    // Get the SuperTrend line on the retrace timeframe (the main cancel gate)
    double st_line;
    int st_dir;
    if (!CalcSuperTrend(TF_Main_Cancel_Gate, ST_ATR_Period, ST_ATR_Mult, 1, st_line, st_dir))
    {
        return false; // Cannot get ST data.
    }
    
    bool isBuy = (tradeType == ORDER_TYPE_BUY_STOP);
    
    // THE CORE RULE: Check if the ST line is a valid retrace entry WITHIN the SL/TP range.
    if (isBuy && st_dir > 0)
    {
        // For a BUY, the ST line must be above the SL and below the current price (a valid limit entry)
        if (st_line > rangeBottom && st_line < SymbolInfoDouble(_Symbol, SYMBOL_ASK))
        {
            retracePriceOut = st_line;
            return true;
        }
    }
    else if (!isBuy && st_dir < 0)
    {
        // For a SELL, the ST line must be below the SL and above the current price
        if (st_line < rangeTop && st_line > SymbolInfoDouble(_Symbol, SYMBOL_BID))
        {
            retracePriceOut = st_line;
            return true;
        }
    }
    
    return false; // No valid retrace entry found.
}
// NEW, UPGRADED FUNCTION: Manages pending orders based on their type (Main vs. Scalp).
void ManagePendingOrders()
{
    if (!Cancel_Pending_On_Flip) return;
    
    double st_main_line;
    int st_main_dir;
    if (!CalcSuperTrend(TF_Main_Cancel_Gate, ST_ATR_Period, ST_ATR_Mult, 1, st_main_line, st_main_dir)) return;
    
    double st_scalp_line;
    int st_scalp_dir;
    if (!CalcSuperTrend(TF_Scalp_Cancel_Gate, ST_ATR_Period, ST_ATR_Mult, 1, st_scalp_line, st_scalp_dir)) return;
    
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if (OrderSelect(ticket))
        {
            if (OrderGetInteger(ORDER_MAGIC) == Magic && OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
                long   orderType = OrderGetInteger(ORDER_TYPE);
                string comment   = OrderGetString(ORDER_COMMENT);
                bool   isScalp   = (StringFind(comment, "Scalp", 0) >= 0);
                
                int relevantST_dir = isScalp ? st_scalp_dir : st_main_dir;
                ENUM_TIMEFRAMES relevant_TF = isScalp ? TF_Scalp_Cancel_Gate : TF_Main_Cancel_Gate;
                
                bool isBuyOrder  = (orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT);
                bool isSellOrder = (orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_LIMIT);
                
                if ((isBuyOrder && relevantST_dir < 0) || (isSellOrder && relevantST_dir > 0))
                {
                    Trade.OrderDelete(ticket);
                    if (Trade.ResultRetcode() == TRADE_RETCODE_DONE)
                    {
                        SendTG(StringFormat("🔵 <b>PENDING ORDER CANCELED</b>\n\n"
                                            "📊 <b>Symbol:</b> %s\n"
                                            "⚡ <b>Reason:</b> Trend flipped on %s.",
                                            _Symbol, tfstr(relevant_TF)));
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Checks for a clean breakout candle followed by confirmation candles. |
//+------------------------------------------------------------------+
bool IsCleanBreakout(long tradeType, int numConfirmCandles, ENUM_TIMEFRAMES tf)
{
    // Total number of candles in our sequence (1 breakout + N confirmation)
    int sequenceLength = 1 + numConfirmCandles;
    
    // Ensure we have enough historical data to check the sequence
    if(Bars(_Symbol, tf) < sequenceLength + 5) return false;
    
    // --- Step 1: Identify the Breakout Candle and the line it broke ---
    int breakoutCandleIndex = sequenceLength; // e.g., bar[3] if numConfirmCandles = 2
    int barBeforeBreakoutIndex = breakoutCandleIndex + 1; // e.g., bar[4]
    
    // Get the SuperTrend value from the candle BEFORE the breakout
    double stLineToBreak = 0;
    int dirBeforeBreakout = 0;
    if(!CalcSuperTrend(tf, ST_ATR_Period, ST_ATR_Mult, barBeforeBreakoutIndex, stLineToBreak, dirBeforeBreakout))
    {
        return false; // Cannot calculate ST, cannot confirm
    }
    
    // Get the Open and Close of the breakout candle
    double breakoutOpen  = iOpen(_Symbol, tf, breakoutCandleIndex);
    double breakoutClose = iClose(_Symbol, tf, breakoutCandleIndex);
    
    // --- Step 2: Verify the breakout candle crossed the SuperTrend line ---
    bool breakoutCandleIsValid = false;
    if(tradeType == POSITION_TYPE_BUY)
    {
        // For a BUY, the trend before must be DOWN, and the candle must cross UP
        if(dirBeforeBreakout == -1 && breakoutOpen < stLineToBreak && breakoutClose > stLineToBreak)
        {
            breakoutCandleIsValid = true;
        }
    }
    else // POSITION_TYPE_SELL
    {
        // For a SELL, the trend before must be UP, and the candle must cross DOWN
        if(dirBeforeBreakout == +1 && breakoutOpen > stLineToBreak && breakoutClose < stLineToBreak)
        {
            breakoutCandleIsValid = true;
        }
    }
    
    if(!breakoutCandleIsValid) return false; // The first candle didn't perform a clean break.
    
    // --- Step 3: Verify all confirmation candles are in the correct direction ---
    for(int i = numConfirmCandles; i >= 1; i--)
    {
        int confirmCandleIndex = i; // e.g., bar[2], then bar[1]
        double confirmOpen  = iOpen(_Symbol, tf, confirmCandleIndex);
        double confirmClose = iClose(_Symbol, tf, confirmCandleIndex);
        
        if(tradeType == POSITION_TYPE_BUY)
        {
            if(confirmClose <= confirmOpen) return false; // Must be a bullish candle
        }
        else // POSITION_TYPE_SELL
        {
            if(confirmClose >= confirmOpen) return false; // Must be a bearish candle
        }
    }
    
    // If we passed all checks, it's a valid, clean breakout sequence
    return true;
}

// ---- Dynamic SL: pick SL at [min..max] ATRs from entry, and beyond swing by pad
bool PickSL_DynamicATR(bool isBuy,
                       double entry, double atr,
                       double swingHigh, double swingLow,
                       double minATR, double maxATR,
                       double padATR,
                       double &slOut)
{
    if(atr<=0.0) return false;
    double minDist = minATR*atr;
    double maxDist = maxATR*atr;
    
    // Start with swing-based SL (beyond swing with pad)
    double base = isBuy ? (swingLow  - padATR*atr)
    : (swingHigh + padATR*atr);
    
    // Ensure correct side and clamp into [min..max] ATRs from entry
    double d = MathAbs(entry - base);
    if(isBuy){
        if(base>=entry) base = entry - minDist;
        d = MathAbs(entry - base);
        if(d<minDist) base = entry - minDist;
        else if(d>maxDist) base = entry - maxDist;
    }else{
        if(base<=entry) base = entry + minDist;
        d = MathAbs(entry - base);
        if(d<minDist) base = entry + minDist;
        else if(d>maxDist) base = entry + maxDist;
    }
    
    slOut = base;
    return true;
}

// ---- Dynamic TP: choose R in [rrMin..rrMax] limited by ATR cap and swing "room"
bool PickRRTarget(bool isBuy,
                  double entry, double sl, double atr,
                  double lastHigh, double lastLow,
                  double rrMin, double rrMax,
                  double tpMaxATRs, double swingExtATRs,
                  double &chosenR, double &tpOut)
{
    if(atr<=0.0) return false;
    double risk = MathAbs(entry - sl);
    if(risk<=0.0) return false;
    
    // Cap A: ATR
    double rCapATR = (tpMaxATRs*atr) / risk;
    
    // Cap B: structure via last swing +/- extension
    double capPrice = isBuy ? (lastHigh + swingExtATRs*atr)
    : (lastLow  - swingExtATRs*atr);
    double room     = isBuy ? MathMax(0.0, capPrice - entry)
    : MathMax(0.0, entry - capPrice);
    double rCapSwing = (room>0.0) ? (room / risk) : 0.0;
    
    double rFeasible = (rCapSwing>0.0) ? MathMin(rCapATR, rCapSwing) : rCapATR;
    if(rFeasible<=0.0) return false;
    
    chosenR = MathMin(rrMax, rFeasible);
    if(chosenR < rrMin) return false; // caller will decide fallback
    
    tpOut = isBuy ? (entry + chosenR*risk) : (entry - chosenR*risk);
    return true;
}

//+------------------------------------------------------------------+
//| Checks for 3 consecutive closed candles moving in trade direction|
//+------------------------------------------------------------------+
// This function determines if the last three closed candles (bar 1, 2, and 3)
// confirm movement in the direction of the trade based on their closing prices.
// It uses the primary trading timeframe (TF_Trade).
bool CheckThreeCandleConfirmation(long type, ENUM_TIMEFRAMES tf)
{
    // Copy rates for the last 3 closed bars (shifts 1, 2, 3)
    // rates[0] = bar[1] (most recent closed bar)
    // rates[1] = bar[2]
    // rates[2] = bar[3] (oldest of the three)
    MqlRates rates[];
    if(CopyRates(_Symbol, tf, 1, 3, rates) != 3)
    {
        // Not enough history or data, cannot confirm
        return false;
    }
    
    if (type == POSITION_TYPE_BUY)
    {
        // BUY trade: requires 3 consecutive higher closes
        // Close[1] > Close[2] AND Close[2] > Close[3]
        if (rates[0].close > rates[1].close &&
            rates[1].close > rates[2].close)
        {
            return true;
        }
    }
    else if (type == POSITION_TYPE_SELL)
    {
        // SELL trade: requires 3 consecutive lower closes
        // Close[1] < Close[2] AND Close[2] < rates[2].close)
        if (rates[0].close < rates[1].close &&
            rates[1].close < rates[2].close)
        {
            return true;
        }
    }
    
    return false;
}

// Find last swing high/low on a TF (reuses your fractal logic)
bool GetLastSwingsTF(ENUM_TIMEFRAMES tf, int lookback, double &pHigh, double &pLow, int &barHigh, int &barLow)
{
    int hFr = iFractals(_Symbol, tf);
    if(hFr==INVALID_HANDLE) return false;
    double up[], dn[];
    ArraySetAsSeries(up,true); ArraySetAsSeries(dn,true);
    if(CopyBuffer(hFr,0,0,lookback,up)<=0 || CopyBuffer(hFr,1,0,lookback,dn)<=0){ IndicatorRelease(hFr); return false; }
    
    barHigh=-1; pHigh=0.0; barLow=-1; pLow=0.0;
    for(int i=2; i<lookback; ++i)
    {
        if(up[i]!=EMPTY_VALUE && barHigh==-1){ barHigh=i; pHigh=up[i]; }
        if(dn[i]!=EMPTY_VALUE && barLow==-1){ barLow=i; pLow=dn[i]; }
        if(barHigh!=-1 && barLow!=-1) break;
    }
    IndicatorRelease(hFr);
    return (barHigh!=-1 && barLow!=-1);
}

// Build a trendline from the last two pivots (bull: lows, bear: highs) on HTF.
// Returns price of that line at 'shift' (closed bar shift) via 'linePx'.
bool TrendlineAt(ENUM_TIMEFRAMES tf, int lookback, bool bull, int shift, double &linePx)
{
    int hFr = iFractals(_Symbol, tf);
    if(hFr==INVALID_HANDLE) return false;
    double up[], dn[];
    ArraySetAsSeries(up,true); ArraySetAsSeries(dn,true);
    if(CopyBuffer(hFr,0,0,lookback,up)<=0 || CopyBuffer(hFr,1,0,lookback,dn)<=0){ IndicatorRelease(hFr); return false; }
    
    // collect two most recent pivots of the required side
    int i1=-1,i2=-1; double p1=0.0,p2=0.0;
    for(int i=2; i<lookback; ++i)
    {
        double v = bull ? dn[i] : up[i];
        if(v!=EMPTY_VALUE){
            if(i1==-1){ i1=i; p1=v; }
            else { i2=i; p2=v; break; }
        }
    }
    IndicatorRelease(hFr);
    if(i1==-1 || i2==-1 || i1==i2) return false;
    
    // line through (i1,p1) and (i2,p2) in "bars as x"
    double slope = (p2 - p1) / (double)(i2 - i1);
    linePx = p1 + slope * (double)(shift - i1);
    return true;
}

// Test for "strong" HTF breakout within last N bars.
// dirOut: +1 bull, -1 bear. ageOut: bars since breakout (1..N). Returns true if found.
bool IsStrongBreakoutHTF(ENUM_TIMEFRAMES tf, int lookback, int atrPeriod,
                         double atrMargin, int modeAND_1_else_OR_0, int maxAgeBars,
                         int &dirOut, int &ageOut)
{
    dirOut=0; ageOut=0;
    
    // ATR on HTF
    int hATR = iATR(_Symbol, tf, atrPeriod);
    if(hATR==INVALID_HANDLE) return false;
    double a[]; ArraySetAsSeries(a,true);
    if(CopyBuffer(hATR,0,0,maxAgeBars+3,a) <= maxAgeBars){ IndicatorRelease(hATR); return false; }
    
    // Swings (S/R)
    double pH=0.0, pL=0.0; int bH=-1,bL=-1;
    if(!GetLastSwingsTF(tf, lookback, pH, pL, bH, bL)){ IndicatorRelease(hATR); return false; }
    
    // Scan the last N closed bars
    for(int s=1; s<=maxAgeBars; ++s)
    {
        double c = iClose(_Symbol, tf, s);
        double atr = a[s];
        
        bool srBuy  = (c >= pH + atrMargin*atr);
        bool srSell = (c <= pL - atrMargin*atr);
        
        double tlBull=0.0, tlBear=0.0;
        bool tlB = TrendlineAt(tf, lookback, true,  s, tlBull);
        bool tlS = TrendlineAt(tf, lookback, false, s, tlBear);
        
        bool tlBuy  = tlB && (c >= tlBull + atrMargin*atr);
        bool tlSell = tlS && (c <= tlBear - atrMargin*atr);
        
        bool buyOK  = (modeAND_1_else_OR_0==1) ? (srBuy  && tlBuy)  : (srBuy  || tlBuy);
        bool sellOK = (modeAND_1_else_OR_0==1) ? (srSell && tlSell) : (srSell || tlSell);
        
        if(buyOK){ dirOut=+1; ageOut=s; IndicatorRelease(hATR); return true; }
        if(sellOK){ dirOut=-1; ageOut=s; IndicatorRelease(hATR); return true; }
    }
    IndicatorRelease(hATR);
    return false;
}

// --- MIN distance (stop+freeze) in points
int  MinStopPoints() {
    int stop   = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    int freeze = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    return MathMax(stop, freeze);
}

// Get Alligator lines at a shift (if you ever want scalp "retrace-to-jaw" gating later)
bool GetAlligatorLines(ENUM_TIMEFRAMES tf, int shift, double &jawOut, double &teethOut, double &lipsOut)
{
    int h=iAlligator(_Symbol, tf, Jaw_Period, Jaw_Shift, Teeth_Period, Teeth_Shift, Lips_Period, Lips_Shift, MODE_SMMA, PRICE_MEDIAN);
    if(h==INVALID_HANDLE) return false;
    double jaw[], teeth[], lips[]; ArraySetAsSeries(jaw,true); ArraySetAsSeries(teeth,true); ArraySetAsSeries(lips,true);
    bool ok=true;
    if(CopyBuffer(h,0,0,shift+2,jaw)<=shift)   ok=false;
    if(CopyBuffer(h,1,0,shift+2,teeth)<=shift) ok=false;
    if(CopyBuffer(h,2,0,shift+2,lips)<=shift)  ok=false;
    IndicatorRelease(h);
    if(!ok) return false;
    jawOut=jaw[shift]; teethOut=teeth[shift]; lipsOut=lips[shift];
    return true;
}

// Alligator state:  +1 bull, -1 bear, 0 neutral
int AlligatorState(ENUM_TIMEFRAMES tf, int shift=1)
{
    int h = iAlligator(_Symbol, tf, Jaw_Period, Jaw_Shift, Teeth_Period, Teeth_Shift, Lips_Period, Lips_Shift, MODE_SMMA, PRICE_MEDIAN);
    if(h==INVALID_HANDLE) return 0;
    
    double jaw[], teeth[], lips[];
    ArraySetAsSeries(jaw,true);  ArraySetAsSeries(teeth,true);  ArraySetAsSeries(lips,true);
    if(CopyBuffer(h,0,0,shift+5,jaw)<=shift)  { IndicatorRelease(h); return 0; }
    if(CopyBuffer(h,1,0,shift+5,teeth)<=shift){ IndicatorRelease(h); return 0; }
    if(CopyBuffer(h,2,0,shift+5,lips)<=shift) { IndicatorRelease(h); return 0; }
    
    double c = iClose(_Symbol,tf,shift);
    int state = 0;
    if(lips[shift] > teeth[shift] && teeth[shift] > jaw[shift] && c > jaw[shift]) state = +1;
    else if(lips[shift] < teeth[shift] && teeth[shift] < jaw[shift] && c < jaw[shift]) state = -1;
    
    IndicatorRelease(h);
    return state;
}

// AO value
double AOValue(ENUM_TIMEFRAMES tf, int shift=1)
{
    int h = iAO(_Symbol, tf);
    if(h==INVALID_HANDLE) return 0.0;
    double ao[];
    ArraySetAsSeries(ao,true);
    if(CopyBuffer(h,0,0,shift+3,ao)<=shift){ IndicatorRelease(h); return 0.0; }
    double v = ao[shift];
    IndicatorRelease(h);
    return v;
}

// WPR value ([-100..0]) -> e.g. -20, -50, -80
double WPRValue(ENUM_TIMEFRAMES tf, int shift=1)
{
    int h = iWPR(_Symbol, tf, 14);
    if(h==INVALID_HANDLE) return -50.0;
    double w[];
    ArraySetAsSeries(w,true);
    if(CopyBuffer(h,0,0,shift+3,w)<=shift){ IndicatorRelease(h); return -50.0; }
    double v = w[shift];
    IndicatorRelease(h);
    return v;
}

// SuperTrend calc (dir: +1 up, -1 down). Returns line at 'shift'.
bool CalcSuperTrend(ENUM_TIMEFRAMES tf, int atrPeriod, double mult, int shift, double &stLine, int &dir)
{
    const int want= atrPeriod + 200;
    MqlRates rates[];
    ArraySetAsSeries(rates,true);
    int got = CopyRates(_Symbol, tf, 0, want, rates);
    if(got < atrPeriod+5) return false;
    
    int hATR = iATR(_Symbol, tf, atrPeriod);
    if(hATR==INVALID_HANDLE) return false;
    double atr[];
    ArraySetAsSeries(atr,true);
    if(CopyBuffer(hATR,0,0,got,atr)<=0){ IndicatorRelease(hATR); return false; }
    
    // Work arrays
    static double upper[], lower[], fUp[], fDn[];
    static int    trend[];
    ArrayResize(upper,got); ArrayResize(lower,got);
    ArrayResize(fUp,got);   ArrayResize(fDn,got);
    ArrayResize(trend,got);
    
    // initialize from oldest to newest using series indexing
    // series: index got-1 = oldest, 0 = newest
    for(int idx=got-1; idx>=0; --idx)
    {
        double median = (rates[idx].high + rates[idx].low)*0.5;
        upper[idx] = median + mult * atr[idx];
        lower[idx] = median - mult * atr[idx];
        
        if(idx==got-1)
        {
            fUp[idx] = upper[idx];
            fDn[idx] = lower[idx];
            trend[idx] = +1;
            continue;
        }
        
        // provisional
        fUp[idx] = MathMin(upper[idx], fUp[idx+1]);
        fDn[idx] = MathMax(lower[idx], fDn[idx+1]);
        
        int curTrend = trend[idx+1];
        // flip rules vs previous final bands
        double prevUp = fUp[idx+1];
        double prevDn = fDn[idx+1];
        
        if(rates[idx].close > prevUp) curTrend = +1;
        else if(rates[idx].close < prevDn) curTrend = -1;
        
        // lock bands per trend
        if(curTrend==+1) fUp[idx] = upper[idx];     // in uptrend we use lower band as line, keep upper reset
        else             fDn[idx] = lower[idx];     // in downtrend we use upper band as line, keep lower reset
        
        trend[idx] = curTrend;
    }
    
    dir = trend[shift];
    stLine = (dir>0) ? fDn[shift] : fUp[shift];
    
    IndicatorRelease(hATR);
    return true;
}

bool GetSwingsATR(ENUM_TIMEFRAMES tf, int lookback, int atrPeriod,
                  double &pHigh, double &pLow, double &atrOut)
{
    // --- WARNINGS FIXED: Removed unused bH and bL variables ---
    int barHigh, barLow;
    double ph, pl;
    if(!RecentSwings(tf, lookback, barHigh, ph, barLow, pl)) return false;
    
    int hATR = iATR(_Symbol, tf, atrPeriod);
    if(hATR==INVALID_HANDLE) return false;
    double a[]; ArraySetAsSeries(a,true);
    if(CopyBuffer(hATR,0,0,3,a)<2){ IndicatorRelease(hATR); return false; }
    atrOut = a[1];
    IndicatorRelease(hATR);
    
    pHigh = ph;
    pLow  = pl;
    return true;
}

bool BuildSLTP_FromSwings(bool isBuy, double entry, double pHigh, double pLow, double atr,
                          bool useFib, double rr, double &sl, double &tp)
{
    if(isBuy)
    {
        sl = pLow - ATR_SL_Buffer_Mult * atr;
        if(useFib){
            double leg = MathAbs(pHigh - pLow);
            tp = pHigh + 1.618 * leg; // Corrected Fib Extension (2.618 -> 1.618)
        }else{
            double riskPts = (entry - sl)/_Point;
            if(riskPts<=0) return false;
            tp = entry + rr * riskPts * _Point;
        }
    }
    else
    {
        sl = pHigh + ATR_SL_Buffer_Mult * atr;
        if(useFib){
            double leg = MathAbs(pHigh - pLow);
            tp = pLow - 1.618 * leg; // Corrected Fib Extension (2.618 -> 1.618)
        }else{
            double riskPts = (sl - entry)/_Point;
            if(riskPts<=0) return false;
            tp = entry - rr * riskPts * _Point;
        }
    }
    return (sl>0 && tp>0);
}

// Find recent swing high/low using fractals
bool RecentSwings(ENUM_TIMEFRAMES tf, int lookback, int &barHigh, double &priceHigh, int &barLow, double &priceLow)
{
    int hFr = iFractals(_Symbol, tf);
    if(hFr==INVALID_HANDLE) return false;
    
    double up[], dn[];
    ArraySetAsSeries(up,true); ArraySetAsSeries(dn,true);
    if(CopyBuffer(hFr,0,0,lookback,up)<=0 || CopyBuffer(hFr,1,0,lookback,dn)<=0){ IndicatorRelease(hFr); return false; }
    
    barHigh=-1; priceHigh=0; barLow=-1; priceLow=0;
    for(int i=2; i<lookback; ++i)
    {
        if(up[i]!=EMPTY_VALUE && barHigh==-1){ barHigh=i; priceHigh=up[i]; }
        if(dn[i]!=EMPTY_VALUE && barLow==-1){ barLow=i; priceLow=dn[i]; }
        if(barHigh!=-1 && barLow!=-1) break;
    }
    IndicatorRelease(hFr);
    return (barHigh!=-1 && barLow!=-1);
}

//============================== Position/Risk Management Utilities (Called by Core Logic) =========================

// NEW FUNCTION: Closes all positions on the current symbol in an emergency
void EmergencyCloseAllPositions(const string reason)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                Trade.PositionClose(ticket, 10);
            }
        }
    }
    
    string alertMsg = StringFormat(
                                   "🚨 <b>CIRCUIT BREAKER TRIPPED</b> 🚨\n\n"
                                   "📊 <b>Symbol:</b> %s\n"
                                   "⚡ <b>Reason:</b> %s\n\n"
                                   "<i>All positions have been closed to prevent further loss.</i>",
                                   _Symbol, reason
                                   );
    SendTG(alertMsg);
}
// NEW FUNCTION: Syncs all open stops to the latest SL, but only if it's an improvement
void SyncAllStopsSafely(double latestSL)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if((string)PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        long   type    = PositionGetInteger(POSITION_TYPE);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        double modSL = currentSL;
        
        // Only adjust if the new SL is better than the current one
        if(type == POSITION_TYPE_BUY && latestSL > currentSL)
        {
            modSL = latestSL;
        }
        else if(type == POSITION_TYPE_SELL && latestSL < currentSL)
        {
            modSL = latestSL;
        }
        
        // If a change is needed, modify the position
        if(modSL != currentSL)
        {
            Trade.PositionModify(ticket, modSL, currentTP);
        }
    }
}


void TouchUpManualInitial()
{
    if(!ApplyToManualTrades || !Manual_Set_Initial_SLTP) return;
    
    int total = PositionsTotal();
    for(int i=0;i<total;i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        
        string sym = (string)PositionGetString(POSITION_SYMBOL);
        if(sym != _Symbol) continue;
        
        long magic = PositionGetInteger(POSITION_MAGIC);
        if(magic != 0) continue; // manual trades are magic=0
        
        long   type  = PositionGetInteger(POSITION_TYPE);
        double entry = PositionGetDouble(POSITION_PRICE_OPEN);
        double sl    = PositionGetDouble(POSITION_SL);
        double tp    = PositionGetDouble(POSITION_TP);
        
        bool needSL = (sl<=0.0);
        bool needTP = (tp<=0.0);
        if(!needSL && !needTP) continue;
        
        double pH,pL,atr;
        if(!GetSwingsATR(TF_Trade, 300, ST_ATR_Period, pH, pL, atr)) continue;
        
        double newSL = sl, newTP = tp;
        bool isBuy   = (type==POSITION_TYPE_BUY);
        
        if(needSL || needTP)
        {
            double tmpSL, tmpTP;
            if(!BuildSLTP_FromSwings(isBuy, entry, pH, pL, atr,
                                     Manual_Use_Fib_Targets, Manual_RR_Min, tmpSL, tmpTP))
                continue;
            
            if(needSL) newSL = tmpSL;
            if(needTP) newTP = tmpTP;
            
            if(PositionSelect(sym)) // ensure current pos context
            {
                long ptype = PositionGetInteger(POSITION_TYPE);
                
                // guard invalid math
                if(!MathIsValidNumber(newSL)) newSL = 0.0;
                if(!MathIsValidNumber(newTP)) newTP = 0.0;
                
                double modSL = newSL;
                double modTP = newTP;
                SanitizeStops(ptype, modSL, modTP);
                
                // skip if both unset or effectively unchanged
                double curSL = PositionGetDouble(POSITION_SL);
                double curTP = PositionGetDouble(POSITION_TP);
                bool changed = ( (modSL>0 && MathAbs(modSL-curSL) >= 0.5*_Point) ||
                                (modTP>0 && MathAbs(modTP-curTP) >= 0.5*_Point) );
                
                Trade.PositionModify(_Symbol, modSL, modTP);
                if (Trade.ResultRetcode() == TRADE_RETCODE_DONE)
                {
                    SendTG(StringFormat("🔧 Manual %s on %s: set %s%s\nSL: %.2f  TP: %.2f",
                                        isBuy?"BUY":"SELL", _Symbol,
                                        needSL?"SL ":"", needTP?"TP":"", modSL, modTP));
                }
            }
        }
    }
}

// Apply one SL/TP to ALL open (EA+manual) trades in that direction
void ApplySLTPToAllOpen(int dir, double newSL, double newTP)
{
    for(int i=0;i<PositionsTotal();++i){
        ulong tk=PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;
        if((string)PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
        long typ=PositionGetInteger(POSITION_TYPE);
        int d=(typ==POSITION_TYPE_BUY)?+1:-1;
        if(d!=dir) continue;
        
        string pcomment = (string)PositionGetString(POSITION_COMMENT);
        if(Adjust_All_Exclude_Scalps && StringFind(pcomment, "Scalp", 0) >= 0) continue;
        
        double curSL=PositionGetDouble(POSITION_SL);
        double curTP=PositionGetDouble(POSITION_TP);
        double modSL=newSL, modTP=newTP;
        SanitizeStops(typ, modSL, modTP);
        
        bool changed=( (modSL>0 && MathAbs(modSL-curSL)>=0.5*_Point) ||
                      (modTP>0 && MathAbs(modTP-curTP)>=0.5*_Point) );
        if(changed) Trade.PositionModify(_Symbol, modSL, modTP);
    }
}

// --- NEW HELPER: Closes open TREND positions (Magic) on the current symbol ---
void CloseOpenTrendPositions(long currentTradeType)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if((string)PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        long magic = PositionGetInteger(POSITION_MAGIC);
        long posType = PositionGetInteger(POSITION_TYPE);

        // Check if it's a TREND trade (main magic) and OPPOSITE to the upcoming reversal
        if(magic == Magic && posType != currentTradeType)
        {
            Trade.PositionClose(ticket, 10);
            if (Trade.ResultRetcode() == TRADE_RETCODE_DONE)
            {
                string posDir = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
                SendTG(StringFormat("⚠️ Closed Trend %s Trade (Magic %d) in anticipation of Scalp Reversal.", posDir, Magic));
            }
        }
    }
}
// --- END NEW HELPER ---

// Latest open position (EA or manual) in given direction (+1 buy, -1 sell)
bool GetLatestOpenPos(int dir, bool includeManual, ulong &ticketOut, double &entryOut, double &slOut)
{
    datetime newest=0; bool found=false;
    for(int i=0;i<PositionsTotal();++i){
        ulong tk=PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;
        if((string)PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
        long typ=PositionGetInteger(POSITION_TYPE);
        int d=(typ==POSITION_TYPE_BUY)?+1:-1;
        if(d!=dir) continue;
        long mg=PositionGetInteger(POSITION_MAGIC);
        if(!(mg==Magic || mg==Magic_Reversal || (includeManual && mg==0))) continue;
        datetime t=(datetime)PositionGetInteger(POSITION_TIME);
        if(t>newest){ newest=t; found=true; ticketOut=tk;
            entryOut=PositionGetDouble(POSITION_PRICE_OPEN);
            slOut   =PositionGetDouble(POSITION_SL);
        }
    }
    return found;
}

// Has price reached a % of the way from entry to SL (toward SL)?
bool ReachedRatioToSL(int dir, double entry, double sl, double ratio)
{
    if(sl<=0.0) return false;
    double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
    double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
    double cur=(dir>0)?bid:ask;
    if(dir>0){ double risk=entry-sl; if(risk<=0) return false; return (entry-cur)>=ratio*risk; }
    else     { double risk=sl-entry; if(risk<=0) return false; return (cur-entry)>=ratio*risk; }
}

// --- Make SL/TP finite, correct side of price, and beyond min distance
void SanitizeStops(long posType, double &sl, double &tp)
{
    // remove NaN/INF/EMPTY_VALUE
    if(!MathIsValidNumber(sl) || sl==EMPTY_VALUE) sl = 0.0;
    if(!MathIsValidNumber(tp) || tp==EMPTY_VALUE) tp = 0.0;
    
    const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    const double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    const double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    const double mind   = (double)MinStopPoints() * _Point;
    
    if(posType==POSITION_TYPE_BUY)
    {
        if(sl>0 && sl >= bid - mind) sl = bid - mind;
        if(tp>0 && tp <= ask + mind) tp = ask + mind;
        if(sl >= bid) sl = 0.0;       // fail-safe
        if(tp <= ask) tp = 0.0;
    }
    else // SELL
    {
        if(sl>0 && sl <= ask + mind) sl = ask + mind;
        if(tp>0 && tp >= bid - mind) tp = bid - mind;
        if(sl <= ask) sl = 0.0;
        if(tp >= bid) tp = 0.0;
    }
    
    if(sl>0) sl = NormalizeDouble(sl, digits);
    if(tp>0) tp = NormalizeDouble(tp, digits);
}

double NormalizeVolume(double v){
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    if(step<=0) step=0.01;
    v = MathFloor(v/step)*step;
    if(v<minv) v=minv;
    if(v>maxv) v=maxv;
    return v;
}

// ==== ADD PARTIAL CLOSE FUNCTIONS RIGHT HERE ====

// Add this helper function to check if a ticket is in the partial closed array
bool IsTicketPartiallyClosed(ulong ticket)
{
    for(int i = 0; i < ArraySize(g_partialClosedTickets); i++)
    {
        if(g_partialClosedTickets[i] == ticket)
            return true;
    }
    return false;
}

// Add this helper function to add a ticket to the partial closed array
void AddToPartialClosed(ulong ticket)
{
    int size = ArraySize(g_partialClosedTickets);
    ArrayResize(g_partialClosedTickets, size + 1);
    g_partialClosedTickets[size] = ticket;
}

// Add this function to handle partial closing
void CheckPartialClose(ulong ticket, long type, double entry, double sl, double tp, double volume, string comment)
{
    if(!Use_Partial_Close) return;
    if(IsTicketPartiallyClosed(ticket)) return;
    
    double currentPrice = (type == POSITION_TYPE_BUY) ?
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double progress = 0.0;
    if(type == POSITION_TYPE_BUY)
    {
        if(tp > entry && currentPrice > entry)
        {
            progress = (currentPrice - entry) / (tp - entry) * 100.0;
        }
    }
    else // SELL
    {
        if(tp < entry && currentPrice < entry)
        {
            progress = (entry - currentPrice) / (entry - tp) * 100.0;
        }
    }
    
    if(progress >= Partial_Close_TP_Percent)
    {
        double closeVolume = volume * (Partial_Close_Volume_Percent / 100.0);
        closeVolume = NormalizeVolume(closeVolume);
        
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        if(closeVolume >= minVolume && closeVolume < volume)
        {
            Trade.PositionClosePartial(ticket, closeVolume);
            if (Trade.ResultRetcode() == TRADE_RETCODE_DONE)
            {
                AddToPartialClosed(ticket);
                
                string msg = StringFormat(
                    "💰 <b>PARTIAL CLOSE EXECUTED</b>\n\n"
                    "📊 <b>Symbol:</b> %s\n"
                    "🔢 <b>Ticket:</b> %I64u\n"
                    "📈 <b>Type:</b> %s\n"
                    "⚡ <b>Progress to TP:</b> %.1f%%\n"
                    "📦 <b>Volume Closed:</b> %.2f lots (%.1f%%)\n"
                    "🎯 <b>Remaining Volume:</b> %.2f lots\n"
                    "💬 <b>Comment:</b> %s",
                    _Symbol,
                    ticket,
                    (type == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                    progress,
                    closeVolume,
                    Partial_Close_Volume_Percent,
                    volume - closeVolume,
                    comment
                );
                SendTG(msg);
            }
        }
    }
}

// ==== CONTINUE WITH EXISTING CODE ====


// Compute lot size by risk percent and SL points (simplified, Deriv synthetics)
double LotsByRisk(double riskPct, double slPoints)
{
    if(riskPct<=0.0 || slPoints<=0.0) return Fixed_Lots;
    double bal = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskMoney = bal * (riskPct/100.0);
    // Approx: tick value per point
    double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tp = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tp<=0 || tv<=0) return Fixed_Lots;
    double valuePerPointPerLot = tv / tp; // money per point per 1 lot
    double lots = riskMoney / (slPoints * valuePerPointPerLot);
    // Clamp by volume limits
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    lots = MathMax(minv, MathMin(maxv, MathFloor(lots/step)*step));
    if(lots<=0) lots = minv;
    return lots;
}

// Count open positions by this EA for current symbol
int CountOpen()
{
    int total = PositionsTotal();
    int cnt=0;
    for(int p=0; p<total; ++p)
    {
        ulong ticket = PositionGetTicket(p);
        if(PositionSelectByTicket(ticket))
        {
            if((PositionGetInteger(POSITION_MAGIC)==Magic || PositionGetInteger(POSITION_MAGIC)==Magic_Reversal) && (string)PositionGetString(POSITION_SYMBOL)==_Symbol)
                cnt++;
        }
    }
    return cnt;
}

// Count open positions by comment substring (same Magic & Symbol)
int CountOpenByCommentSubstr(const string key)
{
    int cnt=0;
    for(int i=0;i<PositionsTotal();++i){
        ulong tk=PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;
        if((string)PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
        if((long)PositionGetInteger(POSITION_MAGIC)!=Magic && (long)PositionGetInteger(POSITION_MAGIC)!=Magic_Reversal) continue;
        string cmt=(string)PositionGetString(POSITION_COMMENT);
        if(StringFind(cmt,key,0)>=0) cnt++;
    }
    return cnt;
}

// Count pending orders from this EA for this symbol
int CountPendingThisEA()
{
    int c=0;
    for(int i=0;i<OrdersTotal();++i)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket==0) continue;
        if(!OrderSelect(ticket)) continue;
        
        if((string)OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        if((long)OrderGetInteger(ORDER_MAGIC) != Magic && (long)OrderGetInteger(ORDER_MAGIC) != Magic_Reversal) continue;
        
        long t = (long)OrderGetInteger(ORDER_TYPE);
        if(t==ORDER_TYPE_BUY_STOP || t==ORDER_TYPE_SELL_STOP) c++;
    }
    return c;
}

//============================== Indicator & Price Analysis Helpers =========================




//============================== Entry Logic =========================

// ====================== SCALP ENTRIES ======================

// ====================== FINAL CORRECTED TryScalpEntries() FUNCTION ======================
void TryScalpEntries()
{
    if(!Use_Scalp_Mode) return;
    // --- NEW: TIME FILTER CHECK ---
    if (!IsTradeTime()) { return; }
    // --- END TIME FILTER ---
    if(Scalp_Only_When_No_Main && CountOpen()>0) return;
    if(CountOpenByCommentSubstr("V25 Scalp") >= Scalp_Max_Concurrent) return;

    // --- NEW: Check Momentum Cooldown Status ---
    bool isCooldownActive = false;
    int  currentEntryMode = Entry_Mode;
    if (g_momentumCooldownActive) {
        datetime barTime = iTime(_Symbol, TF_Scalp, 0);
        long barsPassed = (barTime - g_cooldownStartTime) / PeriodSeconds(TF_Scalp);
        if (barsPassed >= Cooldown_Momentum_Bars) { g_momentumCooldownActive = false; }
        else { isCooldownActive = true; currentEntryMode = 1; }
    }
    // --- End of New Block ---
    
    // --- NEW: DYNAMIC SPREAD FILTER ---
        if (Use_Dynamic_Spread_Filter && Avg_Spread_Lookback_Bars > 0 && Spread_Filter_Multiplier > 0)
        {
            double avgSpread = GetAverageSpreadBars(TF_Scalp, Avg_Spread_Lookback_Bars);
            if (avgSpread > 0) // Only filter if average spread calculation is valid
            {
                double currentSpreadPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD); // Explicitly cast integer to double
                if (currentSpreadPoints > (avgSpread * Spread_Filter_Multiplier))
                {
                    // Optional: Print notification
                    // PrintFormat("Scalp entry blocked by dynamic spread: %.1f points (Avg: %.1f, Max Allowed: %.1f)",
                    //             currentSpreadPoints, avgSpread, avgSpread * Spread_Filter_Multiplier);
                    return; // Spread is too wide, block scalp entry
                }
            }
        }
        // --- END DYNAMIC SPREAD FILTER ---
    // --- NEW: VOLATILITY ENTRY FILTER ---
    if(Use_Volatility_Entry_Filter) {
        double atr = 0; int hATR = iATR(_Symbol, TF_Scalp, ST_ATR_Period); // Use TF_Scalp here
        if(hATR != INVALID_HANDLE){ double a[]; if(CopyBuffer(hATR, 0, 1, 1, a) > 0) atr = a[0]; IndicatorRelease(hATR); }
        double lastCandleSize = iHigh(_Symbol, TF_Scalp, 1) - iLow(_Symbol, TF_Scalp, 1); // Use TF_Scalp here
        if(atr > 0 && lastCandleSize > (atr * CircuitBreaker_ATR_Mult)) { return; }
    }
    // --- END NEW FILTER ---

    // --- Magic Number Logic (Initialize) ---
    long magicToUse = Magic;         // Default to main trend magic
    string commentSuffix = "";       // Default suffix
    bool isScalpReversalConditionMet = false; // Flag for special WPR condition

    // --- Get Core Indicator Data for Scalp ---
    double stLineScalp=0; int dirScalp=0;
    if(!CalcSuperTrend(TF_Scalp, ST_ATR_Period, ST_ATR_Mult, 1, stLineScalp, dirScalp)) return;
    int ag = AlligatorState(TF_Scalp,1);
    double ao = AOValue(TF_Scalp,1);
    double mom = MomentumValue(TF_Scalp,1);
    double c  = iClose(_Symbol, TF_Scalp, 1);
    double mainSTLine_ignored=0; int mainSTDir=0; // For breakout check later
    if(!CalcSuperTrend(TF_Trade, ST_ATR_Period, ST_ATR_Mult, 1, mainSTLine_ignored, mainSTDir)) return;
    // Recalculate isTrendFlip based on mainSTDir and prevDir_ST from the main strategy context
    bool isTrendFlip = (mainSTDir != 0 && mainSTDir != prevDir_ST); // Use global prevDir_ST

    // ======================= STEP 1: GENERATE ENTRY SIGNALS based on Entry_Mode =======================
    bool buySignal = false;
    bool sellSignal = false;

    // --- Priority 1: Check for Trend signals ---
    if(currentEntryMode == 0 || currentEntryMode == 2) // Trend-Following allowed
    {
        if (dirScalp > 0 && c > stLineScalp) buySignal = true;
        if (dirScalp < 0 && c < stLineScalp) sellSignal = true;
    }

    // --- Priority 2: Check for Reversal signals IF no trend signal was found OR if mode allows both ---
    if(currentEntryMode == 1 || currentEntryMode == 2) // Reversal (Divergence) allowed
    {
        bool foundBuyDivergence = CheckDivergenceForEntry(POSITION_TYPE_BUY, Divergence_Lookback_Bars, TF_Scalp);
        bool foundSellDivergence = CheckDivergenceForEntry(POSITION_TYPE_SELL, Divergence_Lookback_Bars, TF_Scalp);

        // --- Check WPR conditions ONLY if divergence found, for SPECIAL handling ---
                double wprH1   = WPRValue(TF_Scalp_Gate_HTF, 1); // Get H1 WPR (Scalp's HTF)
                double wprM15  = WPRValue(TF_Scalp, 1);          // Get M15 WPR (Scalp's own TF)

                // Conditions based on NEW logic: M15 extreme, H1 normal
                bool m15Overbought = (wprM15 > WPR_Overbought_Level);
                bool m15Oversold   = (wprM15 < WPR_Oversold_Level);
                bool h1Normal      = (wprH1 <= WPR_Overbought_Level && wprH1 >= WPR_Oversold_Level);

        // Evaluate BUY Reversal
        if (foundBuyDivergence && !buySignal)
        {
            buySignal = true; // Divergence buy signal exists
            // Check SPECIAL Scalp Reversal WPR condition (H1 Oversold, H4 Normal)
            if (m15Oversold && h1Normal)
            {
                magicToUse = Magic_Reversal;
                commentSuffix = " Scalp Reversal";
                isScalpReversalConditionMet = true; // Mark for filter bypass & closing trades
                CloseOpenTrendPositions(POSITION_TYPE_BUY); // Close opposing SELL trend trades
            }
            // If not special, it's a standard reversal (Mode 1 only)
            else if (currentEntryMode == 1) {
                // magicToUse = Magic_Reversal; // Could assign standard reversal magic here if needed
                // commentSuffix = " Reversal";
            }
        }

        // Evaluate SELL Reversal
        if (foundSellDivergence && !sellSignal)
        {
            sellSignal = true; // Divergence sell signal exists
            // Check SPECIAL Scalp Reversal WPR condition (H1 Overbought, H4 Normal)
            if (m15Overbought && h1Normal)
            {
                magicToUse = Magic_Reversal;
                commentSuffix = " Scalp Reversal";
                isScalpReversalConditionMet = true; // Mark for filter bypass & closing trades
                CloseOpenTrendPositions(POSITION_TYPE_SELL); // Close opposing BUY trend trades
            }
             // If not special, it's a standard reversal (Mode 1 only)
             else if (currentEntryMode == 1) {
                 // magicToUse = Magic_Reversal;
                 // commentSuffix = " Reversal";
            }
        }
    }

    // ======================= STEP 2: APPLY CONFIRMATION FILTERS =======================
    bool aoBuyOK  = (ao > 0.0 && MathAbs(ao) >= AO_Scalp_Min_Strength);
    bool aoSellOK = (ao < 0.0 && MathAbs(ao) >= AO_Scalp_Min_Strength);
    bool momBuyOK  = !Use_Momentum_Filter || (mom > 100.0 && (mom - 100.0) >= Mom_Scalp_Min_Strength);
    bool momSellOK = !Use_Momentum_Filter || (mom < 100.0 && (100.0 - mom) >= Mom_Scalp_Min_Strength);
    bool buyCond  = buySignal && (ag > 0 && aoBuyOK && momBuyOK);
    bool sellCond = sellSignal && (ag < 0 && aoSellOK && momSellOK);

    // --- Breakout Confirmation (applied only to trend signals after a flip) ---
    // Note: Uses isTrendFlip determined from the main TF context (global prevDir_ST)
    if(Use_Breakout_Confirmation && isTrendFlip && !g_breakoutConfirmed) {
        if (buyCond && magicToUse == Magic) { if(!IsCleanBreakout(POSITION_TYPE_BUY, Required_Confirmation_Candles, TF_Scalp)) buyCond = false; else g_breakoutConfirmed = true; }
        if (sellCond && magicToUse == Magic) { if(!IsCleanBreakout(POSITION_TYPE_SELL, Required_Confirmation_Candles, TF_Scalp)) sellCond = false; else g_breakoutConfirmed = true; }
    }

    // ======================= STEP 3: APPLY DIRECTIONAL FILTER =======================
    if(Directional_Filter_Mode == 0 && Use_HTF_Filter) {
        // --- Only apply standard filter if it's NOT our special Scalp Reversal ---
        if (!isScalpReversalConditionMet) {
            bool finalFilterOK = false;
            bool trendAlignOK = false; // Check H4 Alignment
            double htf_st_line_ignored; int htf_st_dir = 0;
            if(CalcSuperTrend(TF_HTF_Breakout, ST_ATR_Period, ST_ATR_Mult, 1, htf_st_line_ignored, htf_st_dir)) {
                if(buyCond && htf_st_dir > 0) trendAlignOK = true;
                if(sellCond && htf_st_dir < 0) trendAlignOK = true;
            }
            bool breakoutOK = false; // Check H1 Breakout Alignment
            int htfDir = 0, htfAge = 0;
            if(IsStrongBreakoutHTF(TF_Scalp_Gate_HTF, HTF_Breakout_Lookback, Scalp_ATR_Period, Scalp_Gate_ATR_Margin, 0, HTF_Breakout_MaxAgeBars, htfDir, htfAge)) {
                if(buyCond && htfDir > 0) breakoutOK = true;
                if(sellCond && htfDir < 0) breakoutOK = true;
            }
            // Apply filter based on mode
            switch(HTF_Filter_Mode) {
                case 0: finalFilterOK = trendAlignOK; break;
                case 1: finalFilterOK = breakoutOK; break;
                case 2: finalFilterOK = trendAlignOK && breakoutOK; break; // Default AND
            }
            if(!finalFilterOK) { buyCond = false; sellCond = false; }
        } // End conditional filter
    } else if (Directional_Filter_Mode == 1) { // Apply Scalp HTF Divergence Filter
        int htfDivergenceBias = GetHTFDivergenceDirection(TF_Scalp_HTF_Divergence, Divergence_Lookback_Bars);
        if (htfDivergenceBias > 0) sellCond = false;
        if (htfDivergenceBias < 0) buyCond = false;
    }

    // --- Final Check ---
    if (!buyCond && !sellCond) return;

    // =========================== BUILD SL / TP & EXECUTE ============================
    // ---- ATR on scalp TF
    int hATR = iATR(_Symbol, TF_Scalp, Scalp_ATR_Period);
    double atr=0.0;
    if(hATR!=INVALID_HANDLE){ double a[]; ArraySetAsSeries(a,true); if(CopyBuffer(hATR,0,0,3,a)>=2) atr=a[1]; IndicatorRelease(hATR); }
    if(atr<=0) return;
    double ask  = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
    double bid  = SymbolInfoDouble(_Symbol,SYMBOL_BID);
    bool buy = buyCond;
    double entry= buy? ask : bid;
    int bH,bL; double pHs,pLs;
    if(!RecentSwings(TF_Scalp, 200, bH,pHs,bL,pLs)) { pHs=iHigh(_Symbol,TF_Scalp,1); pLs=iLow(_Symbol,TF_Scalp,1); }

    // --- SL Calculation ---
    double sl=0.0;
    if(Use_Dynamic_SL_ATR){
        if(!PickSL_DynamicATR(buy, entry, atr, pHs, pLs, SL_ATR_Min, SL_ATR_Max, SL_Swing_Pad_ATR, sl)) return;
    }else{
        sl = buy? (entry - Scalp_SL_ATR_Mult*atr) : (entry + Scalp_SL_ATR_Mult*atr);
    }

    // --- TP Calculation (Copy from Main or Calculate) ---
    double tp = 0.0;
    bool tpOk = false;
    for(int i = PositionsTotal() - 1; i >= 0; i--) { // Search for open main trade TP
        if(PositionSelectByTicket(PositionGetTicket(i))) {
            if(PositionGetInteger(POSITION_MAGIC) == Magic && StringFind(PositionGetString(POSITION_COMMENT), "Scalp", 0) < 0) {
                 tp = PositionGetDouble(POSITION_TP);
                 if(tp > 0) { tpOk = true; break; }
            }
        }
    }
    if(!tpOk) { // Calculate theoretical main TP if none found
        double pH, pL, atrMain;
        if(GetSwingsATR(TF_Trade, 300, ST_ATR_Period, pH, pL, atrMain)) {
            if(Use_RR_Range) { // Try RR Range first
                double chosenR=0, dynTP=0;
                tpOk = PickRRTarget(buy, entry, sl, atrMain, pH, pL, RR_Min, RR_Max, TP_Max_ATR_Mult, TP_Swing_Ext_ATR_Mult, chosenR, dynTP);
                if(tpOk) tp = dynTP;
            }
            if(!tpOk) { // Fallback to Fib
                double leg = MathAbs(pH - pL);
                tp = buy ? (pH + 2.618 * leg) : (pL - 2.618 * leg);
            }
        }
    }
    if(tp == 0.0) { SendTG(StringFormat("🚫 SCALP %s REJECTED...\nSymbol: %s\nReason: Failed TP calc.", buy ? "BUY" : "SELL", _Symbol)); return; }

    // --- Finalize SL/TP and Apply Pullback ---
    { double ssl=sl, stp=tp; SanitizeStops(buy?POSITION_TYPE_BUY:POSITION_TYPE_SELL, ssl, stp); sl=ssl; tp=stp; }
    if(TP_Pullback_ATR_Mult > 0 && tp > 0) { if(buy) tp = tp - (TP_Pullback_ATR_Mult * atr); else tp = tp + (TP_Pullback_ATR_Mult * atr); }
    if( (buy && (entry - sl) <= 0) || (!buy && (sl - entry) <= 0) ) return;

    // --- HYBRID ENTRY LOGIC (Market vs Limit) ---
    double jaw, teeth, lips;
    if (!GetAlligatorLines(TF_Scalp, 1, jaw, teeth, lips)) return;
    double idealEntry = lips;
    double zone = Scalp_Market_Entry_ATR_Zone * atr;
    bool inMarketZone = buy ? (entry <= idealEntry + zone) : (entry >= idealEntry - zone);
    string entryType = "";
    double entryPrice = 0.0;
    double finalSL = sl;
    double finalTP = tp;
    if(Scalp_Market_Entry_ATR_Zone > 0 && inMarketZone) { // Market Entry
        entryType = "Market";
        entryPrice = entry;
    } else { // Limit Entry
        entryType = "Limit";
        entryPrice = idealEntry;
        finalSL = buy ? (entryPrice - MathAbs(entry - sl)) : (entryPrice + MathAbs(sl - entry));
        finalTP = buy ? (entryPrice + MathAbs(tp - entry)) : (entryPrice - MathAbs(entry - tp));
        if (buy && finalSL >= entryPrice) finalSL = entryPrice - 2.0 * atr; // Safety margin for limit SL
        if (!buy && finalSL <= entryPrice) finalSL = entryPrice + 2.0 * atr; // Safety margin for limit SL
        SanitizeStops(buy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, finalSL, finalTP);
    }

    // --- Lot Sizing ---
    double riskPtsForLots = buy ? (entryPrice - finalSL) / _Point : (finalSL - entryPrice) / _Point;
    if (riskPtsForLots <= MinStopPoints()) return;
    double rp = (Risk_Percent_Scalp > 0) ? Risk_Percent_Scalp : Risk_Percent;
    bool useFixedLot = Scalp_Use_Fixed_Lot;
    double fixedLots = (Fixed_Lots_Scalp > 0.0 ? Fixed_Lots_Scalp : Fixed_Lots);
    double lots = useFixedLot ? NormalizeVolume(fixedLots) : LotsByRisk(rp, riskPtsForLots);

    // --- Send Signal Alert & Execute Trade ---
        string signalType = buy ? "🟢 SCALP BUY SIGNAL 🟢" : "🔴 SCALP SELL SIGNAL 🔴";
        string signalMsg = StringFormat(
                                        "<b>%s</b> (%s)\n\n"
                                        "📊 <b>Symbol:</b> %s\n"
                                        "⏰ <b>Timeframe:</b> %s\n"
                                        "💰 <b>Entry Price:</b> %s\n"
                                        "⚡ <b>Strategy:</b> Scalp%s\n\n"
                                        "<i>Preparing to execute trade...</i>",
                                        signalType, entryType,
                                        _Symbol,
                                        tfstr(TF_Scalp),
                                        DoubleToString(entryPrice, _Digits),
                                        commentSuffix
                                        );
        SendTG(signalMsg);

        if (Auto_Trade)
        {
            Trade.SetExpertMagicNumber(magicToUse);
            bool orderSent = false; // <<< FIX: Declared locally

            if (entryType == "Market")
            {
                if (buy)
                {
                    Trade.Buy(lots, _Symbol, 0, finalSL, finalTP, StringFormat("V25 Scalp Buy%s", commentSuffix));
                    orderSent = (Trade.ResultRetcode() == TRADE_RETCODE_DONE);
                }
                else
                {
                    Trade.Sell(lots, _Symbol, 0, finalSL, finalTP, StringFormat("V25 Scalp Sell%s", commentSuffix));
                    orderSent = (Trade.ResultRetcode() == TRADE_RETCODE_DONE);
                }
            }
            else // "Limit"
            {
                ENUM_ORDER_TYPE_TIME time_type = Cancel_Pending_On_Flip ? ORDER_TIME_GTC : ORDER_TIME_SPECIFIED;
                datetime expiration = Cancel_Pending_On_Flip ? 0 : TimeCurrent() + (Scalp_StopEntry_Expiry_Bars * PeriodSeconds(TF_Scalp));

                if (buy)
                {
                    Trade.BuyLimit(lots, entryPrice, _Symbol, finalSL, finalTP, time_type, expiration, StringFormat("V25 Scalp Buy Limit%s", commentSuffix));
                    orderSent = (Trade.ResultRetcode() == TRADE_RETCODE_DONE);
                }
                else
                {
                    Trade.SellLimit(lots, entryPrice, _Symbol, finalSL, finalTP, time_type, expiration, StringFormat("V25 Scalp Sell Limit%s", commentSuffix));
                    orderSent = (Trade.ResultRetcode() == TRADE_RETCODE_DONE);
                }
            }

            if (orderSent)
            {
                SendTG(StringFormat("✅ Scalp %s %s placed at %.5f", buy ? "BUY" : "SELL", entryType, entryPrice));
            }
            else
            {
                SendTG(StringFormat("❌ Scalp %s %s failed: ret=%d", buy ? "BUY" : "SELL", entryType, Trade.ResultRetcode()));
            }
        } // <<< FIX: This closing brace was missing
    }
    // ====================== END TryScalpEntries() FUNCTION ======================// ====================== END TryScalpEntries() FUNCTION ======================
// ====================== EA Entries ======================
void TryEntries()
{
    // --- NEW: TIME FILTER CHECK ---
    if (!IsTradeTime())
    {
        return; // Not within the allowed trading session
    }
    // --- END TIME FILTER ---
    // ====================== PER-BAR + COOLDOWN GUARDS ======================
    static datetime lastEvalBar = 0;
    datetime barTime = iTime(_Symbol, TF_Trade, 0);
    if(barTime == lastEvalBar) return; // evaluate once per bar max
    lastEvalBar = barTime;
    if(lastTradeBarTime!=0 && (barTime - lastTradeBarTime) < (long)PeriodSeconds(TF_Trade)*Cooldown_Bars)
        return; // enforce N-bar cooldown after a fill
    // ======================================================================

    // Cooldown after last trade bar (legacy guard)
    if(lastTradeBarTime == barTime) return;

    // --- NEW: Check Momentum Cooldown Status ---
    bool isCooldownActive = false;
    int  currentEntryMode = Entry_Mode; // Use the user's setting by default
    if (g_momentumCooldownActive)
    {
        long barsPassed = (barTime - g_cooldownStartTime) / PeriodSeconds(TF_Trade);
        if (barsPassed >= Cooldown_Momentum_Bars)
        {
            g_momentumCooldownActive = false; // Cooldown expired
            SendTG("ℹ️ Cooldown over. Resuming normal entry mode.");
        }
        else
        {
            isCooldownActive = true;
            currentEntryMode = 1; // Force Reversal (Divergence) mode
        }
    }
    // --- End of New Block ---
    
    // --- NEW: DYNAMIC SPREAD FILTER ---
        if (Use_Dynamic_Spread_Filter && Avg_Spread_Lookback_Bars > 0 && Spread_Filter_Multiplier > 0)
        {
            double avgSpread = GetAverageSpreadBars(TF_Trade, Avg_Spread_Lookback_Bars);
            if (avgSpread > 0) // Only filter if average spread calculation is valid
            {
                double currentSpreadPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD); // Explicitly cast integer to double
                if (currentSpreadPoints > (avgSpread * Spread_Filter_Multiplier))
                {
                    // Optional: Print notification
                    // PrintFormat("Main entry blocked by dynamic spread: %.1f points (Avg: %.1f, Max Allowed: %.1f)",
                    //             currentSpreadPoints, avgSpread, avgSpread * Spread_Filter_Multiplier);
                    return; // Spread is too wide, block main entry
                }
            }
        }
        // --- END DYNAMIC SPREAD FILTER ---

    // --- NEW: VOLATILITY ENTRY FILTER ---
    if(Use_Volatility_Entry_Filter)
    {
        double atr = 0;
        int hATR = iATR(_Symbol, TF_Trade, ST_ATR_Period);
        if(hATR != INVALID_HANDLE)
        {
            double a[];
            if(CopyBuffer(hATR, 0, 1, 1, a) > 0) atr = a[0];
            IndicatorRelease(hATR);
        }
        double lastCandleSize = iHigh(_Symbol, TF_Trade, 1) - iLow(_Symbol, TF_Trade, 1);
        if(atr > 0 && lastCandleSize > (atr * CircuitBreaker_ATR_Mult))
        {
            return; // Block main entry, last candle was too volatile
        }
    }
    // --- END NEW FILTER ---

    // --- Magic Number Logic (Initialize) ---
    long magicToUse = Magic;         // Default to main trend magic
    string commentSuffix = "";       // Default suffix
    bool isMainReversalConditionMet = false; // Flag for special WPR condition allowing filter bypass

    // ================================ INDICATORS ==============================
    double stLineM15=0, stLineH1=0, stLineH4=0;
    int    dirM15=0, dirH1=0, dirH4=0;
    if(!CalcSuperTrend(TF_Trade, ST_ATR_Period, ST_ATR_Mult, 1, stLineM15, dirM15)) return;
    if(Use_H1H4_Filter) { // Only calculate if filter is active
        if(!CalcSuperTrend(PERIOD_H1, ST_ATR_Period, ST_ATR_Mult, 1, stLineH1, dirH1)) return;
        if(!CalcSuperTrend(PERIOD_H4, ST_ATR_Period, ST_ATR_Mult, 1, stLineH4, dirH4)) return;
    }
    int    ag = AlligatorState(TF_Trade,1);
    double ao = AOValue(TF_Trade,1);
    double mom = MomentumValue(TF_Trade,1);
    double w  = WPRValue(TF_Trade,1);
    double c  = iClose(_Symbol, TF_Trade, 1);
    bool hOK = (!Use_H1H4_Filter) || (dirH1==dirM15 && dirH4==dirM15); // H1/H4 alignment check

    // ======================= STEP 1: GENERATE ENTRY SIGNALS based on Entry_Mode =======================
    bool buySignal = false;
    bool sellSignal = false;

    // --- Priority 1: Check for Trend signals ---
    if(currentEntryMode == 0 || currentEntryMode == 2) // Trend-Following allowed
    {
        if (dirM15 > 0 && c > stLineM15) buySignal = true; // Basic ST Buy signal
        if (dirM15 < 0 && c < stLineM15) sellSignal = true; // Basic ST Sell signal
    }

    // --- Priority 2: Check for Reversal signals IF no trend signal was found OR if mode allows both ---
    if(currentEntryMode == 1 || currentEntryMode == 2) // Reversal (Divergence) allowed
    {
        bool foundBuyDivergence = CheckDivergenceForEntry(POSITION_TYPE_BUY, Divergence_Lookback_Bars, TF_Trade);
        bool foundSellDivergence = CheckDivergenceForEntry(POSITION_TYPE_SELL, Divergence_Lookback_Bars, TF_Trade);

        // --- Check WPR conditions ONLY if divergence was found, to decide on SPECIAL handling ---
        double wprH4 = WPRValue(TF_HTF_Breakout, 1); // Get H4 WPR
        double wprH1 = WPRValue(TF_Trade, 1);       // Get H1 WPR
        bool bothOverbought = (wprH4 > WPR_Overbought_Level && wprH1 > WPR_Overbought_Level);
        bool bothOversold   = (wprH4 < WPR_Oversold_Level && wprH1 < WPR_Oversold_Level);

        // Evaluate BUY Reversal
        if (foundBuyDivergence && !buySignal) // Only consider if no trend buy signal exists yet
        {
            buySignal = true; // A divergence buy signal exists
            // Check if it meets the SPECIAL Main Reversal WPR condition
            if (bothOversold)
            {
                magicToUse = Magic_Reversal;
                commentSuffix = " Main Reversal";
                isMainReversalConditionMet = true; // Mark for filter bypass
            }
            // If divergence exists but WPR condition not met, it's a standard reversal.
            else if (currentEntryMode == 1) { // Mode 1 might still use Magic_Reversal but without bypass
                 // magicToUse = Magic_Reversal;
                 // commentSuffix = " Reversal";
            }
        }

        // Evaluate SELL Reversal
        if (foundSellDivergence && !sellSignal) // Only consider if no trend sell signal exists yet
        {
            sellSignal = true; // A divergence sell signal exists
            // Check if it meets the SPECIAL Main Reversal WPR condition
            if (bothOverbought)
            {
                magicToUse = Magic_Reversal;
                commentSuffix = " Main Reversal";
                isMainReversalConditionMet = true; // Mark for filter bypass
            }
             // If not special, standard reversal handling (Mode 1 only?)
             else if (currentEntryMode == 1) {
                 // magicToUse = Magic_Reversal;
                 // commentSuffix = " Reversal";
             }
        }
    }

    // ======================= STEP 2: APPLY CONFIRMATION FILTERS =======================
    // --- Williams %R gating ---
    bool wBuyOK  = !Use_WPR_Bias || (w > -50.0);
    bool wSellOK = !Use_WPR_Bias || (w < -50.0);
    if(Use_OverboughtOversold_Filter) {
        if (w > WPR_Overbought_Level) wBuyOK = false;
        if (w < WPR_Oversold_Level) wSellOK = false;
    }
    // --- AO & Momentum Confirmation ---
    bool aoBuyOK  = (ao > 0.0 && MathAbs(ao) >= AO_Min_Strength);
    bool aoSellOK = (ao < 0.0 && MathAbs(ao) >= AO_Min_Strength);
    bool momBuyOK  = !Use_Momentum_Filter || (mom > 100.0 && (mom - 100.0) >= Mom_Min_Strength);
    bool momSellOK = !Use_Momentum_Filter || (mom < 100.0 && (100.0 - mom) >= Mom_Min_Strength);

    // --- Combine signals with confirmations ---
    bool buyCond  = buySignal && (ag > 0 && aoBuyOK && wBuyOK && hOK && momBuyOK);
    bool sellCond = sellSignal && (ag < 0 && aoSellOK && wSellOK && hOK && momSellOK);

    // --- Trend Flip & Breakout Confirmation Logic ---
    if(dirM15 != 0 && dirM15 != prevDir_ST && prevDir_ST != 0) { // Trend Flip Detection
        flipBar = iTime(_Symbol, TF_Trade, 1);
        stageCount = 0;
        g_breakoutConfirmed = false;
        string newTrend = (dirM15 > 0) ? "UP (Bullish)" : "DOWN (Bearish)";
        string alertMsg = StringFormat("🔄 TREND FLIP DETECTED...\nSymbol: %s\nTimeframe: %s\nNew Trend: %s",
                                       _Symbol, tfstr(TF_Trade), newTrend);
        SendTG(alertMsg);
    }
    prevDir_ST = dirM15;
    bool isTrendFlip = (dirM15 != 0 && dirM15 != prevDir_ST); // Recheck after update
    bool flipWaitOK = true;
    if(isTrendFlip && Min_Bars_After_Flip > 0) {
        datetime barsSinceFlip = (barTime - flipBar) / PeriodSeconds(TF_Trade);
        flipWaitOK = (barsSinceFlip >= Min_Bars_After_Flip);
    }
    if(!flipWaitOK) { buyCond = false; sellCond = false; }

    if(Use_Breakout_Confirmation && isTrendFlip && !g_breakoutConfirmed) {
        if (buyCond && magicToUse == Magic) { if(!IsCleanBreakout(POSITION_TYPE_BUY, Required_Confirmation_Candles, TF_Trade)) buyCond = false; else g_breakoutConfirmed = true; }
        if (sellCond && magicToUse == Magic) { if(!IsCleanBreakout(POSITION_TYPE_SELL, Required_Confirmation_Candles, TF_Trade)) sellCond = false; else g_breakoutConfirmed = true; }
    }

    // ======================= STEP 3: APPLY DIRECTIONAL FILTER =======================
    if(Directional_Filter_Mode == 0 && Use_HTF_Filter) {
        // --- Only apply standard filter if it's NOT our special Main Reversal ---
        if (!isMainReversalConditionMet) {
            bool finalFilterOK = false;
            bool trendAlignOK = false; // Check H4 Trend Alignment
            double htf_st_line_ignored; int htf_st_dir = 0;
            if(CalcSuperTrend(TF_HTF_Breakout, ST_ATR_Period, ST_ATR_Mult, 1, htf_st_line_ignored, htf_st_dir)) {
                if(buyCond && htf_st_dir > 0) trendAlignOK = true;
                if(sellCond && htf_st_dir < 0) trendAlignOK = true;
            }
            bool breakoutOK = false; // Check H4 Breakout Alignment
            int bH_htf, bL_htf; double pH_htf, pL_htf;
            if(RecentSwings(TF_HTF_Breakout, HTF_Breakout_Lookback, bH_htf, pH_htf, bL_htf, pL_htf)) {
                double atrHTF = 0.0; int hATR_htf = iATR(_Symbol, TF_HTF_Breakout, ST_ATR_Period);
                if(hATR_htf != INVALID_HANDLE){ double ahtf[]; ArraySetAsSeries(ahtf,true); if(CopyBuffer(hATR_htf,0,0,3,ahtf)>=2) atrHTF = ahtf[1]; IndicatorRelease(hATR_htf); }
                if(atrHTF > 0.0){ double cHTF = iClose(_Symbol, TF_HTF_Breakout, 1); double mHTF = HTF_Breakout_ATR_Margin * atrHTF;
                                  if(buyCond && (cHTF >= (pH_htf + mHTF))) breakoutOK = true;
                                  if(sellCond && (cHTF <= (pL_htf - mHTF))) breakoutOK = true; }
            }
            // Apply filter based on HTF_Filter_Mode
            switch(HTF_Filter_Mode) {
                case 0: finalFilterOK = trendAlignOK; break;
                case 1: finalFilterOK = breakoutOK; break;
                case 2: finalFilterOK = trendAlignOK && breakoutOK; break; // Default AND
            }
            if(!finalFilterOK) { buyCond = false; sellCond = false; } // Block if filter fails
        } // End of conditional filter application
    } else if (Directional_Filter_Mode == 1) { // Apply HTF Divergence Filter
        int htfDivergenceBias = GetHTFDivergenceDirection(TF_HTF_Divergence, Divergence_Lookback_Bars);
        if (htfDivergenceBias > 0) sellCond = false; // Bearish HTF divergence blocks sells
        if (htfDivergenceBias < 0) buyCond = false;  // Bullish HTF divergence blocks buys
    }

    // --- Final Check & Max Position Guard ---
    if (!buyCond && !sellCond) return;
    if(One_Trade_At_A_Time && CountOpen()>0)
    {
        string rejectMsg = StringFormat(
                                        "🚫 TRADE REJECTED - Max Positions...\nTimeframe: %s\nSymbol: %s\nCurrent: %d\nMax: 1\nSignal: %s",
                                         tfstr(TF_Trade), _Symbol, CountOpen(), buyCond ? "BUY" : (sellCond ? "SELL" : "N/A"));
        SendTG(rejectMsg);
        return;
    }

    // =========================== BUILD SL / TP & EXECUTE ============================
    if(buyCond || sellCond)
    {
        int bH; double pH; int bL; double pL;
        if(!RecentSwings(TF_Trade, 300, bH,pH,bL,pL)) return;
        int hATR = iATR(_Symbol, TF_Trade, ST_ATR_Period); double atr=0.0;
        if(hATR!=INVALID_HANDLE){ double a[]; ArraySetAsSeries(a,true); if(CopyBuffer(hATR,0,0,3,a)>=2) atr = a[1]; IndicatorRelease(hATR); }
        if(atr<=0.0) return;
        double sl=0, tp=0;
        double ask=SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid=SymbolInfoDouble(_Symbol, SYMBOL_BID);

        if(buyCond) // --- BUY ---
        {
            double entry = ask;
            if(Use_Dynamic_SL_ATR) { if(!PickSL_DynamicATR(true, entry, atr, pH, pL, SL_ATR_Min, SL_ATR_Max, SL_Swing_Pad_ATR, sl)) return; }
            else { sl = pL - ATR_SL_Buffer_Mult * atr; }
            bool tpOk=false;
            if(Use_RR_Range) { double chosenR=0, dynTP=0; tpOk = PickRRTarget(true, entry, sl, atr, pH, pL, RR_Min, RR_Max, TP_Max_ATR_Mult, TP_Swing_Ext_ATR_Mult, chosenR, dynTP); if(tpOk) tp = dynTP; }
            if(!tpOk) { double leg = MathAbs(pH - pL); tp = pH + 2.618 * leg; } // Fib fallback
            bool allowStage=false;
            if(!Use_ST_Flip_Retest){ allowStage=true; }
            else { // Check Retest Logic
                double tol = Retest_ATR_Tolerance * atr;
                bool retestTouch = (iLow(_Symbol, TF_Trade, 1) <= stLineM15 + tol);
                bool confirmAway = (c >= stLineM15 + Confirm_Close_Dist_ATR * atr);
                bool confirmOk = (ag>0 && aoBuyOK && wBuyOK && hOK && confirmAway && flipWaitOK);
                if(stageCount==0) allowStage = (retestTouch && confirmOk);
                else{ ulong tk; double e0, sl0; bool nearSL=false; if(GetLatestOpenPos(+1, true, tk, e0, sl0)) nearSL = ReachedRatioToSL(+1, e0, sl0, AddEntry_Trigger_Ratio); allowStage = (retestTouch && confirmOk && nearSL); }
            }
            if(!allowStage || stageCount>=Max_Entry_Stages) return;
            if(Use_ST_as_Stop) { double stPad = ST_Stop_Pad_Mult * atr; sl = MathMin(sl, stLineM15 - stPad); }
            { double minPtsBuy = MathMax((int)Min_SL_Points, (int)MathRound((Min_SL_ATR_Mult*atr)/_Point)); if( ((entry - sl)/_Point) < minPtsBuy ) return; }
            { double ssl=sl, stp=tp; SanitizeStops(POSITION_TYPE_BUY, ssl, stp); sl=ssl; tp=stp; }
            if(TP_Pullback_ATR_Mult > 0 && tp > 0) { tp = tp - (TP_Pullback_ATR_Mult * atr); }
            if((entry - sl) <= 0) return;
            if (tp <= entry) { SendTG(StringFormat("🚫 BUY REJECTED...\nSymbol: %s\nReason: Invalid TP (%.2f) <= entry (%.2f).", _Symbol, tp, entry)); return; }
            if(Require_Retrace_Or_Breakout) { double tolX = Retest_ATR_Tolerance * atr; bool retraceOK = (iLow(_Symbol, TF_Trade, 1) <= stLineM15 + tolX); bool breakoutOK = (c >= (pH + Breakout_ATR_Margin * atr)); if(!(retraceOK || breakoutOK)) return; }
            // --- Send Signal Alert ---
                        SendTG(StringFormat("📈 BUY Setup %s %s\nST:%s Alligator:bull AO:%.2f Mom:%.2f WPR:%.1f\nEntry: %.2f SL: %.2f TP: %.2f",
                                                     _Symbol, tfstr(TF_Trade), "UP", ao, mom, w, entry, sl, tp));

                        // --- Execute Trade ---
                        if(Auto_Trade)
                        {
                            Trade.SetExpertMagicNumber(magicToUse);
                            bool orderSent = false; // <<< FIX: Declared locally
                            double msgEntryPrice = entry;

                            if(Use_Pending_Stop_Entries)
                            {
                                if(CountPendingThisEA()>0) return; // Only one pending allowed
                                double hi1 = iHigh(_Symbol, TF_Trade, 1);
                                double stopPrice = hi1 + StopEntry_Offset_ATR * atr;
                                double riskPtsForLots = (stopPrice - sl) / _Point;
                                double orderLots = LotsByRisk(Risk_Percent, riskPtsForLots);
                                msgEntryPrice = stopPrice;
                                datetime expiration_buy = TimeCurrent() + (StopEntry_Expiry_Bars * PeriodSeconds(TF_Trade));

                                Trade.BuyStop(orderLots, stopPrice, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration_buy, StringFormat("V25 BuyStop%s", commentSuffix));
                                orderSent = (Trade.ResultRetcode() == TRADE_RETCODE_DONE); // <<< FIX: Check result

                                // Send signal detected AFTER attempting trade
                                string buySignalMsg = StringFormat("🟢 BUY SIGNAL DETECTED...\nSymbol: %s\nTimeframe: %s\nCurrent Price: %s\nSuperTrend: %s\nStrategy: Main Trend...",
                                                                   _Symbol, tfstr(TF_Trade), DoubleToString(entry, _Digits), DoubleToString(stLineM15, _Digits));
                                SendTG(buySignalMsg);
                            }
                            else // Market Entry
                            {
                                double orderLots = LotsByRisk(Risk_Percent, (entry - sl)/_Point);
                                Trade.Buy(orderLots, _Symbol, entry, sl, tp, StringFormat("V25 Buy%s", commentSuffix));
                                orderSent = (Trade.ResultRetcode() == TRADE_RETCODE_DONE); // <<< FIX: Check result
                            }

                            if(orderSent)
                            {
                                SendTG(StringFormat("[📈 BUY placed\nEntry %.2f\nSL %.2f\nTP %.2f]", msgEntryPrice, sl, tp));
                                lastTradeBarTime = barTime;
                                stageCount++;
                                lastStageBar = barTime;
                                if(Adjust_All_To_Latest) ApplySLTPToAllOpen(+1, sl, tp);
                            }
                            else
                            {
                                SendTG(StringFormat("❌ BUY send failed: ret=%d", Trade.ResultRetcode()));
                            }
                        } // <<< FIX: Correct closing brace for if(Auto_Trade)
                    } // End of if(buyCond)
                    // =============================== SELL ===============================
                    else if(sellCond)
                    {
                        double entry = bid;
                        // --- SL Calculation ---
                        if(Use_Dynamic_SL_ATR) { if(!PickSL_DynamicATR(false, entry, atr, pH, pL, SL_ATR_Min, SL_ATR_Max, SL_Swing_Pad_ATR, sl)) return; }
                        else { sl = pH + ATR_SL_Buffer_Mult * atr; }
                        // --- TP Calculation ---
                        bool tpOk=false;
                        if(Use_RR_Range) { double chosenR=0, dynTP=0; tpOk = PickRRTarget(false, entry, sl, atr, pH, pL, RR_Min, RR_Max, TP_Max_ATR_Mult, TP_Swing_Ext_ATR_Mult, chosenR, dynTP); if(tpOk) tp = dynTP; }
                        if(!tpOk) { double leg = MathAbs(pH - pL); tp = pL - 2.618 * leg; }
                        // --- Staging Logic ---
                        bool allowStage=false;
                        if(!Use_ST_Flip_Retest){ allowStage=true; }
                        else { double tol = Retest_ATR_Tolerance * atr; bool retestTouch = (iHigh(_Symbol, TF_Trade, 1) >= stLineM15 - tol); bool confirmAway = (c <= stLineM15 - Confirm_Close_Dist_ATR * atr); bool confirmOk = (ag<0 && aoSellOK && wSellOK && hOK && confirmAway && flipWaitOK);
                             if(stageCount==0) allowStage = (retestTouch && confirmOk);
                             else{ ulong tk; double e0, sl0; bool nearSL=false; if(GetLatestOpenPos(-1, true, tk, e0, sl0)) nearSL = ReachedRatioToSL(-1, e0, sl0, AddEntry_Trigger_Ratio); allowStage = (retestTouch && confirmOk && nearSL); }
                        }
                        if(!allowStage || stageCount>=Max_Entry_Stages) return;
                        // --- Final SL/TP Adjustments & Checks ---
                        if(Use_ST_as_Stop) { double stPad = ST_Stop_Pad_Mult * atr; sl = MathMax(sl, stLineM15 + stPad); }
                        { double minPtsSell = MathMax((int)Min_SL_Points, (int)MathRound((Min_SL_ATR_Mult*atr)/_Point)); if( ((sl - entry)/_Point) < minPtsSell ) return; }
                        { double ssl=sl, stp=tp; SanitizeStops(POSITION_TYPE_SELL, ssl, stp); sl=ssl; tp=stp; }
                        if(TP_Pullback_ATR_Mult > 0 && tp > 0) { tp = tp + (TP_Pullback_ATR_Mult * atr); }
                        if((sl - entry) <= 0) return;
                        if (tp >= entry) { SendTG(StringFormat("🚫 SELL REJECTED...\nSymbol: %s\nReason: Invalid TP (%.2f) >= entry (%.2f).", _Symbol, tp, entry)); return; }
                        if(Require_Retrace_Or_Breakout) { double tolX = Retest_ATR_Tolerance * atr; bool retraceOK = (iHigh(_Symbol, TF_Trade, 1) >= stLineM15 - tolX); bool breakoutOK = (c <= (pL - Breakout_ATR_Margin * atr)); if(!(retraceOK || breakoutOK)) return; }

                        // --- Send Signal Alert ---
                        SendTG(StringFormat("📉 SELL Setup %s %s\nST:%s Alligator:bear AO:%.2f Mom:%.2f WPR:%.1f\nEntry: %.2f SL: %.2f TP: %.2f",
                                                     _Symbol, tfstr(TF_Trade), "DOWN", ao, mom, w, entry, sl, tp));

                        // --- Execute Trade ---
                        if(Auto_Trade)
                        {
                            Trade.SetExpertMagicNumber(magicToUse);
                            bool orderSent = false; // <<< FIX: Declared locally
                            double msgEntryPrice = entry;

                            if(Use_Pending_Stop_Entries) // Pending Sell Stop
                            {
                                if(CountPendingThisEA()>0) return; // Only one pending allowed
                                double lo1 = iLow(_Symbol, TF_Trade, 1);
                                double stopPrice = lo1 - StopEntry_Offset_ATR * atr;
                                double riskPtsForLots = (sl - stopPrice) / _Point;
                                double orderLots = LotsByRisk(Risk_Percent, riskPtsForLots); // <<< FIX: Correct variable name
                                msgEntryPrice = stopPrice;
                                datetime expiration_sell = TimeCurrent() + (StopEntry_Expiry_Bars * PeriodSeconds(TF_Trade));

                                Trade.SellStop(orderLots, stopPrice, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration_sell, StringFormat("V25 SellStop%s", commentSuffix));
                                orderSent = (Trade.ResultRetcode() == TRADE_RETCODE_DONE); // <<< FIX: Check result

                                // Send signal detected AFTER attempting trade
                                string sellSignalMsg = StringFormat("🔴 SELL SIGNAL DETECTED...\nSymbol: %s\nTimeframe: %s\nCurrent Price: %s\nSuperTrend: %s\nStrategy: Main Trend...",
                                                                    _Symbol, tfstr(TF_Trade), DoubleToString(entry, _Digits), DoubleToString(stLineM15, _Digits));
                                SendTG(sellSignalMsg);
                            }
                            else // Market Sell
                            {
                                 double orderLots = LotsByRisk(Risk_Percent, (sl - entry)/_Point); // <<< FIX: Correct variable name
                                 Trade.Sell(orderLots, _Symbol, entry, sl, tp, StringFormat("V25 Sell%s", commentSuffix));
                                 orderSent = (Trade.ResultRetcode() == TRADE_RETCODE_DONE); // <<< FIX: Check result
                            }

                            if(orderSent)
                            {
                                SendTG(StringFormat("[📉 SELL placed\nEntry %.2f\nSL %.2f\nTP %.2f]", msgEntryPrice, sl, tp)); // <<< FIX: Added TP/SL/Entry
                                lastTradeBarTime = barTime;
                                stageCount++;
                                lastStageBar = barTime;
                                if(Adjust_All_To_Latest) ApplySLTPToAllOpen(-1, sl, tp);
                            }
                            else
                            {
                                SendTG(StringFormat("❌ SELL send failed: ret=%d", Trade.ResultRetcode()));
                            }
                        } // <<< FIX: Correct closing brace for if(Auto_Trade)
                    } // End of else if(sellCond)
                } // End of if(buyCond || sellCond)
            } // End of TryEntries
// Apply breakeven & trailing for open positions
// UPGRADED ManageOpenPositions() FUNCTION WITH TIERED EXITS

void ManageOpenPositions()

{
    
    // --- Get current SuperTrend directions for both strategies at the start ---
    
    double main_st_line; int main_st_dir;
    
    if (!CalcSuperTrend(TF_Trade, ST_ATR_Period, ST_ATR_Mult, 1, main_st_line, main_st_dir)) return;
    
    
    
    double scalp_st_line; int scalp_st_dir;
    
    if (Use_Scalp_Mode && !CalcSuperTrend(TF_Scalp, ST_ATR_Period, ST_ATR_Mult, 1, scalp_st_line, scalp_st_dir)) return;
    
    
    
    // --- Loop through all open positions ---
    
    for(int p = PositionsTotal() - 1; p >= 0; p--)
        
    {
        
        ulong ticket = PositionGetTicket(p);
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        
        
        string sym = (string)PositionGetString(POSITION_SYMBOL);
        
        if(sym != _Symbol) continue;
        
        
        
        long magic = PositionGetInteger(POSITION_MAGIC);
        
        bool isEA      = (magic==Magic || magic==Magic_Reversal);
        
        bool isManual  = (magic==0);
        
        
        
        if(!(isEA || (ApplyToManualTrades && isManual))) continue;
        
        
        
        long   type  = PositionGetInteger(POSITION_TYPE);
        
        double entry = PositionGetDouble(POSITION_PRICE_OPEN);
        
        double sl    = PositionGetDouble(POSITION_SL);
        
        double tp    = PositionGetDouble(POSITION_TP);
        
        double cur = (type==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        string pcomment = (string)PositionGetString(POSITION_COMMENT);
        
        bool   isScalp  = (StringFind(pcomment,"Scalp",0) >= 0);
        
        // ======================= ADD THIS LINE BACK =======================
        int requiredDir = (type == POSITION_TYPE_BUY) ? +1 : -1;
        // ==================================================================
        
        // ======================= TIER 1: MAIN TREND FLIP (HIGHEST PRIORITY) =======================
                
                // If the main trend flips, close ALL positions (main, scalp, manual).
                // int requiredDir = (type == POSITION_TYPE_BUY) ? +1 : -1; // <-- KEEP THIS COMMENTED
                
                if (main_st_dir != requiredDir)                          // <-- UNCOMMENTED
                {                                                        // <-- UNCOMMENTED
                   if (Trade.PositionClose(ticket))                      // <-- UNCOMMENTED
                   {                                                     // <-- UNCOMMENTED
                      SendTG(StringFormat("🛑 %s closed: MAIN TREND flipped on %s. Exit price %.2f", // <-- UNCOMMENTED
                                          pcomment, tfstr(TF_Trade), cur));
                   }                                                     // <-- UNCOMMENTED
                   continue; // Position is closed, move to the next one. // <-- UNCOMMENTED
                }                                                        // <-- UNCOMMENTED
        
        
        // ======================= TIER 2: SCALP TREND FLIP (SCALP ONLY) =======================
        
        // If this is a scalp trade AND the scalp trend has flipped, close ONLY this scalp trade.
        
        if (isScalp && scalp_st_dir != requiredDir)
            
        {
            
            if (Trade.PositionClose(ticket))
                
            {
                
                SendTG(StringFormat("🛑 %s closed: SCALP TREND flipped on %s. Exit price %.2f",
                                    
                                    pcomment, tfstr(TF_Scalp), cur));
                
            }
            
            continue; // Position is closed, move to the next one.
            
        }
        
        
        
        // If a position is a scalp and Protect_Scalp_SLTP is on, skip all further management.
        
        if(Protect_Scalp_SLTP && isScalp) continue;
        
        // In ManageOpenPositions() function - ADD THIS BLOCK after trend flip checks
        
        // ======================= MOMENTUM DIVERGENCE EXIT (TIER 1.5) =======================
                if(Use_Momentum_Exit_Filter && isEA) // Only for EA trades, not manual
                {
                    // --- NEW: Determine correct timeframe based on trade type ---
                    ENUM_TIMEFRAMES divergenceTF = isScalp ? TF_Scalp : TF_Trade;
                    // --- END NEW ---

                    if(CheckMomentumDivergence(type, Divergence_Lookback_Bars, divergenceTF)) // <-- Uses dynamic timeframe
                    {
                        // --- Calculate P/L Before Closing ---
                        double potentialProfit = 0;
                        double swap = PositionGetDouble(POSITION_SWAP);
                        double fee = 0;
                        if (type == POSITION_TYPE_BUY) {
                            potentialProfit = (cur - entry) * PositionGetDouble(POSITION_VOLUME) * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
                        } else { // SELL
                            potentialProfit = (entry - cur) * PositionGetDouble(POSITION_VOLUME) * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
                        }
                        double potentialNet = potentialProfit + swap + fee;
                        string profitEmoji = (potentialNet >= 0) ? "✅" : "❌";
                        string profitSign  = (potentialNet >= 0) ? "+" : "";

                        if(Trade.PositionClose(ticket))
                        {
                            // --- MODIFIED: Use correct timeframe in alert message ---
                            SendTG(StringFormat("%s %s closed:\n"
                                                "MOMENTUM DIVERGENCE\n"
                                                "Detected on %s.\n" // <-- Uses dynamic timeframe
                                                "💰 Profit/Loss: %s%.2f (Exit: %.2f)",
                                                profitEmoji, pcomment,
                                                tfstr(divergenceTF), // <-- Uses dynamic timeframe
                                                profitSign, potentialNet, cur));
                            // --- END MODIFICATION ---
                        }
                        continue; // Position closed, move to next
                    }
                }
        
        // --- Breakeven (BE) & Protection Logic (Percentage Only) ---
        // Note: BE_Activation_TP_Percent must be > 0.0 to enable this block.
        if(BE_Activation_TP_Percent > 0.0 && tp > 0.0 && sl > 0.0)
        {
            // Define a tiny buffer to guarantee the modification is an 'improvement' to the broker
            const double BE_Buffer = BE_Buffer_Points * _Point; // Move SL to entry + 1 Point (guaranteed improvement)
            
            double totalDistToTP = (type == POSITION_TYPE_BUY) ?
            (tp - entry) : (entry - tp);
            double currentProgress = (type == POSITION_TYPE_BUY) ?
            (cur - entry) : (entry - cur);
            
            // 1. Check if the trade is in profit and has a valid TP distance
            if(totalDistToTP > _Point && currentProgress > 0)
            {
                // --- Trigger: Percentage Progress to TP ---
                double requiredProgress = totalDistToTP * (BE_Activation_TP_Percent / 100.0);
                
                if (currentProgress >= requiredProgress)
                                {
                                    // --- MODIFIED: Calculate BE based on BE_Profit_Percent ---
                                    double profitToLockIn = totalDistToTP * (BE_Profit_Percent / 100.0);
                                    
                                    // Fallback: Ensure we at least move it past entry by a small amount
                                    if (profitToLockIn <= (100.0 * _Point))
                                    {
                                        profitToLockIn = 100.0 * _Point; // Default to 100 points
                                    }
                                    
                                    double targetBE = (type == POSITION_TYPE_BUY) ? (entry + profitToLockIn) : (entry - profitToLockIn);
                                    // --- END MODIFICATION ---
                                    bool needsMove = (type == POSITION_TYPE_BUY && sl < targetBE) || (type == POSITION_TYPE_SELL && sl > targetBE);
                    if(needsMove)
                    {
                        double modSL = targetBE, modTP = tp;
                        // SanitizeStops ensures compliance with broker MinStopLevel
                        SanitizeStops(type, modSL, modTP);
                        
                        // Final check for significant change (> 0.5 Point)
                        if(modSL > 0 && MathAbs(modSL - sl) >= 0.5 * _Point)
                        {
                            if(Trade.PositionModify(_Symbol, modSL, modTP))
                            {
                                g_trailingActivated = true;
                                // --- 6. BREAKEVEN ACTIVATED ---
                                double progressPercent = (currentProgress / totalDistToTP) * 100.0;
                                string beMsg = StringFormat(
                                                            "💰 <b>BREAKEVEN ACTIVATED</b>\n\n"
                                                            "📊 <b>Symbol:</b> %s\n"
                                                            "📈 <b>Type:</b> %s\n"
                                                            "🛑 <b>New SL:</b> %s\n"
                                                            "⚡ <b>Progress:</b> %.1f%% to TP",
                                                            _Symbol,
                                                            (type == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                                                            DoubleToString(modSL, _Digits),
                                                            progressPercent
                                                            );
                                SendTG(beMsg);
                            }
                        }
                        
                    }
                }
            }
        }
        // --- End of Breakeven Logic ---
        
        // --- Partial Close Logic ---
        if(!isScalp || !Protect_Scalp_SLTP) // Don't partial close protected scalp trades
        {
            CheckPartialClose(ticket, type, entry, sl, tp,
                             PositionGetDouble(POSITION_VOLUME), pcomment);
        }
        
        // --- Manual HALF-STEP trailing (adds; mirrors main, skips scalps & EA mains)
        if(Use_HalfStep_Trailing && ApplyToManualTrades && isManual && tp>0.0 && sl>0.0)
        {
            static datetime lastHalfBarManual = 0;
            datetime curBar = iTime(_Symbol, TF_Trade, 0);
            bool canUpdate = (!HalfTrail_NewBar_Only || curBar!=lastHalfBarManual);
            
            if(canUpdate)
            {
                // distance to TP and progress toward TP
                double targetPts   = (type==POSITION_TYPE_BUY) ? (tp - entry)/_Point
                : (entry - tp)/_Point;
                double progressPts = (type==POSITION_TYPE_BUY) ? (cur - entry)/_Point
                : (entry - cur)/_Point;
                
                if(progressPts > 0)
                {
                    double ratio   = MathMin(1.0, progressPts/targetPts);
                    double desired = 0.0;
                    
                    if(type==POSITION_TYPE_BUY)
                        desired = entry + 0.5 * ratio * (tp - entry);
                    else
                        desired = entry - 0.5 * ratio * (entry - tp);
                    
                    double modSL = sl, modTP = tp;
                    if(type==POSITION_TYPE_BUY && desired>sl)  modSL = desired;
                    if(type==POSITION_TYPE_SELL && desired<sl) modSL = desired;
                    
                    SanitizeStops(type, modSL, modTP);
                    
                    if(modSL>0 && MathAbs(modSL - sl) >= 0.5*_Point)
                    {
                        if(Trade.PositionModify(_Symbol, modSL, modTP))
                        {
                            g_trailingActivated = true; // <-- ADD THIS LINE
                        }
                    }
                }
                
                lastHalfBarManual = curBar;
            }
            
            // when manual half-step active, skip further trailing for this position
            continue;
        }
        // --- end Manual HALF-STEP trailing ---
        
        // --- Half-step trailing (main positions only)
        if(Use_HalfStep_Trailing)
        {
            // run at most once per bar if requested
            static datetime lastHalfBar = 0;
            datetime hb = iTime(_Symbol, TF_Trade, 0);
            bool allowNow = (!HalfTrail_NewBar_Only || hb != lastHalfBar);
            if(allowNow) lastHalfBar = hb;
            
            if(allowNow)
            {
                // Need a valid TP on the correct side of entry
                double D = (type==POSITION_TYPE_BUY) ? (tp - entry) : (entry - tp);
                if(tp>0 && D>0.0)
                {
                    // Progress to TP in [0..1]
                    double progress = (type==POSITION_TYPE_BUY)
                    ? (cur - entry) / D
                    : (entry - cur) / D;
                    
                    // <<< FIX: Only run trailing logic if the trade is actually in profit. >>>
                    if(progress <= 0.0) continue; // If not in profit, skip this position and move to the next.
                    
                    if(progress > 1.0) progress = 1.0;
                    
                    // Target SL = entry +/- 0.5 * progress * distance-to-TP
                    double targetSL = (type==POSITION_TYPE_BUY)
                    ? (entry + 0.5 * progress * D)
                    : (entry - 0.5 * progress * D);
                    
                    // Monotonic: never move SL backwards
                    double newSL = (type==POSITION_TYPE_BUY) ? MathMax(sl, targetSL)
                    : MathMin(sl, targetSL);
                    
                    // Sanitize and micro-move filter
                    double modSL=newSL, modTP=tp;
                    SanitizeStops(type, modSL, modTP);
                    
                    if(modSL>0 && MathAbs(modSL - sl) >= 0.5*_Point)
                    {
                        if(Trade.PositionModify(_Symbol, modSL, modTP))
                        {
                            g_trailingActivated = true; // <-- ADD THIS LINE
                        }
                    }
                }
            }
            
            // When half-step trailing is active, skip legacy ATR trailing for this position
            continue;
        }
        
        // ATR trailing
        if(Use_ATR_Trailing)
        {
            int hATR = iATR(_Symbol, TF_Trade, ATR_Period_Trail);
            if(hATR!=INVALID_HANDLE)
            {
                double a[]; ArraySetAsSeries(a,true);
                if(CopyBuffer(hATR,0,0,3,a)>=2)
                {
                    double atr = a[1];
                    if(type==POSITION_TYPE_BUY)
                    {
                        double trail = cur - ATR_Trail_Mult * atr;
                        if(trail>sl)
                        {
                            double modSL=trail, modTP=tp;
                            SanitizeStops(type, modSL, modTP);
                            if(modSL>0 && MathAbs(modSL-sl) >= 0.5*_Point)
                            {
                                if(Trade.PositionModify(_Symbol, modSL, modTP))
                                {
                                    g_trailingActivated = true; // <-- ADD THIS LINE
                                }
                            }
                        }
                    }
                    else
                    {
                        double trail = cur + ATR_Trail_Mult * atr;
                        
                        // <<< BUG FIX: Corrected logic to only move SL down (forward for a sell) >>>
                        if(trail < sl)
                        {
                            double modSL=trail, modTP=tp;
                            SanitizeStops(type, modSL, modTP);
                            if(modSL>0 && MathAbs(modSL-sl) >= 0.5*_Point)
                            {
                                if(Trade.PositionModify(_Symbol, modSL, modTP))
                                {
                                    g_trailingActivated = true;
                                }
                            }
                        }
                    }
                }
                IndicatorRelease(hATR);
            }
        }
        // [INSERT THIS BLOCK BEFORE LINE 810 (BE/Protection Logic)]
        
    }
}

//============================== Events ==============================
// REPLACEMENT FOR OnInit() FUNCTION
int OnInit()
{
    // --- Set the EA start time for reports
    g_eaStartTime = TimeCurrent();
    
    // --- 11. CONNECTION TEST
    string testMsg = "🔔 EA Connection Test\nTesting Telegram notifications...";
    SendTG(testMsg);
    
    // --- 1. ACTIVATION NOTIFICATION
    string mainStrategyStatus = "ENABLED"; // Main strategy is always on
    string scalpStrategyStatus = Use_Scalp_Mode ? "ENABLED" : "DISABLED";
    string maxPos;
    if(One_Trade_At_A_Time) maxPos = "1";
    else maxPos = (string)Max_Entry_Stages;
    
    
    string activationMsg = StringFormat(
                                        "✅ <b>Nodezilla101 EA Bot ACTIVATED</b>\n\n"
                                        "📊 <b>Symbol:</b> %s\n"
                                        "⏰ <b>Timeframe:</b> %s\n"
                                        "💼 <b>Main Strategy:</b> %s\n"
                                        "⚡ <b>Scalp Strategy:</b> %s\n"
                                        "📈 <b>Trade TF:</b> %s\n"
                                        "📉 <b>Scalp TF:</b> %s\n"
                                        "🚫 <b>Max Positions:</b> %s\n\n"
                                        "<i>Monitoring for trading opportunities...</i>",
                                        _Symbol,
                                        tfstr(_Period), // Use the chart's current timeframe
                                        mainStrategyStatus,
                                        scalpStrategyStatus,
                                        tfstr(TF_Trade),
                                        tfstr(TF_Scalp),
                                        maxPos
                                        );
    SendTG(activationMsg);
    
    EventSetTimer(60);
    return(INIT_SUCCEEDED);
}

// HELPER FUNCTION TO GET DEINIT REASON (ADD THIS BEFORE OnDeinit)
string GetDeinitReason(int reason)
{
    switch(reason)
    {
        case REASON_REMOVE:         return "EA removed by user";
        case REASON_CHARTCHANGE:    return "Chart symbol or period changed";
        case REASON_CHARTCLOSE:     return "Chart was closed";
        case REASON_PARAMETERS:     return "Input parameters changed";
        case REASON_ACCOUNT:        return "Account changed";
        case REASON_TEMPLATE:       return "New template applied";
        case REASON_RECOMPILE:      return "EA was recompiled";
        default:                    return "Unknown reason";
    }
}


// REPLACEMENT FOR OnDeinit() FUNCTION
void OnDeinit(const int reason)
{
    EventKillTimer();
    
    // --- 10. DEACTIVATION NOTIFICATION
    string deactivationMsg = StringFormat(
                                          "❌ <b>Nodezilla101 EA Bot DEACTIVATED</b>\n\n"
                                          "📊 <b>Symbol:</b> %s\n"
                                          "⏰ <b>Timeframe:</b> %s\n"
                                          "🔧 <b>Reason:</b> %s",
                                          _Symbol,
                                          tfstr(_Period),
                                          GetDeinitReason(reason)
                                          );
    SendTG(deactivationMsg);
}

void SendPeriodReport(datetime fromTs, datetime toTs, const string label)
{
    if(StringLen(TG_BOT_TOKEN)<10 || StringLen(TG_CHAT_ID)<1) return;
    
    HistorySelect(fromTs, toTs);
    
    // Totals (EA-only, current symbol)
    int mainN=0, scalpN=0, mainW=0, scalpW=0;
    double mainNet=0.0, scalpNet=0.0, best=0.0, worst=0.0;
    
    int total = (int)HistoryDealsTotal();
    for(int i=0;i<total;i++)
    {
        ulong d = HistoryDealGetTicket(i);
        long  ent = (long)HistoryDealGetInteger(d, DEAL_ENTRY);
        if(!(ent==DEAL_ENTRY_OUT || ent==DEAL_ENTRY_OUT_BY)) continue;
        
        string sym = (string)HistoryDealGetString(d, DEAL_SYMBOL);
        if(sym != _Symbol) continue;
        
        long mg = (long)HistoryDealGetInteger(d, DEAL_MAGIC);
        if(mg != Magic) continue;
        
        double P = HistoryDealGetDouble(d, DEAL_PROFIT);
        double F = HistoryDealGetDouble(d, DEAL_FEE);
        double C = HistoryDealGetDouble(d, DEAL_COMMISSION);
        double S = HistoryDealGetDouble(d, DEAL_SWAP);
        double net = P + F + C + S;
        
        string cmt = (string)HistoryDealGetString(d, DEAL_COMMENT);
        bool   isScalp = (StringFind(cmt,"Scalp",0)>=0);
        
        if(isScalp){
            scalpN++;
            if(net>=0) scalpW++;
            scalpNet += net;
        }else{
            mainN++;
            if(net>=0) mainW++;
            mainNet += net;
        }
        
        if(net>best || (i==0))  best=net;
        if(net<worst|| (i==0)) worst=net;
    }
    
    int totN = mainN + scalpN;
    int totW = mainW + scalpW;
    double totNet = mainNet + scalpNet;
    double wr = (totN>0) ? (100.0 * (double)totW / (double)totN) : 0.0;
    double wrMain  = (mainN>0)  ? (100.0 * (double)mainW  / (double)mainN)  : 0.0;
    double wrScalp = (scalpN>0) ? (100.0 * (double)scalpW / (double)scalpN) : 0.0;
    
    string hdr = StringFormat("📊 %s Report — %s", label, _Symbol);

        // --- MODIFICATION START: Build format string separately ---
        string fmt = "[ %s\nPeriod: %s → %s\n\nTotal: %d trades | WinRate %.1f%% | Net %.2f\n";
        fmt +=       "Main:  %d trades | WR %.1f%% | Net %.2f\n";
        fmt +=       "Scalp: %d trades | WR %.1f%% | Net %.2f\n";
        fmt +=       "Best:  %.2f   Worst: %.2f ]";
        // --- MODIFICATION END ---

        string body = StringFormat(fmt, // Use the pre-built format string
                     hdr,
                     TimeToString(fromTs, TIME_DATE|TIME_MINUTES),
                     TimeToString(toTs,   TIME_DATE|TIME_MINUTES),
                     totN, wr, totNet,
                     mainN, wrMain, mainNet,
                     scalpN, wrScalp, scalpNet,
                     best, worst);
        SendTG(body);
    }

// REPLACEMENT FOR OnTimer() FUNCTION
void OnTimer()
{
    datetime now = TimeCurrent();
    MqlDateTime st; TimeToStruct(now, st);

    // --- SCHEDULED REPORTS (WEEKLY) ---
    if(Send_Weekly_Report)
    {
        bool dow_ok = (st.day_of_week == Weekly_Report_DOW); // Check if it's the reporting day (Sunday=0)
        bool time_ok= (st.hour==Weekly_Report_Hour && st.min>=Weekly_Report_Min); // Check if it's the reporting time
        bool gap_ok = (now - g_lastWeeklyReportSent) > (5*24*60*60); // Prevent duplicates (allow only 1 report per 5 days)

        if(dow_ok && time_ok && gap_ok)
        {
            // Calculate start time (7 days ago from 'now')
            datetime weekStart = now - (7 * 24 * 60 * 60);
            // Call the detailed report function
            SendPeriodReport(weekStart, now, "WEEKLY");
            g_lastWeeklyReportSent = now; // Update the timestamp
        }
    }

    // --- SCHEDULED REPORTS (MONTHLY) ---
    if(Send_Monthly_Report)
    {
        bool dom_ok = (st.day == Monthly_Report_DOM); // Check if it's the 1st day of the month
        bool time_ok= (st.hour==Monthly_Report_Hour && st.min>=Monthly_Report_Min); // Check reporting time
        bool gap_ok = (now - g_lastMonthlyReportSent) > (25*24*60*60); // Prevent duplicates (allow only 1 report per 25 days)

        if(dom_ok && time_ok && gap_ok)
        {
            // Calculate the start time (approximately 1 month ago)
            MqlDateTime startDt;
            TimeToStruct(now, startDt);
            // Go back one month, handle year change
            if (startDt.mon == 1) {
                startDt.mon = 12;
                startDt.year--;
            } else {
                startDt.mon--;
            }
            // Ensure the day is valid for the previous month (e.g., handle Feb 30th)
            int daysInPrevMonth = DaysInMonth(startDt.year, startDt.mon);
            startDt.day = MathMin(st.day, daysInPrevMonth); // Use same day or last day of prev month

            datetime monthStart = StructToTime(startDt);

            // Call the detailed report function
            SendPeriodReport(monthStart, now, "MONTHLY");
            g_lastMonthlyReportSent = now; // Update the timestamp
        }
    }
}

// Helper function to get days in a month (needed for monthly report)
int DaysInMonth(int year, int month)
{
    if(month<1 || month>12) return 0;
    int days[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    if(month==2 && IsLeapYear(year)) return 29;
    return days[month];
}

// Helper function to check for leap year (needed for monthly report)
bool IsLeapYear(int year)
{
    return (year%4==0 && (year%100!=0 || year%400==0));
}

// REPLACEMENT FOR OnTradeTransaction() FUNCTION
// REPLACEMENT FOR OnTradeTransaction() FUNCTION
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest      &req,
                        const MqlTradeResult       &res)
{
    // --- Check if the event is a completed trade or a deleted order ---
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD && trans.type != TRADE_TRANSACTION_ORDER_DELETE) return;
    
    // --- Event Type 1: A DEAL WAS MADE (POSITION OPENED OR CLOSED) ---
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        ulong deal = (ulong)trans.deal;
        if(deal == 0) return;
        
        HistorySelect(0, TimeCurrent());
        long   entryType = (long)HistoryDealGetInteger(deal, DEAL_ENTRY);
        string sym       = (string)HistoryDealGetString (deal, DEAL_SYMBOL);
        if(sym != _Symbol) return;
        
        // --- A POSITION OPENED (FILL) ---
        if(entryType == DEAL_ENTRY_IN)
        {
            long mg = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
            if(mg != Magic && mg != Magic_Reversal) return; // Only this EA's trades
            
            long   dType   = (long)HistoryDealGetInteger(deal, DEAL_TYPE);
            string typeStr = (dType==DEAL_TYPE_BUY) ? "BUY" : "SELL";
            string typeEmoji = (dType==DEAL_TYPE_BUY) ? "📈" : "📉";
            double entry   = HistoryDealGetDouble(deal, DEAL_PRICE);
            double lots    = HistoryDealGetDouble(deal, DEAL_VOLUME);
            string cmt     = (string)HistoryDealGetString(deal, DEAL_COMMENT);
            bool   isScalp = (StringFind(cmt,"Scalp",0) >= 0);
            string strat   = isScalp ? "Scalp Strategy" : "Main Strategy";
            
            // --- ERROR FIX: Declaring these variables once for this block ---
            double sl=0.0, tp=0.0;
            ulong posID = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
            if(PositionSelectByTicket(posID))
            {
                sl = PositionGetDouble(POSITION_SL);
                tp = PositionGetDouble(POSITION_TP);
            }
            
            // If a new scalp trade opened AND trailing has been activated, sync all stops
            if(isScalp && g_trailingActivated)
            {
                SyncAllStopsSafely(sl);
            }
            
            string execMsg = StringFormat(
                                          "✅ <b>TRADE EXECUTED</b>\n\n"
                                          "📊 <b>Symbol:</b> %s\n"
                                          "%s <b>Type:</b> %s\n"
                                          "💰 <b>Entry:</b> %s\n"
                                          "📦 <b>Lots:</b> %.2f\n"
                                          "🛑 <b>SL:</b> %s\n"
                                          "🎯 <b>TP:</b> %s\n"
                                          "⚡ <b>Strategy:</b> %s",
                                          _Symbol, typeEmoji, typeStr, DoubleToString(entry, _Digits),
                                          lots, DoubleToString(sl, _Digits), DoubleToString(tp, _Digits), strat
                                          );
            SendTG(execMsg);
            return;
        }
        
        // --- B) POSITION CLOSED (WIN/LOSS) ---
        if(Send_Closed_Trade_Alerts && (entryType==DEAL_ENTRY_OUT || entryType==DEAL_ENTRY_OUT_BY))
        {
            long mg = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
            // --- Ensure we only process trades from our EA (both magic numbers) ---
            if(mg != Magic && mg != Magic_Reversal) return;

            double P    = HistoryDealGetDouble (deal, DEAL_PROFIT);
            double F    = HistoryDealGetDouble (deal, DEAL_FEE);
            double C    = HistoryDealGetDouble (deal, DEAL_COMMISSION);
            double S    = HistoryDealGetDouble (deal, DEAL_SWAP);
            double net  = P + F + C + S;
            string cmt  = (string)HistoryDealGetString(deal, DEAL_COMMENT);

            // --- Activate Momentum Cooldown if the trade was profitable or break-even ---
            if (net >= 0)
            {
                g_momentumCooldownActive = true;
                g_cooldownStartTime = TimeCurrent();
                SendTG("ℹ️ Cooldown activated after profitable trade. Switching to reversal-only mode.");
            }

            // --- Find the Original Entry Price for this Closed Position ---
            double entryPrice = 0.0;
            ulong positionID = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
            if (positionID > 0)
            {
                for (int i = (int)HistoryDealsTotal() - 1; i >= 0; i--)
                {
                    ulong d_ticket = HistoryDealGetTicket(i);
                    if (d_ticket == 0) continue;

                    if (HistoryDealGetInteger(d_ticket, DEAL_POSITION_ID) == positionID &&
                        HistoryDealGetInteger(d_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
                    {
                        entryPrice = HistoryDealGetDouble(d_ticket, DEAL_PRICE);
                        break;
                    }
                }
            }

            // Determine the closing reason
            string reason = "Unknown/Other";
            long dealReason = HistoryDealGetInteger(deal, DEAL_REASON);

            // FIXED: Use proper MQL5 deal reason constants
            if(dealReason == DEAL_REASON_CLIENT)           reason = "Closed Manually by Client";
            else if(dealReason == DEAL_REASON_EXPERT)      reason = "Closed by EA Logic";
            else if(dealReason == DEAL_REASON_SL)          reason = "Closed by Stop Loss";
            else if(dealReason == DEAL_REASON_TP)          reason = "Closed by Take Profit";
            else if(dealReason == DEAL_REASON_SO)          reason = "Closed by Stop Out";
            else if(dealReason == DEAL_REASON_ROLLOVER)    reason = "Closed due to Rollover";
            else if(dealReason == DEAL_REASON_VMARGIN)     reason = "Closed by Var. Margin";
            else if(dealReason == DEAL_REASON_SPLIT)       reason = "Closed due to Split";
            else if(cmt == "")                             reason = "Closed Manually (No Comment)";
            else                                           reason = "Closed (Check Comment/Broker)";

            // --- Send the Telegram Alert ---
            string closeMsg = StringFormat(
                                           "%s **POSITION CLOSED**\n\n"
                                           "📊 **Symbol:** %s\n"
                                           "▶️ **Entry:** %s\n"
                                           "💰 **Profit/Loss:** %s%.2f\n"
                                           "⚡ **Reason:** %s",
                                           net >= 0 ? "✅" : "❌",
                                           _Symbol,
                                           DoubleToString(entryPrice, _Digits),
                                           net >= 0 ? "+" : "", net,
                                           reason
                                          );
            SendTG(closeMsg);
        }
    }
    // --- Event Type 2: A PENDING ORDER WAS REMOVED ---
    else if(trans.type == TRADE_TRANSACTION_ORDER_DELETE)
    {
        // --- ERROR FIX: Check req.magic instead of trans.magic ---
        if(req.magic == Magic || req.magic == Magic_Reversal)
        {
            if(trans.order_type == ORDER_TYPE_BUY_LIMIT || trans.order_type == ORDER_TYPE_SELL_LIMIT)
            {
                string orderTypeStr = (trans.order_type == ORDER_TYPE_BUY_LIMIT) ? "Buy Limit" : "Sell Limit";
                
                string removeMsg = StringFormat(
                                                "🔵 <b>PENDING ORDER REMOVED</b>\n\n"
                                                "📊 <b>Symbol:</b> %s\n"
                                                "🔵 <b>Type:</b> %s\n"
                                                "💰 <b>Price:</b> %s\n"
                                                "⚡ <b>Reason:</b> Order expired or was canceled.",
                                                _Symbol,
                                                orderTypeStr,
                                                DoubleToString(trans.price, _Digits)
                                                );
                SendTG(removeMsg);
            }
        }
    }
}
