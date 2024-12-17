//+------------------------------------------------------------------+
//|                                       Bollinger-RSI-reversal.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

   #include <Trade\Trade.mqh>
      CTrade trade;
      CPositionInfo posinfo;
      COrderInfo ordinfo;
      
   #include <Indicators\Trend.mqh>
      CiBands Bollinger;
      CiBands TPBol;
      CiBands SLBol;
      CiIchimoku Ichimoku;
      CiMA  MovAvgFast, MovAvgSlow;
      
   #include <Indicators\Oscilators.mqh>
      CiRSI RSI;
   
   enum LotTyp {Lot_per_1k_Capital = 0, Fixed_Lot_Size = 1};
   enum IcTypes {Price_above_Cloud = 0, Price_above_Ten = 1, Price_above_Kij = 2, Price_above_SenA = 3, Price_above_SenB = 4, Ten_above_Kij = 5, Ten_above_Kij_above_Cloud=6, Ten_above_Cloud = 7, Kij_above_Cloud = 8};
   
   input group "== EA Specific variables =="
   
      input ulong InpMagic = 23432; // EA Unique ID (Magic No)
      input string Curren = "USDJPY, EURUSD, GBPUSD"; // Currencies for the EA
      input ENUM_TIMEFRAMES Timeframe = PERIOD_H1; // Timeframe for the EA (trading)
   
   input group "== Trade Settings (criteria for taking trades) =="
      input int BollingerMAperiod = 200; // Bollinger MA value
      input double BollingerStDev = 4; // Bollinger standard deviation for taking trade
      input int RSIUpper = 80; // RSI upper level for taking trade
      input int RSILower = 20; // RSI lower level for taking trade
      input int RSIPeriod = 14; // RSI Period
      //additional features
      input int Maxtradessymbol = 0; // Max no. of open trades per pair (0 = unlimited)
      input int Maxtradesaccount = 0; // Max no. of open trades for EA on the account (0 = unlimited)
      input bool SwapHunterOn = false; // Only trade if swap is positive
      input double BuyExitPct = 5; // Exit trades if profit >x% (on that symbol)
   
   input group "== Trade Management =="
      input LotTyp Lot_Type = 0; // Type of lotsize
      input double Lotsize = 0.02; // Lotsize if fixed
      input double Lotsizeper1000 = 0.02; // Lotsize per 1000 capital
      input double TPBolStDev = 3; // Bollinger st.dev for TP setting
      //additional feature
      input double SLBolStDev = 3; // Stoploss on opposite band once price cross MA
      //
      input int BarsSince = 100; // No. of bars/candle to be waited before a new trade can be taken when conditions are met. Sometimes an EA can open multiple conditions on same or next candle if we don't specify a wait time.
       
      
         
      ENUM_APPLIED_PRICE AppPrice = PRICE_MEDIAN; // Moving Avg of Applied Price
      
      
      string Currencies[];
      string BarsTraded[][2];
      string sep = ",";
      
    input group "== Moving Average Filter =="
      
      input bool MAFilterOn = false; // Buy when Fast MA > Slow MA (vice versa)
      input ENUM_TIMEFRAMES MATimeframe = PERIOD_D1;
      input int Slow_MA_Period = 200;
      input int Fast_MA_Period = 50;
      input ENUM_MA_METHOD MA_Mode = MODE_EMA;
      input ENUM_APPLIED_PRICE MA_AppPrice = PRICE_MEDIAN;
     
    input group "== Ichimoku Filter =="
      
      input bool IchiFilterOn = false;
      input IcTypes IchiFilterType = 0;
      input ENUM_TIMEFRAMES IchiTimeframe = PERIOD_D1;
      input int tenkan = 9;
      input int kijun = 26;
      input int senkou_b = 52;
        
      
//+------------------------------------------------------------------+
//| Expert initialization function - Runs everytime the EA is added to chart |
//+------------------------------------------------------------------+
int OnInit(){
   trade.SetExpertMagicNumber(InpMagic);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   
   int sep_code = StringGetCharacter(sep, 0);
   int k = StringSplit(Curren,sep_code,Currencies);
   
   ArrayResize(BarsTraded,k);
   for(int i=k-1;i>=0;i--) {
      BarsTraded[i][0] = Currencies[i];
      BarsTraded[i][1] = IntegerToString(i);
   }
   ArrayPrint(BarsTraded);
   
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function - Runs everytime the EA is removed from chart |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   if(!IsNewBar()) return;
   for(int i=ArraySize(Currencies)-1; i>=0; i--){
      RunSymbols(Currencies[i]);
   }
}
  
