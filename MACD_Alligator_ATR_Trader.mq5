//+------------------------------------------------------------------+
//|                                  MACD_Alligator_ATR_Trailing.mq5 |
//|                                    Copyright 2025, LanreEnlight  |
//|                                       https://www.youtube.com/@lanreenlight |
//+------------------------------------------------------------------+
#property copyright "LanreEnlight"
#property link      "https://www.youtube.com/@lanreenlight"
#property version   "2.40"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "--- Strategy Settings ---"
input double   InpLotSize        = 0.5;     // Fixed Lot Size
input int      InpMagicNumber    = 123456;   // Magic Number
input int      InpSlippage       = 3;        // Slippage Deviation

input group "--- Entry & SL Settings (ZigZag) ---"
input int      InpZZ_Depth       = 12;       // ZigZag Depth
input int      InpZZ_Deviation   = 5;        // ZigZag Deviation
input int      InpZZ_Backstep    = 3;        // ZigZag Backstep
input double   InpSL_Buffer      = 10.0;     // SL Buffer (Points)

input group "--- MACD Settings ---"
input int      InpMACD_Fast      = 12;       // MACD Fast EMA
input int      InpMACD_Slow      = 26;       // MACD Slow EMA
input int      InpMACD_Signal    = 9;        // MACD Signal SMA
input ENUM_APPLIED_PRICE InpMACD_Price = PRICE_CLOSE; // MACD Applied Price

input group "--- Alligator Settings ---"
input bool     InpUseAlligator   = true;     // Use Alligator Filter
input int      InpJawPeriod      = 13;       // Jaw Period
input int      InpJawShift       = 8;        // Jaw Shift
input int      InpTeethPeriod    = 8;        // Teeth Period
input int      InpTeethShift     = 5;        // Teeth Shift
input int      InpLipsPeriod     = 5;        // Lips Period
input int      InpLipsShift      = 3;        // Lips Shift
input ENUM_MA_METHOD InpMaMethod = MODE_SMMA; // MA Method
input ENUM_APPLIED_PRICE InpAlligatorPrice = PRICE_MEDIAN; // Applied Price

input group "--- Volatility & Trailing (ATR) ---"
input int      InpATR_Period     = 10;       // ATR Period
input double   InpTrail_StartProfitPercent = 0.5; // Start Trailing at % Profit
input double   InpTrail_Multiplier = 4;    // Trailing Stop ATR Multiplier

