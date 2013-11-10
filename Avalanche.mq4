//+------------------------------------------------------------------+
//|                                                    Avalanche.mq4 |
//|                        Copyright 2012, Таланин Андрей Викторович |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2012, Таланин Андрей Викторович"
#property link      ""

double currentPriceBid;
double currentPriceAsk;

extern string monInfo = "Контролирует вывод мониторинга";
extern bool   drawMonitor  = true;
extern bool   Log          = true;
extern string lotInfo = "Размер лота";
extern double lotSize = 0.01;
extern string ProfitInfo = "Минимальная прибыль для цикла сделок в валюте депозита";
extern double ProfitSize = 0;

bool changePrice  = false;
bool canTrade     = false;
bool changeLot    = false;
bool canHadge     = false;

int currentTicket       = 0;
int ordersCntr          = 0;
int avalancheArm        = 0;
int logHangle           = 0;

int init() {
   logHangle = LogInit();
   if (1 < logHangle) {
      Alert("Ошибка инициализации лог файла!");
   }
   LogAdd("Лавина успешно загружена!");
   return(0);
}

int deinit() {
   FileClose(logHangle);
   LogAdd("Деинициализация Лавины...");
   return(0);
}

int start() {
   if (drawMonitor) {
      int a,y;
      for(a=0,y=15;a<=6;a++) {
         string N=DoubleToStr(a,0);
         ObjectCreate(N,OBJ_LABEL,0,0,0,0,0);
         ObjectSet(N,OBJPROP_CORNER,0);
         ObjectSet(N,OBJPROP_XDISTANCE,5);
         ObjectSet(N,OBJPROP_YDISTANCE,y);
         y+=20;
      } 
   }
     
   changeFlag(0, false);           
   changeFlag(1, false);           
   changeFlag(2, false);     
   changeFlag(3, false);
    
   if (OrdersTotal() == 0) {      
      changeFlag(0, true);
      changeFlag(1, true);
   }   
   
   int opnTime = 0;
   int buyCntr = 0;
   int sellCntr = 0;
   int stopLossTicket = -1;
   double lotsSumBuy = 0;
   double lotsSumSell = 0;
   double buyOpnPrice = 0;
   double sellOpnPrice = 0;
   
   
   if (canTrade) {
      avalancheArm = getMedian ();   
      getPrice ();
      OrderSend(Symbol(),OP_BUYSTOP,lotSize,currentPriceAsk+avalancheArm*Point,0,0,0,NULL,NULL,0,Green);
      OrderSend(Symbol(),OP_SELLSTOP,lotSize,currentPriceBid-avalancheArm*Point,0,0,0,NULL,NULL,0,Blue);
      saveRates (); 
      changeFlag(0, false);    
   }  
   
   double currentStopLoss = 0;
   
   //LogAdd("Начинаю вычисления переменных для текущего тика ... ");  
   for (int i = OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS);           
      //LogAdd("Выбираю ордер с тикетом: " + i); 
      if ((OrderOpenTime() > opnTime) && (OrderType() == OP_BUY) || (OrderType() == OP_SELL)) {    
         opnTime = OrderOpenTime(); 
         currentTicket = OrderTicket();
         if(OrderStopLoss() > 0) {
            currentStopLoss = OrderStopLoss();
            stopLossTicket = OrderTicket();    
         }      
         //LogAdd("Ордер открыт позже предыдущего, не является отложенным. Записываю переменные: opnTime - " + opnTime + ", currentTicket - " + currentTicket + ", currentStopLoss - " + currentStopLoss + ".");
      }
      switch (OrderType()) {
         case OP_BUY: {
            buyCntr ++;   
            buyOpnPrice = OrderOpenPrice();
            lotsSumBuy += OrderLots();
            TrailingByShadows(OrderTicket(), Period(), 11, 0); 
            //LogAdd("Ордер не является отложенным, тип ордера - " + OrderType() + ", обновляю переменные, пытаюсь трейлить: buyCntr - " + buyCntr + ", buyOpnPrice - " + buyOpnPrice + ", lotsSumBuy - " + lotsSumBuy + ".");  
            break;
         }
         case OP_SELL: {
            sellCntr ++;
            sellOpnPrice = OrderOpenPrice();
            lotsSumSell += OrderLots();
            TrailingByShadows(OrderTicket(), Period(), 11, 0);
            //LogAdd("Ордер не является отложенным, тип ордера - " + OrderType() + ", обновляю переменные, пытаюсь трейлить: sellCntr - " + sellCntr + ", sellOpnPrice - " + sellOpnPrice + ", lotsSumSell - " + lotsSumSell + ".");      
            break;
         }
         case OP_SELLSTOP: {
            sellOpnPrice = OrderOpenPrice();         
            //LogAdd("Ордер является отложенным, тип ордера - " + OrderType() + ", фиксирую цену открытия: sellOpnPrice - " + sellOpnPrice + ".");
            break;
         }
         case OP_BUYSTOP: {
            buyOpnPrice = OrderOpenPrice();
            //LogAdd("Ордер является отложенным, тип ордера - " + OrderType() + ", фиксирую цену открытия: buyOpnPrice - " + buyOpnPrice + ".");
            break;
         }
      }  
   }
   //LogAdd("Вычисления переменных для текущего тика завершены."); 
   OrderSelect(currentTicket, SELECT_BY_TICKET);
   
   if ((ordersCntr != buyCntr + sellCntr) && (avalancheArm > 0)) { 
      changeFlag(3, true); 
      //LogAdd("Достигнуто условие хеджирования, переменные при достижении условия: ordersCntr - " + ordersCntr + ", buyCntr - " + buyCntr + ", sellCntr - " + sellCntr + ", " + ", avalancheArm - " + avalancheArm + ", buyOpnPrice - " + buyOpnPrice + ", sellOpnPrice - " + sellOpnPrice);
   }  
      
   if ((avalancheArm == 0) && ((currentPriceBid == 0) || (currentPriceAsk == 0))) {
      if (GlobalVariableCheck("avArm") && GlobalVariableCheck("avCurPriceBid") && GlobalVariableCheck("avCurPriceAsk")) {
         avalancheArm = GlobalVariableGet("avArm");
         currentPriceBid = GlobalVariableGet("avCurPriceBid");
         currentPriceAsk = GlobalVariableGet("avCurPriceAsk");
         //LogAdd("Обнаружено отсутствие переменных плеча и цен отложенных ордеров. Пытаюсь изъять их из глобальных переменных. Новые значения: avalancheArm - " + avalancheArm + ", currentPriceBid - " + currentPriceBid + ", currentPriceAsk - " + currentPriceAsk + ".");
      }      
   }
   
   ordersCntr = buyCntr + sellCntr;
   
   if (canHadge) {
      if (OrderType() == OP_BUY) {
         if(OrderSend(Symbol(),OP_SELLSTOP,(lotsSumSell+lotsSumBuy),NormalizeDouble(currentPriceBid-avalancheArm*Point,Digits),0,0,0,NULL,NULL,0,Blue) > 0)
         changeFlag(3, false);       
         //LogAdd("Открываю Sell Stop с лотом " + lotsSumSell+lotsSumBuy + ".");
      } 
      if (OrderType() == OP_SELL) {
         if(OrderSend(Symbol(),OP_BUYSTOP,(lotsSumSell+lotsSumBuy),NormalizeDouble(currentPriceAsk+avalancheArm*Point,Digits),0,0,0,NULL,NULL,0,Green) > 0)
         changeFlag(3, false); 
         //LogAdd("Открываю Buy Stop с лотом " + lotsSumSell+lotsSumBuy + ".");
      }  
   }
   
   if(stopLossTicket != -1) {  
      OrderSelect(stopLossTicket, SELECT_BY_TICKET);
      switch (OrderType()) {
         case OP_BUY: {  
         //LogAdd("Закрываю открытые ордеры на покупку.");   
            closeSellOrders();
            break;
         }  
         case OP_SELL: {
         //LogAdd("Закрываю открытые ордеры на продажу.");  
            closeBuyOrders();
            break;
         }      
      }
   }
   
   if (drawMonitor) {
      string str="Баланс: "+DoubleToStr(AccountBalance(),2);
      ObjectSetText("0",str,10,"Arial Black",White);

      str="Прибыль: "+DoubleToStr(AccountProfit(),2);
      ObjectSetText("1",str,10,"Arial Black",White);

      str="Свободные средства: "+DoubleToStr(AccountFreeMargin(),2);
      ObjectSetText("2",str,10,"Arial Black",White);

      str="Число разворотов: "+DoubleToStr(buyCntr + sellCntr,0);
      if(buyCntr + sellCntr > 2)
      str="Число разворотов: "+DoubleToStr(buyCntr + sellCntr -1,0);
      ObjectSetText("3",str,10,"Arial Black",White);
      
      str="Сумма лотов открытых позиций: "+DoubleToStr(lotsSumSell+lotsSumBuy,2);
      ObjectSetText("4",str,10,"Arial Black",White);      
      
      str="Текущая ширина коридора: "+DoubleToStr(avalancheArm,0)+" пунктов";
      ObjectSetText("5",str,10,"Arial Black",White); 
      
      if (AccountProfit() < 0)
      str = "Текущая просадка: " + DoubleToStr(AccountProfit() / AccountBalance() * 100, 2) + " %";
      else 
      str = "Текущая просадка: 0 %";
      ObjectSetText("6",str,10,"Arial Black",White);
   }
   return(0);
}

