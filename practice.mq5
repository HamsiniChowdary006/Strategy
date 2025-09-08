//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

CTrade trade;
double lowest_price;
int lowest_bar_index;
double highest_price;
int highest_bar_index;

// --- Input Parameters ---
input int lookback = 50;
input double lot_size = 0.1;

// Sell Parameters
input double sell_pips_up_entry = 20.0;
input double sell_pips_up_exit = 40.0;
input double sell_retrace_pips = 5.0;
input double sell_stop_loss_pips = 20.0;
input double sell_take_profit_pips = 20.0;

// Buy Parameters
input double buy_pips_down_entry = 20.0;
input double buy_pips_down_exit = 40.0;
input double buy_retrace_pips = 5.0;
input double buy_stop_loss_pips = 20.0;
input double buy_take_profit_pips = 20.0;

#property strict

// --- Global Flags ---
static bool sell_condition_met = false;
static bool buy_condition_met = false;

// --- OnInit() ---
void OnInit()
  {
   double lowArray[];
   double highArray[];

   if(Bars(_Symbol, PERIOD_CURRENT) < lookback)
     {
      Print("Error: Not enough bars to find swing points.");
      return;
     }

// Find Swing Low (for Sell Logic)
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, lookback, lowArray) == -1)
     {
      Print("Error: Failed to copy low prices. Error: ", GetLastError());
      return;
     }
   int lowest_array_index = ArrayMinimum(lowArray);
   lowest_price = lowArray[lowest_array_index];
   lowest_bar_index = lookback - 1 - lowest_array_index;

// Find Swing High (for Buy Logic)
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookback, highArray) == -1)
     {
      Print("Error: Failed to copy high prices. Error: ", GetLastError());
      return;
     }
   int highest_array_index = ArrayMaximum(highArray);
   highest_price = highArray[highest_array_index];
   highest_bar_index = lookback - 1 - highest_array_index;

   Print("Swing Low: ", lowest_price, " at bar ", lowest_bar_index);
   Print("Swing High: ", highest_price, " at bar ", highest_bar_index);
  }

// --- OnTick() ---
void OnTick()
  {
   if(PositionSelect(_Symbol))
     {
      return;
     }

   FindSwingHighEntry();
   FindSwingLowEntry();
  }

// --- Swing High (Buy) Logic ---
void FindSwingHighEntry()
  {
   double current_bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double pips_difference = (highest_price - current_bid_price) / _Point;

   if(pips_difference > buy_pips_down_entry && pips_difference < buy_pips_down_exit)
     {
      buy_condition_met = true;
     }

   if(buy_condition_met && MathAbs(current_ask_price - highest_price) < (_Point * buy_retrace_pips))
     {
      double lowArray[];
      int bars_to_copy = highest_bar_index - Bars(_Symbol, PERIOD_CURRENT) + 1;
      if(bars_to_copy > 0 && CopyLow(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, lowArray) > 0)
        {
         double lowest_price_for_sl = ArrayMinimum(lowArray);

         double stop_loss = lowest_price_for_sl - buy_stop_loss_pips * _Point;
         double take_profit = current_ask_price + buy_take_profit_pips * _Point;

         if(trade.Buy(lot_size, _Symbol, current_ask_price, stop_loss, take_profit))
           {
            Print("BUY order placed from Swing High logic.");
           }
         else
           {
            Print("Failed to place BUY order. Error: ", GetLastError());
           }
        }
      else
        {
         Print("Error: Could not copy lows for Stop Loss calculation.");
        }
      buy_condition_met = false;
     }
  }

// --- Swing Low (Sell) Logic ---
void FindSwingLowEntry()
  {
   double current_bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double pips_difference = (current_bid_price - lowest_price) / _Point;

   if(pips_difference > sell_pips_up_entry && pips_difference < sell_pips_up_exit)
     {
      sell_condition_met = true;
     }

   if(sell_condition_met && MathAbs(current_bid_price - lowest_price) < (_Point * sell_retrace_pips))
     {
      double stop_loss = current_bid_price + sell_stop_loss_pips * _Point;
      double take_profit = current_bid_price - sell_take_profit_pips * _Point;

      if(trade.Sell(lot_size, _Symbol, current_bid_price, stop_loss, take_profit))
        {
         Print("SELL order placed from Swing Low logic.");
        }
      else
        {
         Print("Failed to place SELL order. Error: ", GetLastError());
        }
      sell_condition_met = false;
     }
  }
//+------------------------------------------------------------------+
