//+------------------------------------------------------------------+
//|                                          PriceBox_Breakout.mq5 |
//|                                    Copyright 2025, LanreEnlight  |
//|                                       https://www.youtube.com/@lanreenlight |
//+------------------------------------------------------------------+
#property copyright "LanreEnlight"
#property link      "https://www.youtube.com/@lanreenlight"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "--- Strategy Settings ---"
input double   InpLotSize        = 0.10;     // Fixed Lot Size
input int      InpMagicNumber    = 998877;   // Magic Number
input int      InpSlippage       = 3;        // Slippage Deviation

input group "--- Price Box Logic ---"
input int      InpBoxPeriod      = 10;       // Box Lookback (Candles)
input double   InpBoxRangeMult   = 1.5;      // Max Range (xATR) to form a Box
input int      InpATR_Period     = 14;       // ATR Period for volatility calc

input group "--- Risk Management ---"
input double   InpStopLossATR    = 2.0;      // Initial SL (xATR)
input double   InpTakeProfitATR  = 4.0;      // Take Profit (xATR) - 0 to disable
input bool     InpEnableTrailing = true;     // Enable ATR Trailing
input double   InpTrailATR       = 2.0;      // Trailing Distance (xATR)

//--- Global Variables
CTrade         trade;
double         currentATRValue;
datetime       lastBarTime;

// Box State Variables
bool           gl_BoxActive = false;
double         gl_BoxHigh   = 0.0;
double         gl_BoxLow    = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   Print("System Initialized: Price Box Breakout Strategy.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "Lanre_Box_");
   Comment("");
   Print("System Shutting Down.");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // --- 1. Manage Trailing Stop (Real-time) ---
   currentATRValue = CalculateManualATR(InpATR_Period);
   ManageTrailingStop();

   // --- Dashboard ---
   string status = gl_BoxActive ? "WAITING FOR BREAKOUT" : "SCANNING FOR SQUEEZE";
   string dash = "LanreEnlight Box Breakout\n" +
                 "-------------------------\n" +
                 "Status: " + status + "\n" +
                 "Current ATR: " + DoubleToString(currentATRValue, _Digits) + "\n" +
                 "Box High: " + (gl_BoxActive ? DoubleToString(gl_BoxHigh, _Digits) : "-") + "\n" +
                 "Box Low:  " + (gl_BoxActive ? DoubleToString(gl_BoxLow, _Digits) : "-");
   Comment(dash);

   // --- 2. Check for New Bar (Entry Logic Only) ---
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(lastBarTime == currentBarTime) return; 
   lastBarTime = currentBarTime;

   // --- 3. Box Logic Execution ---
   
   // A. If Box is Active, Check for Breakout
   if (gl_BoxActive)
   {
      CheckForBreakout();
   }
   // B. If No Box, Scan for new Squeeze
   else
   {
      ScanForNewBox();
   }
  }

//+------------------------------------------------------------------+
//| Logic: Scan for Tight Ranges                                     |
//+------------------------------------------------------------------+
void ScanForNewBox()
{
   // Only scan if we have no open trades (One trade at a time for focus)
   if (PositionsTotal() > 0) return;

   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   if (CopyHigh(_Symbol, _Period, 1, InpBoxPeriod, highs) < InpBoxPeriod) return;
   if (CopyLow(_Symbol, _Period, 1, InpBoxPeriod, lows) < InpBoxPeriod) return;
   
   double maxH = -DBL_MAX;
   double minL = DBL_MAX;
   
   // Find Range of last X candles
   for(int i=0; i<InpBoxPeriod; i++)
   {
      if (highs[i] > maxH) maxH = highs[i];
      if (lows[i] < minL) minL = lows[i];
   }
   
   double range = maxH - minL;
   double threshold = currentATRValue * InpBoxRangeMult;
   
   // Condition: Range is smaller than Volatility Threshold
   if (range < threshold)
   {
      gl_BoxActive = true;
      gl_BoxHigh = maxH;
      gl_BoxLow = minL;
      DrawBoxLines(gl_BoxHigh, gl_BoxLow);
      Print("New Price Box Detected. Waiting for Breakout. Range: ", range);
   }
}

