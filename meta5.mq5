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

// --- Main Strategy ---
input ENUM_TIMEFRAMES TF_Trade        = PERIOD_H1;    // The timeframe the main strategy runs on.
input double         Risk_Percent     = 0;          // Risk % for main trades. Set to 0 to use Fixed_Lots.
input double         Fixed_Lots       = 0.50;       // Lot size for main trades if Risk_Percent is 0.

// --- Scalp Strategy ---
input bool           Use_Scalp_Mode   = true;     // MASTER SWITCH: Turn the scalping engine on/off.
input ENUM_TIMEFRAMES TF_Scalp        = PERIOD_M15;   // The timeframe the scalp strategy reads from.
input bool           Scalp_Use_Fixed_Lot = true;  // true = use fixed lot below, false = use risk %
input double         Fixed_Lots_Scalp = 1.00;      // Lot size for scalp trades.
input double         Risk_Percent_Scalp = 6;      // if >0, overrides and uses this absolute % just for scalps


//================================================================================
//                 --- TRADE MANAGEMENT & EXITS ---
//================================================================================
// Controls how trades are managed after they are opened.

// --- Trailing Stops ---
input bool           Use_ATR_Trailing   = false;    // Dynamic SL that follows price based on volatility.
input double         ATR_Trail_Mult     = 3.5;      // Multiplier for ATR Trail. Higher = wider trail.
input bool           Use_HalfStep_Trailing = true;  // Alternative trail: SL moves half the distance to TP.

// --- Break-Even ---
input double         BE_Activation_TP_Percent = 20.0; // Move SL to BE when trade is X% of the way to TP.

// --- Emergency Exit ---
input bool           Use_Volatility_CircuitBreaker = true; // Emergency brake for extreme volatility.
input double         CircuitBreaker_ATR_Mult = 4.5;    // Closes all if a candle is > X times the average size.

// --- Profit Targets (Risk/Reward) ---
input double         RR_Min           = 3.0;      // MINIMUM R:R for main trades.
input double         RR_Max           = 10.0;     // MAXIMUM R:R for main trades.
input double         Scalp_RR_Min     = 3.0;      // MINIMUM R:R for scalp trades.
input double         Scalp_RR_Max     = 10.0;     // MAXIMUM R:R for scalp trades.


//================================================================================
//                 --- ENTRY FILTERS & QUALITY CONTROLS ---
//================================================================================
// These settings make the EA more selective about which trades to take.

// --- Main Strategy Filters ---
input bool           Use_H1H4_Filter    = true;     // Require main trades to align with H1/H4 SuperTrend.
input bool           Use_ST_Flip_Retest = true;      // Wait for price to pull back to the ST line before entry.
input bool           Use_HTF_Breakout_Filter = false;// Require a breakout on a higher timeframe.
input ENUM_TIMEFRAMES TF_HTF_Breakout   = PERIOD_H1;  // Timeframe for the breakout filter.
input int            Max_Entry_Stages   = 4;        // Allow adding to a trade up to X times.
input bool           One_Trade_At_A_Time = false;   // If true, only one main trade is allowed at a time.

// --- Scalp Strategy Filters ---
input bool           Scalp_Gate_By_HTF  = true;     // Require scalp trades to align with HTF breakout.
input ENUM_TIMEFRAMES TF_Scalp_Gate_HTF = PERIOD_M15; // Timeframe for the scalp alignment filter.
input bool           Scalp_Only_When_No_Main = false; // Block scalps if a main trade is already open.
input int            Scalp_Max_Concurrent = 6;      // Max number of simultaneous scalp trades.


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
input double         AO_Min_Strength  = 0.0;
input double         AO_Scalp_Min_Strength = 3;
input bool           Use_WPR_Bias     = true;
input bool           Use_WPR_Cross    = false;

// --- Pending Order Mechanics ---
input bool           Use_Pending_Stop_Entries = true;
input double         StopEntry_Offset_ATR = 0.1;
input int            StopEntry_Expiry_Bars = 6;
input bool           Scalp_Use_Pending_Stop_Entries = true;
input double         Scalp_StopEntry_Offset_ATR = 0.02;
input int            Scalp_StopEntry_Expiry_Bars = 6;
input double         Scalp_Market_Entry_ATR_Zone = 1.5;

// --- Manual Trade Management ---
input bool           ApplyToManualTrades = true;
input bool           Manual_Set_Initial_SLTP = false;
input bool           Manual_Use_Fib_Targets = true;
input bool           Manual_Use_RR_Range = true;
input double         Manual_RR_Min      = 3.0;
input double         Manual_RR_Max      = 10.0;
input double         Manual_TP_Max_ATR_Mult = 6.0;
input double         Manual_TP_Swing_Ext_ATR_Mult = 1.50;

// --- Detailed SL/TP Mechanics ---
input bool           Use_Fib_Targets    = true;
input bool           Use_RR_Range       = true;
input bool           Scalp_Use_RR_Range = true;
input bool           Use_Dynamic_SL_ATR = true;
input double         ATR_SL_Buffer_Mult = 0.1;
input double         SL_ATR_Min         = 2;
input double         SL_ATR_Max         = 6.0;
input double         SL_Swing_Pad_ATR   = 0.60;
input double         Min_SL_ATR_Mult    = 0.8;
input int            Min_SL_Points      = 0;
input bool           Use_ST_as_Stop     = true;
input double         ST_Stop_Pad_Mult   = 0.8;
input double         TP_Max_ATR_Mult    = 8.0;
input double         TP_Swing_Ext_ATR_Mult = 1.50;
input double         Scalp_TP_Max_ATR_Mult = 6.0;
input double         Scalp_TP_Swing_Ext_ATR_Mult = 1.50;
input int            Scalp_ATR_Period   = 10;
input double         Scalp_SL_ATR_Mult  = 0.5;
input bool           Protect_Scalp_SLTP = false;
input bool           Adjust_All_Exclude_Scalps = false;