//--- Global Variables
CTrade         trade;
int            handleMACD, handleAlligator, handleATR, handleZigZag;
double         macdMain[], macdSignal[];
double         jawVal[], teethVal[], lipsVal[];
double         atrVal[];
datetime       lastBarTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1. Initialize MACD Indicator
   handleMACD = iMACD(_Symbol, _Period, InpMACD_Fast, InpMACD_Slow, InpMACD_Signal, InpMACD_Price);
   if(handleMACD == INVALID_HANDLE)
     {
      Print("Failed to create MACD handle");
      return(INIT_FAILED);
     }

   // 2. Initialize Alligator Indicator
   handleAlligator = iAlligator(_Symbol, _Period, InpJawPeriod, InpJawShift, InpTeethPeriod, InpTeethShift, InpLipsPeriod, InpLipsShift, InpMaMethod, InpAlligatorPrice);
   if(handleAlligator == INVALID_HANDLE)
     {
      Print("Failed to create Alligator handle");
      return(INIT_FAILED);
     }

   // 3. Initialize ATR Indicator
   handleATR = iATR(_Symbol, _Period, InpATR_Period);
   if(handleATR == INVALID_HANDLE)
     {
      Print("Failed to create ATR handle");
      return(INIT_FAILED);
     }

   // 4. Initialize ZigZag Indicator (Standard Library Path)
   handleZigZag = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpZZ_Depth, InpZZ_Deviation, InpZZ_Backstep);
   if(handleZigZag == INVALID_HANDLE)
     {
      Print("Failed to create ZigZag handle. Ensure 'Examples\\ZigZag' exists.");
      return(INIT_FAILED);
     }

   // Set Trade Magic Number
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);

   // Allocate arrays just once
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   ArraySetAsSeries(jawVal, true);
   ArraySetAsSeries(teethVal, true);
   ArraySetAsSeries(lipsVal, true);
   ArraySetAsSeries(atrVal, true);

   Print("System Initialized for LanreEnlight. Ready to trade (Version 2.40 - Optional Alligator).");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handleMACD);
   IndicatorRelease(handleAlligator);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleZigZag);
   
   // Clean up arrows created by this EA to keep the chart clean
   ObjectsDeleteAll(0, "Lanre_Arrow_");
   
   Print("System Shutting Down.");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // --- 1. Check for New Bar (Optimization for Speed) ---
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime) return; 

   // --- 2. Get Indicator Data ---
   // Important: We check data first. If data is not ready, we RETURN but do NOT update lastBarTime.
   if(CopyBuffer(handleMACD, 0, 1, 2, macdMain) < 2 || CopyBuffer(handleMACD, 1, 1, 2, macdSignal) < 2) return;
   if(CopyBuffer(handleAlligator, 0, 1, 1, jawVal) < 1 || CopyBuffer(handleAlligator, 1, 1, 1, teethVal) < 1 || CopyBuffer(handleAlligator, 2, 1, 1, lipsVal) < 1) return;
   if(CopyBuffer(handleATR, 0, 1, 1, atrVal) < 1) return;
   // Note: We don't copy ZigZag here on every tick, only when we need to calculate SL to save resources.

   // Data successfully retrieved, now we mark the bar as processed
   lastBarTime = currentBarTime;

   // --- 3. Manage Trailing Stop (Filtered by Profit %) ---
   ManageTrailingStop();

   // --- 4. Signal Logic (Zero Line Cross) ---
   
   // Check if Main Line crossed Zero
   bool mainCrossBuy  = (macdMain[1] < 0) && (macdMain[0] > 0);
   bool mainCrossSell = (macdMain[1] > 0) && (macdMain[0] < 0);
   
   // Check if Signal Line crossed Zero
   bool sigCrossBuy   = (macdSignal[1] < 0) && (macdSignal[0] > 0);
   bool sigCrossSell  = (macdSignal[1] > 0) && (macdSignal[0] < 0);

   // Filter: Alligator
   bool alligatorBullish = (lipsVal[0] > teethVal[0]) && (teethVal[0] > jawVal[0]);
   bool alligatorBearish = (lipsVal[0] < teethVal[0]) && (teethVal[0] < jawVal[0]);

   // --- 5. Execution ---
   
   // A. Identify Signals (Independent of Positions)
   bool isBuySignal = false;
   bool isSellSignal = false;
   string signalSource = ""; // "Main" or "Signal"

   // CONDITIONAL LOGIC: Check 'InpUseAlligator'
   
   // Buy Logic
   if (!InpUseAlligator || alligatorBullish)
   {
      if (mainCrossBuy) { isBuySignal = true; signalSource = "Main"; }
      else if (sigCrossBuy) { isBuySignal = true; signalSource = "Signal"; }
   }
   
   // Sell Logic
   if (!InpUseAlligator || alligatorBearish)
   {
      if (mainCrossSell) { isSellSignal = true; signalSource = "Main"; }
      else if (sigCrossSell) { isSellSignal = true; signalSource = "Signal"; }
   }

   // B. Manage Positions (Reversal & Counting)
   int posCount = 0;
   double existingSL = 0.0; // Variable to store SL of the 1st trade
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            long type = PositionGetInteger(POSITION_TYPE);
            
            // Reversal Logic: If Buy Signal, Close Sells
            if (isBuySignal && type == POSITION_TYPE_SELL)
            {
               trade.PositionClose(ticket);
               Print("Reversal: Closed Sell due to Buy Signal");
               continue; // Do not count this position
            }
            
            // Reversal Logic: If Sell Signal, Close Buys
            if (isSellSignal && type == POSITION_TYPE_BUY)
            {
               trade.PositionClose(ticket);
               Print("Reversal: Closed Buy due to Sell Signal");
               continue; // Do not count this position
            }
            
            // If we are here, this is a valid position that stays open
            existingSL = PositionGetDouble(POSITION_SL); // Capture its SL
            posCount++;
         }
      }
   }
   
   // C. Determine Final Entry
   bool openBuy = false;
   bool openSell = false;
   string tradeComment = "";

   // Allow entry if less than 2 trades active
   // (If we just closed a reversal trade, posCount will be low enough to enter)
   if (posCount < 2)
   {
      if (isBuySignal)
      {
         openBuy = true;
         tradeComment = "Lanre " + signalSource + " Buy" + ((posCount > 0) ? " (2nd)" : "");
      }
      else if (isSellSignal)
      {
         openSell = true;
         tradeComment = "Lanre " + signalSource + " Sell" + ((posCount > 0) ? " (2nd)" : "");
      }
   }
   
   if (!openBuy && !openSell) return;

   // --- Volume Normalization Logic (Fixes Error 10014) ---
   double minVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double tradeLot = InpLotSize;
   
   // Adjust to Step
   if(stepVol > 0.0)
     {
      double steps = MathRound(tradeLot / stepVol);
      tradeLot = steps * stepVol;
     }
   
   // Clamp to Min/Max
   if(tradeLot < minVol) tradeLot = minVol;
   if(tradeLot > maxVol) tradeLot = maxVol;
   
   // Normalize decimal places
   int volDigits = 2; 
   if(stepVol >= 1.0) volDigits = 0;
   else if(stepVol >= 0.1) volDigits = 1;
   tradeLot = NormalizeDouble(tradeLot, volDigits);
   // ----------------------------------------------------

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   // BUY ENTRY
   if(openBuy)
     {
      double sl = 0.0;
      
      // LOGIC: Use Existing SL if scaling in (2nd trade)
      if (posCount > 0 && existingSL > 0)
      {
         sl = existingSL;
         Print("Scaling In: Using 1st Trade SL: ", sl);
      }
      else
      {
         // --- ZIGZAG SL LOGIC (1st Trade) ---
         double zigZagBuffer[];
         ArraySetAsSeries(zigZagBuffer, true);
         // Copy last 200 bars of ZigZag to find a low
         if(CopyBuffer(handleZigZag, 0, 0, 200, zigZagBuffer) > 0)
         {
            for(int i = 1; i < 200; i++)
            {
               double val = zigZagBuffer[i];
               if(val != 0.0 && val != EMPTY_VALUE)
               {
                  // Found a ZigZag point. For BUY, we want a point BELOW current Ask price.
                  if(val < ask)
                  {
                     sl = val - (InpSL_Buffer * point);
                     break; 
                  }
               }
            }
         }
         // Fallback if ZigZag fails
         if(sl == 0.0) sl = ask - (atrVal[0] * 2.0);
         // ------------------------------------
      }
      
      double tp = 0; 
      
      sl = NormalizeDouble(sl, digits);
      
      // Safety Check: Ensure SL is not inside StopLevel
      if (ask - sl < stopLevel * point) sl = ask - (stopLevel * point) - (10 * point);

      if(trade.Buy(tradeLot, _Symbol, ask, sl, tp, tradeComment))
        {
         Print(tradeComment, " Executed. SL: ", sl);
         
         string objName = "Lanre_Arrow_Buy_" + IntegerToString(TimeCurrent());
         if(ObjectCreate(0, objName, OBJ_ARROW_BUY, 0, TimeCurrent(), ask))
           {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
           }
        }
      else
        {
         Print("Buy Failed! Error: ", trade.ResultRetcodeDescription(), " Code: ", trade.ResultRetcode());
        }
     }

   // SELL ENTRY
   if(openSell)
     {
      double sl = 0.0;

      // LOGIC: Use Existing SL if scaling in (2nd trade)
      if (posCount > 0 && existingSL > 0)
      {
         sl = existingSL;
         Print("Scaling In: Using 1st Trade SL: ", sl);
      }
      else
      {
         // --- ZIGZAG SL LOGIC (1st Trade) ---
         double zigZagBuffer[];
         ArraySetAsSeries(zigZagBuffer, true);
         // Copy last 200 bars of ZigZag to find a high
         if(CopyBuffer(handleZigZag, 0, 0, 200, zigZagBuffer) > 0)
         {
            for(int i = 1; i < 200; i++)
            {
               double val = zigZagBuffer[i];
               if(val != 0.0 && val != EMPTY_VALUE)
               {
                  // Found a ZigZag point. For SELL, we want a point ABOVE current Bid price.
                  if(val > bid)
                  {
                     sl = val + (InpSL_Buffer * point);
                     break; 
                  }
               }
            }
         }
         // Fallback if ZigZag fails
         if(sl == 0.0) sl = bid + (atrVal[0] * 2.0);
         // ------------------------------------
      }

      double tp = 0; 
      
      sl = NormalizeDouble(sl, digits);

      // Safety Check: Ensure SL is not inside StopLevel
      if (sl - bid < stopLevel * point) sl = bid + (stopLevel * point) + (10 * point);

      if(trade.Sell(tradeLot, _Symbol, bid, sl, tp, tradeComment))
        {
         Print(tradeComment, " Executed. SL: ", sl);
         
         string objName = "Lanre_Arrow_Sell_" + IntegerToString(TimeCurrent());
         if(ObjectCreate(0, objName, OBJ_ARROW_SELL, 0, TimeCurrent(), bid))
           {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
           }
        }
      else
        {
         Print("Sell Failed! Error: ", trade.ResultRetcodeDescription(), " Code: ", trade.ResultRetcode());
        }
     }
  }

