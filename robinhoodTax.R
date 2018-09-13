# setup ----
if (!require("pacman")) install.packages("pacman")
pacman::p_load(data.table, lubridate)


# import robinhood csv ----
# TODO Modify file path here
downloaded_path <- "robinhood/robinhood 2018.09.10.csv"
r_transactions <- fread(downloaded_path, sep = ",", header = TRUE)

# clean up ----
col_all <- names(r_transactions)
col_to_keep <- c("average_price", "created_at", "cumulative_quantity", "last_transaction_at", "price", "quantity", "response_category", "side", "state", "symbol", "type")
trans_clean <- r_transactions[, ..col_to_keep]
# convert date time
trans_clean[, created_at := ymd_hms(created_at)]
trans_clean[, last_transaction_at := ymd_hms(last_transaction_at)]
# convert numbers. convert "None" first, otherwise warnings in converting to numbers
trans_clean[average_price == "None", average_price := NA]
trans_clean[, average_price := as.numeric(average_price)]
trans_clean[price == "None", price := NA]
trans_clean[, price := as.numeric(price)]
trans_valid <- trans_clean[cumulative_quantity > 0]
# easier to filter with year column
trans_valid[side == "sell", year := year(last_transaction_at)]
setorder(trans_valid, last_transaction_at)
# cumulative quantity is the actual total order size, when a big order was executed in multiple parts. replace quantity column as we used quantity everywhere
trans_valid[, quantity := cumulative_quantity]

# calculate function ----
get_statement <- function(dt) {
  buy_orders <- dt[side == "buy"]
  sell_orders <- dt[side == "sell"]
  # match orders ----
  match_orders <- function(buy_orders, sell_orders) {
    index_b <- 1
    index_s <- 1
    current_buy <- buy_orders[index_b, quantity]
    current_sell <- sell_orders[index_s, quantity]
    res_dt <- data.table()
    # there will be no matching order when one side is exhausted
    while (index_b <= nrow(buy_orders) && index_s <= nrow(sell_orders)) {
      if (current_buy == current_sell) {
        # need to take current value as order size
        partial_sell_order <- sell_orders[index_s]
        partial_sell_order[1, quantity := current_sell]
        # the sell order could be partial too because of last remains. get size from current
        partial_buy_order <- buy_orders[index_b]
        partial_buy_order[1, quantity := current_buy]
        # always match pair order size
        res_dt <- rbindlist(list(res_dt, partial_buy_order, partial_sell_order))
        # need to maintain both the index and current value, because partial order will change current value but keep the index unchanged
        index_b <- index_b + 1
        index_s <- index_s + 1
        current_buy <- buy_orders[index_b, quantity]
        current_sell <- sell_orders[index_s, quantity]
      } else if (current_buy < current_sell) {
        # use buy order size as partial sell order size
        partial_sell_order <- sell_orders[index_s]
        partial_sell_order[1, quantity := current_buy]
        # the sell order could be partial too because of last remains. get size from current
        partial_buy_order <- buy_orders[index_b]
        partial_buy_order[1, quantity := current_buy]
        res_dt <- rbindlist(list(res_dt, partial_buy_order, partial_sell_order))
        current_sell <- current_sell - current_buy  # remaining part as new sell order
        # sell order index stay same, move to next buy order
        index_b <- index_b + 1
        current_buy <- buy_orders[index_b, quantity]
      } else if (current_buy > current_sell) {
        # use sell order size as partial buy order size
        partial_buy_order <- buy_orders[index_b]
        partial_buy_order[1, quantity := current_sell]
        partial_sell_order <- sell_orders[index_s]
        partial_sell_order[1, quantity := current_sell]
        res_dt <- rbindlist(list(res_dt, partial_buy_order, partial_sell_order))
        current_buy <- current_buy - current_sell
        index_s <- index_s + 1
        current_sell <- sell_orders[index_s, quantity]
      }
    }
    return(res_dt)
  }
  res_dt <- match_orders(buy_orders, sell_orders)
  # have to assign for both buy and sell, otherwise shift will not find the buy order
  res_dt[, buy_price := shift(price)]
  res_dt[, buy_date := shift(last_transaction_at)]
  # orders are paired, only need to check sell orders
  res_dt[side == "buy", buy_price := NA]
  res_dt[side == "sell", cost_basis := buy_price * quantity]
  res_dt[side == "sell", sell_proceeds := price * quantity]
  res_dt[side == "sell", gain := sell_proceeds - cost_basis]
  statement_dt <- res_dt[side == "sell",
                         .(quantity, buy_date, last_transaction_at,
                           sell_proceeds, cost_basis, gain,
                           buy_price, sell_price = price,
                           cumulative_quantity, year
                         )]
}
# calculate on certain stock ----
# TODO set symbol to your stock symbol
dt <- trans_valid[symbol == "FB"]
statement_dt <- get_statement(dt)
View(statement_dt)
# calculate gain for certain year
statement_dt[year == 2016, sum(gain)]