// --- Detailed Filter Mechanics ---
input int            HTF_Breakout_Lookback = 600;
input double         HTF_Breakout_ATR_Margin = 0.12;
input int            HTF_Breakout_Mode  = 0;
input int            HTF_Breakout_MaxAgeBars = 3;
input double         Retest_ATR_Tolerance = 0.15;
input double         AddEntry_Trigger_Ratio = 0.85;
input bool           Adjust_All_To_Latest = true;
input int            Min_Bars_After_Flip = 1;
input double         Confirm_Close_Dist_ATR = 0.10;
input bool           Require_Retrace_Or_Breakout = false;
input double         Breakout_ATR_Margin = 0.10;
input double         Scalp_Gate_ATR_Margin = 0.10;
input double         Scalp_Risk_Mult    = 2.0;

// --- System & Housekeeping ---
input long           Magic            = 250925;
input int            Cooldown_Bars    = 2;
input int            Slippage_Points  = 50;
input bool           Send_Closed_Trade_Alerts = true;
input bool           Send_Weekly_Report = true;
input int            Weekly_Report_DOW = 0;
input int            Weekly_Report_Hour = 21;
input int            Weekly_Report_Min = 0;
input bool           Send_Monthly_Report = true;
input int            Monthly_Report_DOM = 1;
input int            Monthly_Report_Hour = 21;
input int            Monthly_Report_Min = 0;

//---- Telegram
input string          TG_BOT_TOKEN         = "7796324180:AAFOrCfRQEj3s7vo_tl359I3eX2Jg00L8G0";
input string          TG_CHAT_ID           = "394044850";
input bool            TG_Send_Images       = false; // reserved (text only here)

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
            Trade.PositionClose(ticket, 10); // Close with 10 points of slippage tolerance
         }
      }
   }
   // Send a single alert after trying to close all
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

            if(changed && Trade.PositionModify(_Symbol, modSL, modTP))
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
      if(!(mg==Magic || (includeManual && mg==0))) continue;
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
         if(PositionGetInteger(POSITION_MAGIC)==Magic && (string)PositionGetString(POSITION_SYMBOL)==_Symbol)
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
      if((long)PositionGetInteger(POSITION_MAGIC)!=Magic) continue;
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
      if((long)OrderGetInteger(ORDER_MAGIC)   != Magic)   continue;

      long t = (long)OrderGetInteger(ORDER_TYPE);
      if(t==ORDER_TYPE_BUY_STOP || t==ORDER_TYPE_SELL_STOP) c++;
   }
   return c;
}

//============================== Indicator & Price Analysis Helpers =========================


//============================== Entry Logic =========================

   // ====================== SCALP ENTRIES ======================

