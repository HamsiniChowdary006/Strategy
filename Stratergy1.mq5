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

// Visual Parameters
input bool   show_labels          = true;
input color  swing_high_color     = clrYellow;
input color  swing_low_color      = clrYellow;
input color  buy_color            = clrLime;
input color  sell_color           = clrRed;
input color  stoploss_color       = clrOrange;

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
//| Create text label on chart                                       |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, datetime time, double price, color clr, int anchor = ANCHOR_LEFT_UPPER)
{
   if(!show_labels) return;
   
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| Create horizontal line                                           |
//+------------------------------------------------------------------+
void CreateHLine(string name, double price, color clr, int style = STYLE_SOLID, int width = 1)
{
   if(!show_labels) return;
   
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Create trend line                                                |
//+------------------------------------------------------------------+
void CreateTrendLine(string name, datetime time1, double price1, datetime time2, double price2, color clr, int style = STYLE_SOLID, int width = 2)
{
   if(!show_labels) return;
   
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| Create rectangle for highlighting areas                          |
//+------------------------------------------------------------------+
void CreateRectangle(string name, datetime time1, double price1, datetime time2, double price2, color clr, bool fill = true)
{
   if(!show_labels) return;
   
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
}

//+------------------------------------------------------------------+
//| Draw swing points and initial setup                              |
//+------------------------------------------------------------------+
void DrawSwingPoints()
{
   if(!show_labels) return;
   
   datetime swing_high_time = iTime(Symbol(), PERIOD_CURRENT, highest_bar_index);
   datetime swing_low_time = iTime(Symbol(), PERIOD_CURRENT, lowest_bar_index);
   
   // Draw swing high point
   CreateLabel("SwingHigh_Label", "Swing High", swing_high_time, highest_price + 10*Point(), swing_high_color);
   CreateHLine("SwingHigh_Line", highest_price, swing_high_color, STYLE_DOT);
   
   // Draw swing low point  
   CreateLabel("SwingLow_Label", "Swing Low", swing_low_time, lowest_price - 20*Point(), swing_low_color);
   CreateHLine("SwingLow_Line", lowest_price, swing_low_color, STYLE_DOT);
   
   // Draw entry zones
   double buy_entry_upper = highest_price - pips_to_points(buy_pips_down_entry) * Point();
   double buy_entry_lower = highest_price - pips_to_points(buy_pips_down_exit) * Point();
   
   double sell_entry_lower = lowest_price + pips_to_points(sell_pips_up_entry) * Point();
   double sell_entry_upper = lowest_price + pips_to_points(sell_pips_up_exit) * Point();
   
   // Create entry zone rectangles
   datetime current_time = TimeCurrent();
   datetime zone_start = current_time - PeriodSeconds() * 20;
   
   CreateRectangle("BuyZone", zone_start, buy_entry_upper, current_time + PeriodSeconds() * 100, buy_entry_lower, 
                  ColorToARGB(buy_color, 30));
   CreateLabel("BuyZone_Label", "Buy Entry Zone", zone_start, buy_entry_upper + 5*Point(), buy_color);
   
   CreateRectangle("SellZone", zone_start, sell_entry_lower, current_time + PeriodSeconds() * 100, sell_entry_upper, 
                  ColorToARGB(sell_color, 30));
   CreateLabel("SellZone_Label", "Sell Entry Zone", zone_start, sell_entry_upper + 5*Point(), sell_color);
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
   
   // Draw initial swing points and zones
   DrawSwingPoints();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up objects when EA is removed
   ObjectsDeleteAll(0, "SwingHigh");
   ObjectsDeleteAll(0, "SwingLow");
   ObjectsDeleteAll(0, "BuyZone");
   ObjectsDeleteAll(0, "SellZone");
   ObjectsDeleteAll(0, "Entry");
   ObjectsDeleteAll(0, "StopLoss");
   ObjectsDeleteAll(0, "TakeProfit");
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
//| Draw trade execution labels                                      |
//+------------------------------------------------------------------+
void DrawTradeLabels(string trade_type, double entry_price, double stop_loss, double take_profit)
{
   if(!show_labels) return;
   
   datetime current_time = TimeCurrent();
   string prefix = trade_type + "_" + TimeToString(current_time, TIME_SECONDS);
   
   // Entry point
   CreateLabel(prefix + "_Entry", trade_type + " Entry", current_time, entry_price, 
              (trade_type == "BUY") ? buy_color : sell_color);
   
   // Stop loss line and label
   CreateHLine(prefix + "_SL_Line", stop_loss, stoploss_color, STYLE_DASH, 2);
   CreateLabel(prefix + "_SL_Label", "Stop Loss", current_time, stop_loss, stoploss_color);
   
   // Take profit line and label
   CreateHLine(prefix + "_TP_Line", take_profit, (trade_type == "BUY") ? buy_color : sell_color, STYLE_DASH, 2);
   CreateLabel(prefix + "_TP_Label", "Take Profit @" + DoubleToString(MathAbs(take_profit - entry_price) / (pips_to_points(1.0) * Point()), 0) + "pips", 
              current_time, take_profit, (trade_type == "BUY") ? buy_color : sell_color);
   
   // Draw trend line from swing point to entry
   datetime swing_time;
   double swing_price;
   
   if(trade_type == "BUY")
     {
      swing_time = iTime(Symbol(), PERIOD_CURRENT, highest_bar_index);
      swing_price = highest_price;
     }
   else
     {
      swing_time = iTime(Symbol(), PERIOD_CURRENT, lowest_bar_index);
      swing_price = lowest_price;
     }
   
   CreateTrendLine(prefix + "_SwingToEntry", swing_time, swing_price, current_time, entry_price,
                  (trade_type == "BUY") ? buy_color : sell_color, STYLE_SOLID, 2);
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
      
      // Update visual feedback for condition met
      if(show_labels)
        {
         CreateLabel("BuyCondition_Met", "Buy Condition Met - Waiting for Retrace", 
                    TimeCurrent(), current_ask_price + 15*Point(), buy_color);
        }
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
            
            // Draw trade labels
            DrawTradeLabels("BUY", current_ask_price, stop_loss, take_profit);
            
            // Clean up condition met label
            ObjectDelete(0, "BuyCondition_Met");
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
      
      // Update visual feedback for condition met
      if(show_labels)
        {
         CreateLabel("SellCondition_Met", "Sell Condition Met - Waiting for Retrace", 
                    TimeCurrent(), current_bid_price + 15*Point(), sell_color);
        }
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
            
            // Draw trade labels
            DrawTradeLabels("SELL", current_bid_price, stop_loss, take_profit);
            
            // Clean up condition met label
            ObjectDelete(0, "SellCondition_Met");
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