void closeSellOrders() {   
   for (int i = OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS);
      switch (OrderType()) {
         case OP_SELLSTOP: {
            while (true) {
               if (OrderDelete(OrderTicket())) {
                  break;
               }
            } 
            break;
         }
         case OP_SELL: {
            while (true) {
               if (OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Ask,Digits),0)) {
                  break;                  
               }
               else {
                  RefreshRates();
               }
            }
            break; 
         }     
      } 
   }
}

void closeBuyOrders() {
   for (int i = OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS);
      switch (OrderType()) {
         case OP_BUYSTOP: {
            while (true) {
               if (OrderDelete(OrderTicket())) {
                  break;
               }
            } 
            break;
         }
         case OP_BUY: {
            while (true) {
               if (OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Bid,Digits),0)) {
                  break;
               }
               else {
                  RefreshRates();
               }
            }
            break; 
         }   
      }   
   }
}

void saveRates () {
   GlobalVariableSet("avArm", avalancheArm);
   GlobalVariableSet("avCurPriceBid", currentPriceBid);
   GlobalVariableSet("avCurPriceAsk", currentPriceAsk);
   //LogAdd("Сохраняю текущие значения переменных в глобальные: avalancheArm - " + avalancheArm + ", currentPriceBid - " + ", currentPriceAsk - " + currentPriceAsk + ".");
}