void TryScalpEntries()
{
   if(!Use_Scalp_Mode) return;

   // Respect "only when no main trade" using your existing Magic-based count
   if(Scalp_Only_When_No_Main && CountOpen()>0) return;

   // Limit concurrent scalp positions (by comment tag)
   if(CountOpenByCommentSubstr("V25 Scalp") >= Scalp_Max_Concurrent) return;

   // Risk % source for non-fixed lots
   double rp = (Risk_Percent_Scalp > 0.0 ? Risk_Percent_Scalp
                                         : Risk_Percent * Scalp_Risk_Mult);

   // =========================
   // [Gate your scalps by HTF breakout]
   // =========================
   int htfDir = 0, htfAge = 0;
   if(Scalp_Gate_By_HTF)
   {
      if(!IsStrongBreakoutHTF(
            TF_Scalp_Gate_HTF,
            HTF_Breakout_Lookback,
            Scalp_ATR_Period,
            Scalp_Gate_ATR_Margin,
            0,                          // 0 = S/R OR Trendline
            HTF_Breakout_MaxAgeBars,
            htfDir, htfAge))
      {
         return; // no valid HTF breakout → skip scalps for now
      }
   }
   // =========================
   // end HTF breakout gate
   // =========================

   // ---- Read Alligator + AO on TF_Scalp
   int    ag  = AlligatorState(TF_Scalp, 1);
   double ao1 = AOValue(TF_Scalp, 1);
   double ao2 = AOValue(TF_Scalp, 2);

   bool aoUp = (ao1>0.0 && MathAbs(ao1)>=AO_Scalp_Min_Strength && ao1>=ao2);
   bool aoDn = (ao1<0.0 && MathAbs(ao1)>=AO_Scalp_Min_Strength && ao1<=ao2);

   bool buy  = (ag>0 && aoUp);
   bool sell = (ag<0 && aoDn);

   // Align to HTF breakout direction (if enabled)
   if(Scalp_Gate_By_HTF)
   {
      if(htfDir>0) sell = false;   // HTF bullish → allow only BUY scalps
      if(htfDir<0) buy  = false;   // HTF bearish → allow only SELL scalps
   }

   if(!(buy || sell)) return;

   // ---- ATR on scalp TF
   int hATR = iATR(_Symbol, TF_Scalp, Scalp_ATR_Period);
   double atr=0.0;
   if(hATR!=INVALID_HANDLE){
      double a[]; ArraySetAsSeries(a,true);
      if(CopyBuffer(hATR,0,0,3,a)>=2) atr=a[1];
      IndicatorRelease(hATR);
   }
   if(atr<=0) return;

   double ask  = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid  = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double entry= buy? ask : bid;

   // Pull swings on scalp TF (for SL anchor and Fib fallback)
   int bH,bL; double pHs,pLs;
   if(!RecentSwings(TF_Scalp, 200, bH,pHs,bL,pLs)) { pHs=iHigh(_Symbol,TF_Scalp,1); pLs=iLow(_Symbol,TF_Scalp,1); }

   // --- SL: dynamic 1..3 ATR beyond swing (if enabled), else legacy ATR mult
   double sl=0.0;
   if(Use_Dynamic_SL_ATR){
      if(buy){
         if(!PickSL_DynamicATR(true, entry, atr, pHs, pLs, SL_ATR_Min, SL_ATR_Max, SL_Swing_Pad_ATR, sl)) return;
      }else{
         if(!PickSL_DynamicATR(false, entry, atr, pHs, pLs, SL_ATR_Min, SL_ATR_Max, SL_Swing_Pad_ATR, sl)) return;
      }
   }else{
      sl = buy? (entry - Scalp_SL_ATR_Mult*atr)
              : (entry + Scalp_SL_ATR_Mult*atr);
   }

// --- TP: Use the TP from any open MAIN trade ---
double tp = 0.0;
bool tpOk = false;

// Search for an open main trade to copy its TP
for(int i = PositionsTotal() - 1; i >= 0; i--)
{
   if(PositionSelectByTicket(PositionGetTicket(i)))
   {
      if(PositionGetInteger(POSITION_MAGIC) == Magic && 
         StringFind(PositionGetString(POSITION_COMMENT), "Scalp", 0) < 0)
      {
         tp = PositionGetDouble(POSITION_TP);
         if(tp > 0)
         {
            tpOk = true;
            break; // Found one, stop searching
         }
      }
   }
}

// If no main trade was found, calculate a theoretical one
if(!tpOk)
{
   // This block calculates what a main trade's TP would be
   double pH, pL, atrMain;
   if(GetSwingsATR(TF_Trade, 300, ST_ATR_Period, pH, pL, atrMain))
   {
      // First, try to use the main RR range
      if(Use_RR_Range)
      {
         double chosenR=0, dynTP=0;
         tpOk = PickRRTarget(buy, entry, sl, atrMain, pH, pL,
                              RR_Min, RR_Max, TP_Max_ATR_Mult, TP_Swing_Ext_ATR_Mult,
                              chosenR, dynTP);
         if(tpOk) tp = dynTP;
      }
      // Fallback to main Fib if RR range fails
      if(!tpOk)
      {
         double leg = MathAbs(pH - pL);
         tp = buy ? (pH + 2.618 * leg) : (pL - 2.618 * leg);
      }
   }
}    // If tp is still 0.0, it means the trade failed both RR Range and Multi-Fib checks.
    if(tp == 0.0)
    {
        string rejectMsg = StringFormat(
            "🚫 <b>SCALP %s REJECTED</b>\n\n"
            "📊 <b>Symbol:</b> %s\n"
            "⚡ <b>Reason:</b> Failed to find TP > Min RR (%.1f)",
            buy ? "BUY" : "SELL",
            _Symbol,
            Scalp_RR_Min
        );
        SendTG(rejectMsg);
        return; // EXIT and do not place the trade
    }

// =================== START: REPLACE FROM HERE ===================

// Final safety (SanitizeStops ensures compliance with broker stop levels)
   { double ssl=sl, stp=tp; SanitizeStops(buy?POSITION_TYPE_BUY:POSITION_TYPE_SELL, ssl, stp); sl=ssl; tp=stp; }
   if( (buy && (entry - sl) <= 0) || (!buy && (sl - entry) <= 0) ) return;

   // --- HYBRID ENTRY LOGIC ---
   double jaw, teeth, lips;
   if (!GetAlligatorLines(TF_Scalp, 1, jaw, teeth, lips)) return;
   double idealEntry = lips; // Ideal entry is the Alligator Lips line

   // Define the market entry zone
   double zone = Scalp_Market_Entry_ATR_Zone * atr;
   bool inMarketZone = buy ? (entry <= idealEntry + zone) : (entry >= idealEntry - zone);

   string entryType = "";
   double entryPrice = 0.0;
   double finalSL = sl;
   double finalTP = tp;

   if(Scalp_Market_Entry_ATR_Zone > 0 && inMarketZone)
   {
      // --- Decision: Enter at MARKET ---
      entryType = "Market";
      entryPrice = entry; // Use current market price
   }
   else
   {
      // --- Decision: Place LIMIT order ---
      entryType = "Limit";
      entryPrice = idealEntry;

      // Recalculate SL based on the new limitPrice entry for accuracy
      finalSL = buy ? (entryPrice - MathAbs(entry - sl)) : (entryPrice + MathAbs(sl - entry));
      // Recalculate TP based on the new limitPrice entry
      finalTP = buy ? (entryPrice + MathAbs(tp - entry)) : (entryPrice - MathAbs(entry - tp));

      // --- SAFETY CHECKS for Limit Order ---
      if (buy && finalSL >= entryPrice) finalSL = entryPrice - 2.0 * atr;
      if (!buy && finalSL <= entryPrice) finalSL = entryPrice + 2.0 * atr;
      
      SanitizeStops(buy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, finalSL, finalTP);
   }

   // --- Lot Sizing (based on the determined entry price) ---
   double riskPtsForLots = buy ? (entryPrice - finalSL) / _Point : (finalSL - entryPrice) / _Point;
   if (riskPtsForLots <= MinStopPoints()) return; // Risk is too small or invalid

   bool   useFixedLot = Scalp_Use_Fixed_Lot;
   double fixedLots   = (Fixed_Lots_Scalp > 0.0 ? Fixed_Lots_Scalp : Fixed_Lots);
   double lots = useFixedLot ? NormalizeVolume(fixedLots) : LotsByRisk(rp, riskPtsForLots);

   // --- Send Signal & Execute Trade ---
   Trade.SetExpertMagicNumber(Magic);
   bool sent = false;

   string signalType = buy ? "🟢 SCALP BUY SIGNAL 🟢" : "🔴 SCALP SELL SIGNAL 🔴";
   string signalMsg = StringFormat(
      "<b>%s</b> (%s)\n\n"
      "📊 <b>Symbol:</b> %s\n"
      "⏰ <b>Timeframe:</b> %s\n"
      "💰 <b>Entry Price:</b> %s\n"
      "⚡ <b>Strategy:</b> Scalp\n\n"
      "<i>Preparing to execute trade...</i>",
      signalType, entryType,
      _Symbol,
      tfstr(TF_Scalp),
      DoubleToString(entryPrice, _Digits)
   );
   SendTG(signalMsg);

   if (Auto_Trade)
   {
      if (entryType == "Market")
      {
         if (buy) sent = Trade.Buy(lots, _Symbol, 0, finalSL, finalTP, "V25 Scalp Buy");
         else sent = Trade.Sell(lots, _Symbol, 0, finalSL, finalTP, "V25 Scalp Sell");
      }
      else // "Limit"
      {
         datetime expiration = TimeCurrent() + (Scalp_StopEntry_Expiry_Bars * PeriodSeconds(TF_Scalp));
         if (buy) sent = Trade.BuyLimit(lots, entryPrice, _Symbol, finalSL, finalTP, ORDER_TIME_SPECIFIED, expiration, "V25 Scalp Buy Limit");
         else sent = Trade.SellLimit(lots, entryPrice, _Symbol, finalSL, finalTP, ORDER_TIME_SPECIFIED, expiration, "V25 Scalp Sell Limit");
      }
   }
}
// =================== END: REPLACE TO HERE ===================
   // ====================== EA Entries ======================
