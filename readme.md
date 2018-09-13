## Introduction

#### Problems
I meet two problems using RobinHood stock trading app and didn't find an existing easy solution.
- If you have some gain from stocks and your tax withholding is not enough to cover the tax for that part, you are required to [pay estimated tax quarterly](https://www.irs.gov/businesses/small-businesses-self-employed/estimated-taxes), otherwise there might be a penalty if you didn't meet certain requirements.
  However you only receive the tax statement in the end of year, so you need to figure out the profit amount quarterly without the official tax statement.
- If you held a stock for more than 1 year, the profit will be taxed at capital gain tax rate of 10%. It will be helpful to know the holding period of your current stocks if you want to schedule a sell.

Why are calculating profit and holding period difficult? When you have multiple buy/sell transactions on one stock, the profit and holding period is caculated with [First In/First Out rule](https://scs.fidelity.com/webxpress/help/topics/learn_account_cost_basis.shtml), unless you specified which shares you are selling in your order. Matching sell orders with previous buy orders is not an easy task by hand.

#### R script

I wrote a R script to generate a statement just like the tax statement from RobinHood, so you can calculate the profit amount and holding period by yourself anytime.

#### Warnings
- I matched the result with RobinHood tax statements and they are mostly reasonably accurate. Of course I cannot guarantee the accuracy nor provide any advice on tax, and will not be responsible for any impact from your decision.
- Since the calculation start from the first buy order on a stock, you need to have complete data for that stock.
- The script doesn't consider wash sale. 

## Install and Run
- Download your Robinhood transaction with [this python script](https://github.com/joshfraser/robinhood-to-csv).
- Install R and RStudio. 
- Clone the repo, open the project in RStudio, run the R script. You need to modify the csv file path to your own file path, modify the symbol to get statement on your stock (marked with `# TODO` in script).
- The result should be a table that in similar format of Robinhood tax statement. You should compare it to your previous tax statement to verify the accuracy. 
- To read this kind of statement, note that each row have a buy date, buy price, sell date, sell price. `buy price * quantity` is the cost basis, `sell price * quantity` is sell proceeds, and the difference is gain/loss. 
- To match sell order with previous buy order in First In/First Out, there could be partial orders, i.e. one buy order matched to multiple sell order, or one sell order matched to multiple buy order. Each part will be a separate row in table.
- Sometimes Robinhood split one order into multiple parts even when there is no partial matching, because the order was executed in multiple parts, so you need to add them together to match the statement here.