void RunSymbols(string symbol) { 
   if(PositionsTotal()>0) {
      TrailSL(symbol);
      if(BuyExitPct!=0) ExitPositionsInProfit(symbol);
   }
   
   Bollinger = new CiBands;
   Bollinger.Create(symbol, Timeframe, BollingerMAperiod, 0, BollingerStDev, AppPrice);
   RSI = new CiRSI;
   RSI.Create(symbol, Timeframe, RSIPeriod, AppPrice);
   RSI.Refresh(-1);
   Bollinger.Refresh(-1);
   
   double FastMA = 0, SlowMA = 0;
   double SenA = 0, SenB = 0, Ten = 0, Kij = 0;
   
   if(MAFilterOn) {
      MovAvgSlow = new CiMA;
      MovAvgSlow.Create(symbol,MATimeframe,Slow_MA_Period,0,MA_Mode,MA_AppPrice);
      MovAvgFast = new CiMA;
      MovAvgFast.Create(symbol,MATimeframe,Fast_MA_Period,0,MA_Mode,MA_AppPrice);
      
      MovAvgSlow.Refresh(-1);
      MovAvgFast.Refresh(-1);
      
      FastMA = MovAvgFast.Main(1);
      SlowMA = MovAvgSlow.Main(1);
   }
   
   if(IchiFilterOn) {
      Ichimoku = new CiIchimoku;
      Ichimoku.Create(symbol,IchiTimeframe,tenkan,kijun,senkou_b);
      Ichimoku.Refresh(-1);
      
      SenA = Ichimoku.SenkouSpanA(1);
      SenB = Ichimoku.SenkouSpanB(1);
      Ten =  Ichimoku.TenkanSen(1);
      Kij =  Ichimoku.KijunSen(1);
   }
   
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double Closex1 = iClose(symbol, Timeframe, 1);
   long BarsLastTraded = GetBarsLastTraded(symbol);
   int Barsnow = iBars(symbol, Timeframe);
   
   double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lots = 0.01;
   switch(Lot_Type){
      case 0:
        lots = NormalizeDouble(Lotsizeper1000 * AccountBalance / 1000, 2); break;
      case 1:
        lots = Lotsize;
   }
   
   //Closex1 means closing price of last candle
   if(Closex1 < Bollinger.Lower(1) && 
      Barsnow > BarsLastTraded + BarsSince && 
      (Maxtradessymbol==0 || OpenTradesSymbol(symbol) < Maxtradessymbol) &&
      (Maxtradesaccount==0 || PositionsTotal()<Maxtradesaccount) &&
      RSI.Main(1) < RSILower){
         if(MAFilterOn && PriceVsMovAvg(FastMA, SlowMA)!="above") return;
         if(IchiFilterOn && PriceVsIchiCloud(symbol, SenA, SenB, Ten, Kij)!="above") return;
         if(SwapHunterOn && IsSwapPositive(symbol)!="buyallow") return;
            double tp = Bollinger.Upper(0);
            trade.Buy(lots, symbol, 0, 0, tp, NULL); // First 0 is sending buy order on current value. Second 0 is sending order without SL
            SetBarsTraded(symbol); // setting the last traded bar to the current bar
    }
     
    if(Closex1 > Bollinger.Upper(1) && 
      Barsnow > BarsLastTraded + BarsSince && 
      (Maxtradessymbol==0 || OpenTradesSymbol(symbol) < Maxtradessymbol) &&
      (Maxtradesaccount==0 || PositionsTotal()<Maxtradesaccount) &&
      RSI.Main(0) > RSIUpper){
         if(MAFilterOn && PriceVsMovAvg(FastMA, SlowMA)!="below") return;
         if(IchiFilterOn && PriceVsIchiCloud(symbol, SenA, SenB, Ten, Kij)!="below") return;
         if(SwapHunterOn && IsSwapPositive(symbol)!="sellallow") return;
            double tp = Bollinger.Lower(0);
            trade.Sell(lots, symbol, 0, 0, tp, NULL); // First 0 is sending buy order on current value. Second 0 is sending order without SL
            SetBarsTraded(symbol); // setting the last traded bar to the current bar
    }
          
   
}
//+------------------------------------------------------------------+

bool IsNewBar() {
   // checking if the EA on same candle or a new candle
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(previousTime!=currentTime)
     {
       previousTime = currentTime;
       return true;
     }
     return false;
}