void TryEntries()
{
   // ====================== PER-BAR + COOLDOWN GUARDS ======================
   static datetime lastEvalBar = 0;
   datetime barTime = iTime(_Symbol, TF_Trade, 0);
   if(barTime == lastEvalBar) return;             // evaluate once per bar max
   lastEvalBar = barTime;

   if(lastTradeBarTime!=0 && (barTime - lastTradeBarTime) < (long)PeriodSeconds(TF_Trade)*Cooldown_Bars)
      return; // enforce N-bar cooldown after a fill
   // ======================================================================

   // Cooldown after last trade bar (legacy guard)
   if(lastTradeBarTime == barTime) return;

   // ================================ FILTERS ==============================
   double stLineM15=0, stLineH1=0, stLineH4=0;
   int    dirM15=0, dirH1=0, dirH4=0;

   if(!CalcSuperTrend(TF_Trade, ST_ATR_Period, ST_ATR_Mult, 1, stLineM15, dirM15)) return;
   if(Use_H1H4_Filter)
   {
      if(!CalcSuperTrend(PERIOD_H1, ST_ATR_Period, ST_ATR_Mult, 1, stLineH1, dirH1)) return;
      if(!CalcSuperTrend(PERIOD_H4, ST_ATR_Period, ST_ATR_Mult, 1, stLineH4, dirH4)) return;
   }

   int    ag = AlligatorState(TF_Trade,1);
   double ao = AOValue(TF_Trade,1);
   double w  = WPRValue(TF_Trade,1);
   double c  = iClose(_Symbol, TF_Trade, 1);

   bool hOK = (!Use_H1H4_Filter) || (dirH1==dirM15 && dirH4==dirM15);

   // Williams %R gating
   bool wBuyOK  = !Use_WPR_Bias || (w > -50.0);
   bool wSellOK = !Use_WPR_Bias || (w < -50.0);
   if(Use_WPR_Cross)
   {
      double wPrev = WPRValue(TF_Trade,2);
      wBuyOK  = (wPrev < -80.0 && w > -80.0);
      wSellOK = (wPrev > -20.0 && w < -20.0);
   }

   // --- Detect fresh ST flip and reset staging
   if(Use_ST_Flip_Retest){
      if(dirM15!=0 && dirM15!=prevDir_ST){
         flipBar    = iTime(_Symbol, TF_Trade, 1); // last closed bar
         stageCount = 0;
      }
      prevDir_ST = dirM15;
   }

   // --- Wait N bars after flip (anti-early)
   bool flipWaitOK = true;
   if(Use_ST_Flip_Retest && flipBar!=0){
      int barsSinceFlip = (int)((iTime(_Symbol,TF_Trade,1) - flipBar) / (long)PeriodSeconds(TF_Trade));
      flipWaitOK = (barsSinceFlip >= Min_Bars_After_Flip);
   }

   bool aoBuyOK  = (ao > 0.0 && MathAbs(ao) >= AO_Min_Strength);
   bool aoSellOK = (ao < 0.0 && MathAbs(ao) >= AO_Min_Strength);

   // Raw signal conditions (before HTF gate)
   bool buyCond  = (dirM15>0 && ag>0 && aoBuyOK && wBuyOK && hOK && c>stLineM15);
   bool sellCond = (dirM15<0 && ag<0 && aoSellOK && wSellOK && hOK && c<stLineM15);

   // ======================= HTF BREAKOUT GATE (UPDATED) ===================
   {
      // Auto-map: M15 entries gate by H4; H1 entries gate by D1
      ENUM_TIMEFRAMES tfHTF = PERIOD_H4;
      if(TF_Trade==PERIOD_H1)  tfHTF = PERIOD_D1;
      else if(TF_Trade==PERIOD_M15) tfHTF = PERIOD_H4;

      int bH_htf, bL_htf; double pH_htf, pL_htf;
      if(!RecentSwings(tfHTF, 600, bH_htf, pH_htf, bL_htf, pL_htf)) return;

      double atrHTF = 0.0;
      int hATR_htf = iATR(_Symbol, tfHTF, ST_ATR_Period);
      if(hATR_htf!=INVALID_HANDLE)
      {
         double ahtf[]; ArraySetAsSeries(ahtf,true);
         if(CopyBuffer(hATR_htf,0,0,3,ahtf)>=2) atrHTF = ahtf[1];
         IndicatorRelease(hATR_htf);
      }
      if(atrHTF<=0.0) return;

      double cHTF = iClose(_Symbol, tfHTF, 1);
      double mHTF = Breakout_ATR_Margin * atrHTF;

      bool htfBuyOK  = (cHTF >= (pH_htf + mHTF));
      bool htfSellOK = (cHTF <= (pL_htf - mHTF));

      buyCond  = buyCond  && htfBuyOK;
      sellCond = sellCond && htfSellOK;
      if(!buyCond && !sellCond) return;  // gate failed
   }
   // ======================================================================

   // One position at a time (per symbol/magic)
   if(One_Trade_At_A_Time && CountOpen()>0)
   {
        string rejectMsg = StringFormat(
            "🚫 <b>TRADE REJECTED - Max Positions</b>\n\n"
            "⏰ <b>Timeframe:</b> %s\n"
            "📊 <b>Symbol:</b> %s\n"
            "📈 <b>Current Positions:</b> %d\n"
            "📉 <b>Max Allowed:</b> 1\n"
            "⚡ <b>Signal:</b> %s",
            _Symbol,
            CountOpen(),
            buyCond ? "BUY" : (sellCond ? "SELL" : "N/A")
        );
        SendTG(rejectMsg);
        return;
   }
   // =========================== BUILD SL / TP ============================
   if(buyCond || sellCond)
   {
      int bH; double pH; int bL; double pL;
      if(!RecentSwings(TF_Trade, 300, bH,pH,bL,pL)) return;

      // ATR on trade TF
      int hATR = iATR(_Symbol, TF_Trade, ST_ATR_Period);
      double atr=0.0;
      if(hATR!=INVALID_HANDLE)
      {
         double a[]; ArraySetAsSeries(a,true);
         if(CopyBuffer(hATR,0,0,3,a)>=2) atr = a[1];
         IndicatorRelease(hATR);
      }
      if(atr<=0.0) return;

      double sl=0, tp=0;
      double ask=SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid=SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // ================================ BUY ===============================
      if(buyCond)
      {
         double entry = ask;

         // --- SL: dynamic ATR window (1..3 ATR) beyond swing low (fallback = old swing SL)
         if(Use_Dynamic_SL_ATR){
            if(!PickSL_DynamicATR(true, entry, atr, pH, pL, SL_ATR_Min, SL_ATR_Max, SL_Swing_Pad_ATR, sl))
               return;
         }else{
            sl = pL - ATR_SL_Buffer_Mult * atr;
         }

         // --- TP: try RR range; if no valid, FALLBACK TO FIB (no single RR)
         bool tpOk=false;
         if(Use_RR_Range){
            double chosenR=0, dynTP=0;
            tpOk = PickRRTarget(true, entry, sl, atr, pH, pL,
                                RR_Min, RR_Max, TP_Max_ATR_Mult, TP_Swing_Ext_ATR_Mult,
                                chosenR, dynTP);
            if(tpOk) tp = dynTP;
         }
         if(!tpOk){
            double leg = MathAbs(pH - pL);
            tp = pH + 2.618 * leg; // Fib fallback
         }

         // ======= FRESH FLIP + RETEST + CONFIRM (BUY) =======
         bool allowStage=false;
         if(!Use_ST_Flip_Retest){
            allowStage=true; // legacy immediate entry
         }else{
            double tol = Retest_ATR_Tolerance * atr;
            bool retestTouch = (iLow(_Symbol, TF_Trade, 1) <= stLineM15 + tol);
            bool confirmAway = (c >= stLineM15 + Confirm_Close_Dist_ATR * atr);
            bool confirmOk   = (ag>0 && aoBuyOK && wBuyOK && hOK && confirmAway && flipWaitOK);

            if(stageCount==0) allowStage = (retestTouch && confirmOk);
            else{
               ulong tk; double e0, sl0; bool nearSL=false;
               if(GetLatestOpenPos(+1, true, tk, e0, sl0))
                  nearSL = ReachedRatioToSL(+1, e0, sl0, AddEntry_Trigger_Ratio);
               allowStage = (retestTouch && confirmOk && nearSL);
            }
         }
         if(!allowStage || stageCount>=Max_Entry_Stages) return;

         // --- Push SL beyond SuperTrend (more conservative)
         if(Use_ST_as_Stop){
            double stPad = ST_Stop_Pad_Mult * atr;
            sl = MathMin(sl, stLineM15 - stPad);
            // minimum SL distance guard
            double minPtsBuy = MathMax((int)Min_SL_Points, (int)MathRound((Min_SL_ATR_Mult*atr)/_Point));
            if( ((entry - sl)/_Point) < minPtsBuy ) return;
         }

         // --- sanitize & final guards
         { double ssl=sl, stp=tp; SanitizeStops(POSITION_TYPE_BUY, ssl, stp); sl=ssl; tp=stp; }
         if((entry - sl) <= 0) return;

         // --- Optional retrace-or-breakout gate (micro TF)
         if(Require_Retrace_Or_Breakout)
         {
            double tolX = Retest_ATR_Tolerance * atr;
            bool retraceOK = (iLow(_Symbol, TF_Trade, 1) <= stLineM15 + tolX);
            bool breakoutOK = (c >= (pH + Breakout_ATR_Margin * atr));
            if(!(retraceOK || breakoutOK)) return;
         }

         // --- Send
         SendTG(StringFormat("📈 <b>BUY Setup</b> %s %s\nST:%s  Alligator:bull  AO:%.2f  WPR:%.1f\nEntry: %.2f  SL: %.2f  TP: %.2f",
                             _Symbol, tfstr(TF_Trade), "UP", ao, w, entry, sl, tp));

         if(Auto_Trade)
         {
            Trade.SetExpertMagicNumber(Magic);
            bool sent=false;
            double msgEntryPrice = entry;

            if(Use_Pending_Stop_Entries)
            {
               if(CountPendingThisEA()>0) return;
               double hi1 = iHigh(_Symbol, TF_Trade, 1);
               double stopPrice = hi1 + StopEntry_Offset_ATR * atr;
               double riskPtsForLots = (stopPrice - sl) / _Point;
               double lots = LotsByRisk(Risk_Percent, riskPtsForLots);
               msgEntryPrice = stopPrice;

               datetime expiration_buy = TimeCurrent();
               expiration_buy += (StopEntry_Expiry_Bars * PeriodSeconds(TF_Trade));

               sent = Trade.BuyStop(lots, stopPrice, _Symbol, sl, tp,
                                    ORDER_TIME_SPECIFIED, expiration_buy, "V25 BuyStop");

                        string buySignalMsg = StringFormat(
            "🟢 <b>BUY SIGNAL DETECTED</b> 🟢\n\n"
            "📊 <b>Symbol:</b> %s\n"
            "⏰ <b>Timeframe:</b> %s\n"
            "💰 <b>Current Price:</b> %s\n"
            "📈 <b>SuperTrend:</b> %s\n"
            "⚡ <b>Strategy:</b> Main Trend\n\n"
            "<i>Preparing to execute trade...</i>",
            _Symbol,
            tfstr(TF_Trade),
            DoubleToString(entry, _Digits),
            DoubleToString(stLineM15, _Digits)
         );
         SendTG(buySignalMsg);
            }
            else
            {
               double lots = LotsByRisk(Risk_Percent, (entry - sl)/_Point);
               sent = Trade.Buy(lots, _Symbol, entry, sl, tp, "V25 Buy");
            }

            if(sent)
            {
               SendTG(StringFormat("[📈 BUY placed\nEntry %.2f\nSL %.2f\nTP %.2f]", msgEntryPrice, sl, tp));
               lastTradeBarTime = iTime(_Symbol, TF_Trade, 0);
               stageCount = MathMin(stageCount+1, Max_Entry_Stages);
               lastStageBar = iTime(_Symbol, TF_Trade, 0);
               if(Adjust_All_To_Latest) ApplySLTPToAllOpen(+1, sl, tp);
            }
            else
            {
               SendTG(StringFormat("❌ BUY send failed: ret=%d", Trade.ResultRetcode()));
            }
         }
      }
      // =============================== SELL ===============================
      else if(sellCond)
      {
         double entry = bid;

         // --- SL: dynamic ATR window (1..3 ATR) beyond swing high (fallback = old swing SL)
         if(Use_Dynamic_SL_ATR){
            if(!PickSL_DynamicATR(false, entry, atr, pH, pL, SL_ATR_Min, SL_ATR_Max, SL_Swing_Pad_ATR, sl))
               return;
         }else{
            sl = pH + ATR_SL_Buffer_Mult * atr;
         }

         // --- TP: try RR range; if no valid, FALLBACK TO FIB (no single RR)
         bool tpOk=false;
         if(Use_RR_Range){
            double chosenR=0, dynTP=0;
            tpOk = PickRRTarget(false, entry, sl, atr, pH, pL,
                                RR_Min, RR_Max, TP_Max_ATR_Mult, TP_Swing_Ext_ATR_Mult,
                                chosenR, dynTP);
            if(tpOk) tp = dynTP;
         }
         if(!tpOk){
            double leg = MathAbs(pH - pL);
            tp = pL - 2.618 * leg; // Fib fallback
         }

         // ======= FRESH FLIP + RETEST + CONFIRM (SELL) =======
         bool allowStage=false;
         if(!Use_ST_Flip_Retest){
            allowStage=true;
         }else{
            double tol = Retest_ATR_Tolerance * atr;
            bool retestTouch = (iHigh(_Symbol, TF_Trade, 1) >= stLineM15 - tol);
            bool confirmAway = (c <= stLineM15 - Confirm_Close_Dist_ATR * atr);
            bool confirmOk   = (ag<0 && aoSellOK && wSellOK && hOK && confirmAway && flipWaitOK);

            if(stageCount==0) allowStage = (retestTouch && confirmOk);
            else{
               ulong tk; double e0, sl0; bool nearSL=false;
               if(GetLatestOpenPos(-1, true, tk, e0, sl0))
                  nearSL = ReachedRatioToSL(-1, e0, sl0, AddEntry_Trigger_Ratio);
               allowStage = (retestTouch && confirmOk && nearSL);
            }
         }
         if(!allowStage || stageCount>=Max_Entry_Stages) return;

         // --- Push SL beyond SuperTrend (more conservative)
         if(Use_ST_as_Stop){
            double stPad = ST_Stop_Pad_Mult * atr;
            sl = MathMax(sl, stLineM15 + stPad);
         }
         // minimum SL distance guard
         {
            double minPtsSell = MathMax((int)Min_SL_Points, (int)MathRound((Min_SL_ATR_Mult*atr)/_Point));
            if( ((sl - entry)/_Point) < minPtsSell ) return;
         }

         // --- sanitize & final guards
         { double ssl=sl, stp=tp; SanitizeStops(POSITION_TYPE_SELL, ssl, stp); sl=ssl; tp=stp; }
         if((sl - entry) <= 0) return;

         // --- Optional retrace-or-breakout gate (micro TF)
         if(Require_Retrace_Or_Breakout)
         {
            double tolX = Retest_ATR_Tolerance * atr;
            bool retraceOK = (iHigh(_Symbol, TF_Trade, 1) >= stLineM15 - tolX);
            bool breakoutOK = (c <= (pL - Breakout_ATR_Margin * atr));
            if(!(retraceOK || breakoutOK)) return;
         }

         // --- Send
         SendTG(StringFormat("📉 <b>SELL Setup</b> %s %s\nST:%s  Alligator:bear  AO:%.2f  WPR:%.1f\nEntry: %.2f  SL: %.2f  TP: %.2f",
                             _Symbol, tfstr(TF_Trade), "DOWN", ao, w, entry, sl, tp));

         if(Auto_Trade)
         {
            Trade.SetExpertMagicNumber(Magic);
            bool sent=false;
            double msgEntryPrice = entry;

            if(Use_Pending_Stop_Entries)
            {
               if(CountPendingThisEA()>0) return;
               double lo1 = iLow(_Symbol, TF_Trade, 1);
               double stopPrice = lo1 - StopEntry_Offset_ATR * atr;
               double riskPtsForLots = (sl - stopPrice) / _Point;
               double lots = LotsByRisk(Risk_Percent, riskPtsForLots);
               msgEntryPrice = stopPrice;

               datetime expiration_sell = TimeCurrent();
               expiration_sell += (StopEntry_Expiry_Bars * PeriodSeconds(TF_Trade));

               sent = Trade.SellStop(lots, stopPrice, _Symbol, sl, tp,
                                     ORDER_TIME_SPECIFIED, expiration_sell, "V25 SellStop");

                        string sellSignalMsg = StringFormat(
            "🔴 <b>SELL SIGNAL DETECTED</b> 🔴\n\n"
            "📊 <b>Symbol:</b> %s\n"
            "⏰ <b>Timeframe:</b> %s\n"
            "💰 <b>Current Price:</b> %s\n"
            "📉 <b>SuperTrend:</b> %s\n"
            "⚡ <b>Strategy:</b> Main Trend\n\n"
            "<i>Preparing to execute trade...</i>",
            _Symbol,
            tfstr(TF_Trade),
            DoubleToString(entry, _Digits),
            DoubleToString(stLineM15, _Digits)
         );
         SendTG(sellSignalMsg);
            }
            else
            {
               double lots = LotsByRisk(Risk_Percent, (sl - entry)/_Point);
               sent = Trade.Sell(lots, _Symbol, entry, sl, tp, "V25 Sell");
            }

            if(sent)
            {
               SendTG(StringFormat("[📉 SELL placed\nEntry %.2f\nSL %.2f\nTP %.2f]", msgEntryPrice, sl, tp));
               lastTradeBarTime = iTime(_Symbol, TF_Trade, 0);
               stageCount = MathMin(stageCount+1, Max_Entry_Stages);
               lastStageBar = iTime(_Symbol, TF_Trade, 0);
               if(Adjust_All_To_Latest) ApplySLTPToAllOpen(-1, sl, tp);
            }
            else
            {
               SendTG(StringFormat("❌ SELL send failed: ret=%d", Trade.ResultRetcode()));
            }
         }
      }
   }
}