int getMedian ()
{
   double _Sum = 0;
   int i;
      for (i = 0; i <= 46; i++)
      _Sum = _Sum + (High[i]-Low[i]);
   return ((_Sum/17+(MarketInfo(Symbol(), MODE_SPREAD)+MarketInfo(Symbol(), MODE_STOPLEVEL))*Point)/Point);
}

void getPrice () {
   if (changePrice) {
      RefreshRates();
      currentPriceBid = NormalizeDouble(Bid,Digits);
      currentPriceAsk = NormalizeDouble(Ask,Digits);
      changeFlag(1, false);
   }
}

void changeFlag(int Flag, bool State) {
   string strState;
   switch (Flag) {
      case 0: {
         canTrade     = State;         
         //LogAdd("Меняю флаг возможности торговли в состояние: " + State + ".");
         break;
      }
      case 1: {
         changePrice  = State;
         //LogAdd("Меняю флаг изменения цен в состояние: " + State + ".");
         break;
      }
      case 2: {
         changeLot    = State;
         //LogAdd("Меняю флаг изменения лота в состояние: " + State + ".");
         break;
      }
      case 3: {
         canHadge     = State;
         //LogAdd("Меняю флаг хеджирования в состояние: " + State + ".");
         break;
      }
   }
}

double GetTickValue(string CurrentQuote) {
   string AccountCurr = AccountCurrency();
   string BaseCurr = StringSubstr(CurrentQuote,0,3);
   string CurrentCurr = StringSubstr(CurrentQuote,3,3);
   
   if (CurrentCurr == AccountCurr)  
      return (MarketInfo(CurrentQuote, MODE_LOTSIZE) * MarketInfo(CurrentQuote, MODE_TICKSIZE));
   if (BaseCurr == AccountCurr)
      return (MarketInfo(CurrentQuote, MODE_LOTSIZE) * MarketInfo(CurrentQuote, MODE_TICKSIZE) / MarketInfo(CurrentQuote, MODE_BID));
   if ((CurrentCurr != AccountCurr) && (BaseCurr != AccountCurr))
      return (MarketInfo(CurrentQuote, MODE_LOTSIZE) * MarketInfo(CurrentQuote, MODE_TICKSIZE) * MarketInfo(StringConcatenate(BaseCurr,AccountCurr), MODE_BID) / MarketInfo(CurrentQuote, MODE_BID));
}