//+------------------------------------------------------------------+
//| Function to manage ATR Trailing Stop                             |
//+------------------------------------------------------------------+
void ManageTrailingStop()
  {
   if(PositionsTotal() == 0) return;

   // We reuse the 'atrVal' from OnTick (Index 1: Closed Bar)
   // This is much more stable than recalculating it on a fresh bar.
   double trailDistance = atrVal[0] * InpTrail_Multiplier;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

         double currentSL = PositionGetDouble(POSITION_SL);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = 0.0;
         long type = PositionGetInteger(POSITION_TYPE);
         bool modify = false;
         double newSL = 0.0;

         // --- Calculate Profit % ---
         double profitPercent = 0.0;
         if(type == POSITION_TYPE_BUY) 
         {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            profitPercent = ((currentPrice - openPrice) / openPrice) * 100.0;
         }
         else if(type == POSITION_TYPE_SELL)
         {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            profitPercent = ((openPrice - currentPrice) / openPrice) * 100.0;
         }

         // Only trail if profit > start %
         if(profitPercent < InpTrail_StartProfitPercent) continue;
         // ---------------------------

         if(type == POSITION_TYPE_BUY)
           {
            double potentialSL = currentPrice - trailDistance;
            
            if(potentialSL > currentSL && potentialSL < currentPrice)
              {
               newSL = potentialSL;
               modify = true;
              }
           }
         else if(type == POSITION_TYPE_SELL)
           {
            double potentialSL = currentPrice + trailDistance;
            
            if((potentialSL < currentSL || currentSL == 0) && potentialSL > currentPrice)
              {
               newSL = potentialSL;
               modify = true;
              }
           }

         if(modify)
           {
            newSL = NormalizeDouble(newSL, _Digits);
            long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            if(MathAbs(currentPrice - newSL) > stopLevel * point)
              {
               if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
               {
                  // Print("Trailing Stop Updated. Ticket: ", ticket);
               }
              }
           }
        }
     }
  }