// Apply breakeven & trailing for open positions
void ManageOpenPositions()
{
   int total = PositionsTotal();
   for(int p=0; p<total; ++p)
   {
      ulong ticket = PositionGetTicket(p);
      if(!PositionSelectByTicket(ticket)) continue;

      string sym = (string)PositionGetString(POSITION_SYMBOL);
      if(sym != _Symbol) continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      bool isEA      = (magic==Magic);
      bool isManual  = (magic==0);

      if(!(isEA || (ApplyToManualTrades && isManual))) continue;

      long   type  = PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);

      double cur = (type==POSITION_TYPE_BUY)
                   ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      string pcomment = (string)PositionGetString(POSITION_COMMENT);
      bool   isScalp  = (StringFind(pcomment,"Scalp",0) >= 0);
      if(Protect_Scalp_SLTP && isScalp) continue;  // skip all SL/TP changes for scalps

// --- Breakeven (BE) & Protection Logic (Percentage Only) ---
// Note: BE_Activation_TP_Percent must be > 0.0 to enable this block.
if(BE_Activation_TP_Percent > 0.0 && tp > 0.0 && sl > 0.0) 
{
    // Define a tiny buffer to guarantee the modification is an 'improvement' to the broker
    const double BE_Buffer = 100.0 * _Point; // Move SL to entry + 1 Point (guaranteed improvement)

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
            // Calculate the new Breakeven SL with a small guaranteed profit buffer
            double targetBE = (type == POSITION_TYPE_BUY) ?
                              (entry + BE_Buffer) : (entry - BE_Buffer);

            // Only modify if the current SL is NOT already past the targetBE level
            bool needsMove = (type == POSITION_TYPE_BUY && sl < targetBE) ||
                             (type == POSITION_TYPE_SELL && sl > targetBE);
            
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

            if(targetPts>0 && progressPts>0)
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
               if(progress < 0.0) progress = 0.0;
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
                  if(trail<sl || sl==0.0) // allow first set
                  {
                     double modSL=trail, modTP=tp;
                     SanitizeStops(type, modSL, modTP);
                     if(modSL>0 && (sl==0.0 || MathAbs(modSL-sl) >= 0.5*_Point))
                        {
   if(Trade.PositionModify(_Symbol, modSL, modTP))
   {
      g_trailingActivated = true; // <-- ADD THIS LINE
   }
}
                  }
               }
            }
            IndicatorRelease(hATR);
         }
      }
      // [INSERT THIS BLOCK BEFORE LINE 810 (BE/Protection Logic)]

        // --- Aggressive Trend Change Exit (New Requirement) ---
        // Exits the trade immediately if the SuperTrend on the trade TF flips.
        double currentSTLine = 0.0;
        int    currentSTDir = 0;
        
        // Use ST settings from inputs (ST_ATR_Period, ST_ATR_Mult)
        if (CalcSuperTrend(TF_Trade, ST_ATR_Period, ST_ATR_Mult, 1, currentSTLine, currentSTDir))
        {
            int requiredDir = (type == POSITION_TYPE_BUY) ? +1 : -1;
            
            // Exit if the SuperTrend flips against the trade direction
            if (currentSTDir != requiredDir)
            {
                // Trend flip detected: Close the position aggressively
                if (Trade.PositionClose(ticket))
                {
                    SendTG(StringFormat("🛑 %s closed: Trend flip detected on %s. Exit price %.2f",
                                        pcomment, tfstr(TF_Trade), cur));
                    continue; // Position closed, move to next position
                }
            }
        }
        // --- End Aggressive Trend Change Exit ---
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
   string body =
      StringFormat("[ %s\nPeriod: %s → %s\n\nTotal: %d trades | WinRate %.1f%% | Net %.2f\n"
                   "Main:  %d trades | WR %.1f%% | Net %.2f\n"
                   "Scalp: %d trades | WR %.1f%% | Net %.2f\n"
                   "Best:  %.2f   Worst: %.2f ]",
         hdr,
         TimeToString(fromTs, TIME_DATE|TIME_MINUTES),
         TimeToString(toTs,   TIME_DATE|TIME_MINUTES),
         totN, wr, totNet,
         mainN, wrMain, mainNet,
         scalpN, wrScalp, scalpNet,
         best, worst);

   SendTG(body);
}

