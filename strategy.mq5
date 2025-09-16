#include <Trade\Trade.mqh>

CTrade trade;
double lowest_price;
int    lowest_bar_index;
double highest_price;
int    highest_bar_index;

// --- Input Parameters ---
input int    lookback             = 50;
input double lot_size             = 0.1;

// Sell Parameters - Made editable
input double sell_pips_up_entry   = 20.0;
input double sell_pips_up_exit    = 40.0;
input double sell_retrace_pips    = 5.0;
input double sell_take_profit_pips= 20.0;

// Buy Parameters - Made editable  
input double buy_pips_down_entry  = 20.0;
input double buy_pips_down_exit   = 40.0;
input double buy_retrace_pips     = 5.0;
input double buy_take_profit_pips = 20.0;

// --- Global Flags ---
static bool sell_condition_met = false;
static bool buy_condition_met  = false;

//+------------------------------------------------------------------+
//| Converts pips to points, accounting for 3 and 5 digit brokers  |
//+------------------------------------------------------------------+
double pips_to_points(double pips)
{
   // For 3 or 5 digit symbols, 1 pip = 10 points
   if(Digits() == 3 || Digits() == 5)
     {
      return(pips * 10);
     }
   // For 2 or 4 digit symbols, 1 pip = 1 point
   else
     {
      return(pips);
     }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   double lowArray[];
   double highArray[];

   if(Bars(Symbol(), PERIOD_CURRENT) < lookback)
     {
      Print("Error: Not enough bars to find swing points.");
      return(INIT_FAILED);
     }

// Find Swing Low (for Sell Logic)
   if(CopyLow(Symbol(), PERIOD_CURRENT, 0, lookback, lowArray) == -1)
     {
      Print("Error: Failed to copy low prices. Error: ", GetLastError());
      return(INIT_FAILED);
     }
   int lowest_array_index = ArrayMinimum(lowArray);
   lowest_price = lowArray[lowest_array_index];
   lowest_bar_index = lookback - 1 - lowest_array_index;

// Find Swing High (for Buy Logic)
   if(CopyHigh(Symbol(), PERIOD_CURRENT, 0, lookback, highArray) == -1)
     {
      Print("Error: Failed to copy high prices. Error: ", GetLastError());
      return(INIT_FAILED);
     }
   int highest_array_index = ArrayMaximum(highArray);
   highest_price = highArray[highest_array_index];
   highest_bar_index = lookback - 1 - highest_array_index;

   Print("Swing Low: ", lowest_price, " at bar ", lowest_bar_index);
   Print("Swing High: ", highest_price, " at bar ", highest_bar_index);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(PositionSelect(Symbol()))
     {
      return;
     }

   FindSwingHighEntry();
   FindSwingLowEntry();
}

//+------------------------------------------------------------------+
//| Find highest candle between swing point and current price       |
//+------------------------------------------------------------------+
double FindHighestCandleBetween(int start_bar, int end_bar)
{
   double highArray[];
   int bars_to_copy = start_bar - end_bar + 1;
   
   if(bars_to_copy <= 0) return 0.0;
   
   if(CopyHigh(Symbol(), PERIOD_CURRENT, end_bar, bars_to_copy, highArray) == -1)
     {
      Print("Error: Failed to copy high prices for stop loss calculation. Error: ", GetLastError());
      return 0.0;
     }
     
   return highArray[ArrayMaximum(highArray)];
}

//+------------------------------------------------------------------+
//| Find lowest candle between swing point and current price        |
//+------------------------------------------------------------------+
double FindLowestCandleBetween(int start_bar, int end_bar)
{
   double lowArray[];
   int bars_to_copy = start_bar - end_bar + 1;
   
   if(bars_to_copy <= 0) return 0.0;
   
   if(CopyLow(Symbol(), PERIOD_CURRENT, end_bar, bars_to_copy, lowArray) == -1)
     {
      Print("Error: Failed to copy low prices for stop loss calculation. Error: ", GetLastError());
      return 0.0;
     }
     
   return lowArray[ArrayMinimum(lowArray)];
}

//+------------------------------------------------------------------+
//| Swing High (Buy) Logic                                           |
//+------------------------------------------------------------------+
void FindSwingHighEntry()
{
   double current_bid_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double current_ask_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

   // The pips difference calculation must be divided by the point value of a pip.
   double pips_difference = (highest_price - current_bid_price) / (pips_to_points(1.0) * Point());

   // Check if price has moved down within the specified range
   if(pips_difference > buy_pips_down_entry && pips_difference < buy_pips_down_exit)
     {
      buy_condition_met = true;
     }

   // Check for retrace back to starting point (swing high) within tolerance
   if(buy_condition_met && MathAbs(current_ask_price - highest_price) < (pips_to_points(buy_retrace_pips) * Point()))
     {
      // Find the lowest candle between swing high and current entry point
      int current_bar = 0; // Current bar index
      double lowest_candle_price = FindLowestCandleBetween(highest_bar_index, current_bar);
      
      if(lowest_candle_price > 0.0)
        {
         // Set stop loss below the lowest candle found between swing point and entry
         double stop_loss = lowest_candle_price - pips_to_points(1.0) * Point(); // 1 pip buffer below lowest candle
         double take_profit = current_ask_price + pips_to_points(buy_take_profit_pips) * Point();

         if(trade.Buy(lot_size, Symbol(), current_ask_price, stop_loss, take_profit))
           {
            Print("BUY order placed from Swing High logic. Stop Loss at: ", stop_loss, " (Lowest candle: ", lowest_candle_price, ")");
           }
         else
           {
            Print("Failed to place BUY order. Error: ", GetLastError());
           }
        }
      else
        {
         Print("Error: Could not find lowest candle for Stop Loss calculation.");
        }
      buy_condition_met = false;
     }
}

//+------------------------------------------------------------------+
//| Swing Low (Sell) Logic                                           |
//+------------------------------------------------------------------+
void FindSwingLowEntry()
{
   double current_bid_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   // The pips difference calculation must be divided by the point value of a pip.
   double pips_difference = (current_bid_price - lowest_price) / (pips_to_points(1.0) * Point());

   // Check if price has moved up within the specified range
   if(pips_difference > sell_pips_up_entry && pips_difference < sell_pips_up_exit)
     {
      sell_condition_met = true;
     }

   // Check for retrace back to starting point (swing low) within tolerance
   if(sell_condition_met && MathAbs(current_bid_price - lowest_price) < (pips_to_points(sell_retrace_pips) * Point()))
     {
      // Find the highest candle between swing low and current entry point
      int current_bar = 0; // Current bar index
      double highest_candle_price = FindHighestCandleBetween(lowest_bar_index, current_bar);
      
      if(highest_candle_price > 0.0)
        {
         // Set stop loss above the highest candle found between swing point and entry
         double stop_loss = highest_candle_price + pips_to_points(1.0) * Point(); // 1 pip buffer above highest candle
         double take_profit = current_bid_price - pips_to_points(sell_take_profit_pips) * Point();

         if(trade.Sell(lot_size, Symbol(), current_bid_price, stop_loss, take_profit))
           {
            Print("SELL order placed from Swing Low logic. Stop Loss at: ", stop_loss, " (Highest candle: ", highest_candle_price, ")");
           }
         else
           {
            Print("Failed to place SELL order. Error: ", GetLastError());
           }
        }
      else
        {
         Print("Error: Could not find highest candle for Stop Loss calculation.");
        }
      sell_condition_met = false;
     }
}