//+------------------------------------------------------------------+
//| Logic: Check for Breakout of Active Box                          |
//+------------------------------------------------------------------+
void CheckForBreakout()
{
   double close1[];
   ArraySetAsSeries(close1, true);
   if(CopyClose(_Symbol, _Period, 1, 1, close1) < 1) return;
   
   double closePrice = close1[0];
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   bool breakoutUp = closePrice > gl_BoxHigh;
   bool breakoutDown = closePrice < gl_BoxLow;
   
   if (breakoutUp || breakoutDown)
   {
      // --- Volume Normalization ---
      double tradeLot = NormalizeVolume(InpLotSize);
      
      // Calculate SL/TP
      double slDist = currentATRValue * InpStopLossATR;
      double tpDist = currentATRValue * InpTakeProfitATR;
      
      if (breakoutUp)
      {
         double sl = ask - slDist;
         double tp = (InpTakeProfitATR > 0) ? ask + tpDist : 0;
         if (trade.Buy(tradeLot, _Symbol, ask, sl, tp, "Lanre Box Breakout Buy"))
         {
            Print("Breakout UP! Box cleared.");
            ResetBox();
         }
      }
      else if (breakoutDown)
      {
         double sl = bid + slDist;
         double tp = (InpTakeProfitATR > 0) ? bid - tpDist : 0;
         if (trade.Sell(tradeLot, _Symbol, bid, sl, tp, "Lanre Box Breakout Sell"))
         {
            Print("Breakout DOWN! Box cleared.");
            ResetBox();
         }
      }
   }
   else
   {
      // Still trapped -> Refresh Lines
      DrawBoxLines(gl_BoxHigh, gl_BoxLow);
   }
}

//+------------------------------------------------------------------+
//| Helper: Reset Box State                                          |
//+------------------------------------------------------------------+
void ResetBox()
{
   gl_BoxActive = false;
   gl_BoxHigh = 0.0;
   gl_BoxLow = 0.0;
   ObjectsDeleteAll(0, "Lanre_Box_");
}

//+------------------------------------------------------------------+
//| Helper: Manage Trailing Stop                                     |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!InpEnableTrailing || PositionsTotal() == 0) return;
   
   double trailDist = currentATRValue * InpTrailATR;
   
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         
         long type = PositionGetInteger(POSITION_TYPE);
         double currentSL = PositionGetDouble(POSITION_SL);
         double newSL = 0.0;
         bool modify = false;
         
         if(type == POSITION_TYPE_BUY)
         {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double potential = bid - trailDist;
            if(potential > currentSL && potential < bid) { newSL = potential; modify = true; }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double potential = ask + trailDist;
            if((potential < currentSL || currentSL == 0) && potential > ask) { newSL = potential; modify = true; }
         }
         
         if(modify)
         {
            long digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            trade.PositionModify(ticket, NormalizeDouble(newSL, (int)digits), PositionGetDouble(POSITION_TP));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Helper: Calculate ATR Manually                                   |
//+------------------------------------------------------------------+
double CalculateManualATR(int period)
{
   double High[], Low[], Close[];
   ArraySetAsSeries(High, true); ArraySetAsSeries(Low, true); ArraySetAsSeries(Close, true);
   
   if(CopyHigh(_Symbol, _Period, 0, period+1, High) < period+1) return 0.0;
   if(CopyLow(_Symbol, _Period, 0, period+1, Low) < period+1) return 0.0;
   if(CopyClose(_Symbol, _Period, 0, period+1, Close) < period+1) return 0.0;
   
   double trSum = 0.0;
   for(int i = 0; i < period; i++)
   {
      double hl = High[i] - Low[i];
      double hc = MathAbs(High[i] - Close[i+1]);
      double lc = MathAbs(Low[i] - Close[i+1]);
      trSum += MathMax(hl, MathMax(hc, lc));
   }
   return trSum / period;
}

//+------------------------------------------------------------------+
//| Helper: Normalize Volume                                         |
//+------------------------------------------------------------------+
double NormalizeVolume(double lot)
{
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(step > 0)
   {
      double steps = MathRound(lot / step);
      lot = steps * step;
   }
   
   if(lot < min) lot = min;
   if(lot > max) lot = max;
   
   int digits = 0;
   if(step < 1.0) digits = (int)MathCeil(MathAbs(MathLog10(step)));
   
   return NormalizeDouble(lot, digits);
}

//+------------------------------------------------------------------+
//| Helper: Visual Lines                                             |
//+------------------------------------------------------------------+
void DrawBoxLines(double top, double bottom)
{
   string topName = "Lanre_Box_Top";
   if(ObjectFind(0, topName) < 0) ObjectCreate(0, topName, OBJ_HLINE, 0, 0, top);
   ObjectMove(0, topName, 0, 0, top);
   ObjectSetInteger(0, topName, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, topName, OBJPROP_WIDTH, 2);
   
   string botName = "Lanre_Box_Bot";
   if(ObjectFind(0, botName) < 0) ObjectCreate(0, botName, OBJ_HLINE, 0, 0, bottom);
   ObjectMove(0, botName, 0, 0, bottom);
   ObjectSetInteger(0, botName, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, botName, OBJPROP_WIDTH, 2);
}