// REPLACEMENT FOR OnTick() FUNCTION
// REPLACEMENT FOR OnTick() FUNCTION
void OnTick()
{
   // --- Part 1: Logic that runs on EVERY tick (Circuit Breaker) ---
   if(Use_Volatility_CircuitBreaker)
   {
      // Cooldown timer to prevent it from firing repeatedly on the same candle
      static datetime lastBreakerTripTime = 0;
      if(TimeCurrent() - lastBreakerTripTime < 60) // 60-second cooldown
      {
         return; // Still in cooldown, do nothing
      }

      // Get current candle size and ATR on the main trading timeframe
      double high0 = iHigh(_Symbol, TF_Trade, 0);
      double low0  = iLow(_Symbol, TF_Trade, 0);
      double candleSize = high0 - low0;

      double atr = 0;
      int hATR = iATR(_Symbol, TF_Trade, ST_ATR_Period);
      if(hATR != INVALID_HANDLE)
      {
         double a[];
         if(CopyBuffer(hATR, 0, 1, 1, a) > 0) atr = a[0];
         IndicatorRelease(hATR);
      }

      // Check if the circuit breaker condition is met
      if(atr > 0 && candleSize > (atr * CircuitBreaker_ATR_Mult))
      {
         if(PositionsTotal() > 0) // Only fire if there are open positions
         {
            EmergencyCloseAllPositions("Extreme candle volatility detected.");
            lastBreakerTripTime = TimeCurrent(); // Start the cooldown
            return; // Stop further processing on this tick
         }
      }
   }

   // --- Part 2: Your original logic that runs ONCE per new bar ---
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, TF_Trade, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;

      // Check for main strategy entries.
      TryEntries();
      
      // Check for scalp entries
      static datetime lastScalpBarTime = 0;
      if(Use_Scalp_Mode)
      {
          datetime currentScalpBarTime = iTime(_Symbol, TF_Scalp, 0);
          if(currentScalpBarTime != lastScalpBarTime)
          {
              lastScalpBarTime = currentScalpBarTime;
              TryScalpEntries();
          }
      }

      // Manage all other per-bar tasks
      TouchUpManualInitial();
      ManageOpenPositions();
   }
}