void TrailSL (string symbol) {
   TPBol = new CiBands;
   TPBol.Create(symbol, Timeframe, BollingerMAperiod, 0, TPBolStDev, AppPrice);
   TPBol.Refresh(-1);
   
   for(int i=PositionsTotal()-1; i>=0; i--) {
       posinfo.SelectByIndex(i);
       ulong ticket = posinfo.Ticket();
       double tp = posinfo.TakeProfit();
       double sl = posinfo.StopLoss();
       double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
       
       if(SLBolStDev!=0){
         SLBol = new CiBands;
         SLBol.Create(symbol,Timeframe,BollingerMAperiod,0,SLBolStDev,AppPrice);
         SLBol.Refresh(-1);
         switch(posinfo.PositionType())
           {
            case POSITION_TYPE_BUY:
              if(sl!=0 || ask>Bollinger.Base(1)) sl = SLBol.Lower(1); break;
            case POSITION_TYPE_SELL:
              if(sl!=0 || ask<Bollinger.Base(1)) sl = SLBol.Upper(1); break;
           }
       }
       
       switch(posinfo.PositionType()) {
          case POSITION_TYPE_BUY: tp = TPBol.Upper(1); break;
          case POSITION_TYPE_SELL: tp = TPBol.Lower(1); break;
       }
       
       if(posinfo.Symbol() == symbol && posinfo.Magic() == InpMagic){
         if(sl!=0) {
            trade.PositionModify(ticket,sl,tp);
         } else {
            trade.PositionModify(ticket,0,tp);  
         }
       }
   }
}

void SetBarsTraded (string symbol) {
   for(int i=ArraySize(Currencies)-1; i>=0; i--)
     {
         string targetsymbol = BarsTraded[i][0];
         int Barsnow = iBars(symbol, Timeframe);
         if(targetsymbol == symbol){
            BarsTraded[i][1] = IntegerToString(Barsnow);
         }
     }
}

long GetBarsLastTraded(string symbol) {
   long BarLastTraded = 0;
   for(int i=ArraySize(Currencies)-1; i>=0; i--) {
      string targetsymbol = BarsTraded[i][0];
      if(targetsymbol == symbol) {
         BarLastTraded = StringToInteger(BarsTraded[i][1]);
      }
   }
   return BarLastTraded;
}

string PriceVsMovAvg (double MAfast, double MAslow) {
   
   if(MAfast > MAslow) return "above";
   if(MAfast < MAslow) return "below";
   
return "error";
   
}

string PriceVsIchiCloud (string symbol, double SenA, double SenB, double Ten, double Kij) {
   
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(IchiFilterType == 0) {
      if(ask> SenA && ask > SenB) return "above";
      if(ask< SenA && ask < SenB) return "below";
   }
   
   if(IchiFilterType == 1) {
      if(ask> Ten) return "above";
      if(ask< Ten) return "below";
   }
   
   if(IchiFilterType == 2) {
      if(ask> Kij) return "above";
      if(ask< Kij) return "below";
   }
   
   if(IchiFilterType == 3) {
      if(ask> SenA) return "above";
      if(ask< SenA) return "below";
   }
   
   if(IchiFilterType == 4) {
      if(ask > SenB) return "above";
      if(ask < SenB) return "below";
   }
   
   if(IchiFilterType == 5) {
      if(Ten>Kij) return "above";
      if(Ten<Kij) return "below";
   }
   
   if(IchiFilterType == 6) {
      if(Ten>Kij && Kij>SenA && Kij>SenB) return "above";
      if(Ten<Kij && Kij<SenA && Kij<SenB) return "below";
   }
   
   if(IchiFilterType == 7) {
      if(Ten > SenA && Ten > SenB) return "above";
      if(Ten < SenA && Ten < SenB) return "below";
   }
   
   if(IchiFilterType == 8) {
      if(Kij > SenA && Kij > SenB) return "above";
      if(Kij < SenA && Kij < SenB) return "below";
   }
   
return "Incloud";

}

string IsSwapPositive (string symbol) {
   double swapLong = SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
   double swapShort = SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
   
   if(swapLong>0) return "buyallow";
   if(swapShort>0) return "sellallow";

return "error";

}

void ExitPositionsInProfit(string symbol){ 
   double totalProfit = 0;
   double accbalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   for(int i = PositionsTotal()-1;i>=0;i--) {
      posinfo.SelectByIndex(i);
      if(posinfo.Symbol()==symbol && posinfo.Magic()==InpMagic){
         totalProfit += posinfo.Profit();
      }
   }
   
   if(totalProfit >=accbalance*BuyExitPct/100) {
      for(int i=PositionsTotal()-1; i>=0;i--) { 
         posinfo.SelectByIndex(i);
         ulong ticket = posinfo.Ticket();
         if(posinfo.Symbol() == symbol && posinfo.Magic()==InpMagic) {
            trade.PositionClose(ticket);
         }
      }
   }
}

int OpenTradesSymbol(string symbol) {
   int OpenTrades = 0;
   
   for(int i=PositionsTotal()-1; i>=0;i--){
      posinfo.SelectByIndex(i);
      if(posinfo.Symbol() == symbol && posinfo.Magic()==InpMagic) {
         OpenTrades++;
      }
   }
   return OpenTrades;
}