double AcountProfitEx(double Price) {   
   double TickValue, delta;
   double lotSum;
   string SymbolName;
   
   SymbolName = Symbol();
   TickValue = MarketInfo( SymbolName, MODE_TICKVALUE) / Point;
   delta = ( ( Price - ( MarketInfo( SymbolName, MODE_SPREAD ) * Point ) ) - Ask ) * TickValue;

   lotSum = 0.0; 
   LogAdd("Пытаюсь вычислить общую прибыль открытых позиций по цене Bid(Ask): " + Bid + "(" + Ask + "), TickValue: " + TickValue);
   for (int i = 0; i <= OrdersTotal()-1; i++)
   {
      OrderSelect(i, SELECT_BY_POS);     
      if ( OrderSymbol() == SymbolName )
      { 
         if (OrderType() == OP_BUY)    { 
            lotSum += OrderProfit() + OrderLots() * delta; 
            LogAdd(OrderTicket() + ": " + (OrderProfit() + OrderLots() * delta));
         }
         if (OrderType() == OP_SELL)   { 
            lotSum += OrderProfit() - OrderLots() * delta; 
            LogAdd(OrderTicket() + ": " + (OrderProfit() + OrderLots() * delta));
         }
      }
   }   
   LogAdd("Вычисления закончены, сумма прибыли: " + lotSum);
   return(lotSum);
}

void TrailingByShadows(int ticket,int tmfrm,int bars_n, int indent) {  
   int i;
   double new_extremum;
   
   //LogAdd("Пытаюсь трейлить ордер - " + ticket);
   if ((bars_n<1) || (indent<0) || (ticket==0) || ((tmfrm!=1) && (tmfrm!=5) && (tmfrm!=15) && (tmfrm!=30) && (tmfrm!=60) && (tmfrm!=240) && (tmfrm!=1440) && (tmfrm!=10080) && (tmfrm!=43200))) {
      Print("Трейлинг функцией TrailingByShadows() невозможен из-за некорректности значений переданных ей аргументов.");
      return(0);
   } 
   if (OrderType()==OP_BUY) {
      for(i = 1; i <= bars_n; i++) {
         if (i == 1) new_extremum = iLow(Symbol(), tmfrm, i); 
         else if (new_extremum > iLow(Symbol(), tmfrm, i)) new_extremum = iLow(Symbol(), tmfrm, i);
      }
      //LogAdd("Ордер на покупку, предполагаемая новая цена - " + new_extremum);
      if(((new_extremum - indent * Point) > OrderStopLoss() + 1.0 * Point) || (OrderStopLoss() == 0))
      if((new_extremum - indent * Point) > OrderOpenPrice())
      if(new_extremum - indent * Point < Bid - MarketInfo(Symbol(), MODE_STOPLEVEL) * Point)
      if(AcountProfitEx(new_extremum) > ProfitSize)
      OrderModify(ticket, OrderOpenPrice(), new_extremum - indent * Point, OrderTakeProfit(), OrderExpiration());
   }
   
   if (OrderType() == OP_SELL) {
      for(i = 1; i <= bars_n; i++) {
         if (i == 1) new_extremum = iHigh(Symbol(), tmfrm, i); 
         else if (new_extremum < iHigh(Symbol(), tmfrm, i)) new_extremum = iHigh(Symbol(), tmfrm, i);
      }
      //LogAdd("Ордер на продажу, предполагаемая новая цена - " + new_extremum);
      if (((new_extremum + (indent + MarketInfo(Symbol(),MODE_SPREAD)) * Point) < OrderStopLoss() - 1.0 * Point) || (OrderStopLoss() == 0)) 
      if ((new_extremum + (indent + MarketInfo(Symbol(),MODE_SPREAD)) * Point) < OrderOpenPrice())                          
      if ((new_extremum + (indent + MarketInfo(Symbol(),MODE_SPREAD)) * Point > Ask + MarketInfo(Symbol(),MODE_STOPLEVEL) * Point)) 
      if (AcountProfitEx(new_extremum) > ProfitSize)
      OrderModify(ticket, OrderOpenPrice(), new_extremum + (indent + MarketInfo(Symbol(), MODE_SPREAD)) * Point, OrderTakeProfit(), OrderExpiration());
   }      
}

int LogInit () {
  int handle;
  handle = FileOpen("Avalanche.log",FILE_CSV|FILE_READ|FILE_WRITE,';');
  return(handle);
}
void LogAdd(string msg) {   
   if (Log) {
      string currentDate = Year() + "." + Month() + "." + Day() + " " + Hour() + ":" + Minute() + ":" + Seconds();
      FileSeek(logHangle, 0, SEEK_END);
      FileWrite(logHangle, currentDate + " - " + msg);
   }
}