// REPLACEMENT FOR OnTimer() FUNCTION
void OnTimer()
{
   datetime now = TimeCurrent();
   MqlDateTime st; TimeToStruct(now, st);

   // --- 9. SCHEDULED REPORTS (WEEKLY)
   if(Send_Weekly_Report)
   {
      bool dow_ok = (st.day_of_week == Weekly_Report_DOW);
      bool time_ok= (st.hour==Weekly_Report_Hour && st.min>=Weekly_Report_Min);
      bool gap_ok = (now - g_lastWeeklyReportSent) > (5*24*60*60); // prevent duplicates
      if(dow_ok && time_ok && gap_ok)
      {
         string weeklyReport = StringFormat(
            "📊 <b>WEEKLY REPORT</b>\n\n"
            "📈 <b>EA Status:</b> Active\n"
            "💼 <b>Main Strategy:</b> ENABLED\n"
            "⚡ <b>Scalp Strategy:</b> %s\n"
            "📊 <b>Symbol:</b> %s\n\n"
            "<i>All systems operational</i>",
            Use_Scalp_Mode ? "ENABLED" : "DISABLED",
            _Symbol
         );
         SendTG(weeklyReport);
         g_lastWeeklyReportSent = now;
      }
   }

   // --- 9. SCHEDULED REPORTS (MONTHLY)
   if(Send_Monthly_Report)
   {
      bool dom_ok = (st.day == Monthly_Report_DOM);
      bool time_ok= (st.hour==Monthly_Report_Hour && st.min>=Monthly_Report_Min);
      bool gap_ok = (now - g_lastMonthlyReportSent) > (25*24*60*60);
      if(dom_ok && time_ok && gap_ok)
      {
         string monthlyReport = StringFormat(
            "📈 <b>MONTHLY REPORT</b>\n\n"
            "✅ <b>EA Status:</b> Running Smoothly\n"
            "📊 <b>Symbol:</b> %s\n"
            "⏰ <b>Active Since:</b> %s\n\n"
            "<i>Continuing market monitoring</i>",
            _Symbol,
            TimeToString(g_eaStartTime, TIME_DATE|TIME_SECONDS)
         );
         SendTG(monthlyReport);
         g_lastMonthlyReportSent = now;
      }
   }
}


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

      // --- A) POSITION OPENED (FILL) ---
      if(entryType == DEAL_ENTRY_IN)
      {
         long mg = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
         if(mg != Magic) return; // Only this EA's trades

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
         if(mg != Magic) return;

         double P    = HistoryDealGetDouble (deal, DEAL_PROFIT);
         double F    = HistoryDealGetDouble (deal, DEAL_FEE);
         double C    = HistoryDealGetDouble (deal, DEAL_COMMISSION);
         double S    = HistoryDealGetDouble (deal, DEAL_SWAP);
         double net  = P + F + C + S;
         string cmt  = (string)HistoryDealGetString(deal, DEAL_COMMENT);
         
         // --- ERROR FIX: Declare entryPrice here so it's available for the alert message ---
         double entryPrice = 0.0;
         ulong posID_closed = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
         if (posID_closed > 0)
         {
             for (int i = HistoryDealsTotal() - 1; i >= 0; i--)
             {
                 ulong d_ticket = HistoryDealGetTicket(i);
                 if (HistoryDealGetInteger(d_ticket, DEAL_POSITION_ID) == posID_closed &&
                     HistoryDealGetInteger(d_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
                 {
                     entryPrice = HistoryDealGetDouble(d_ticket, DEAL_PRICE);
                     break; 
                 }
             }
         }

         string reason = "Closed by TP/SL";
         if (cmt == "") reason = "Closed Manually";
         
         string closeMsg = StringFormat(
            "%s <b>POSITION CLOSED</b>\n\n"
            "📊 <b>Symbol:</b> %s\n"
            "💰 <b>Entry:</b> %s\n"
            "💰 <b>Profit/Loss:</b> %s%.2f\n"
            "⚡ <b>Reason:</b> %s",
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
      if(req.magic == Magic)
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
