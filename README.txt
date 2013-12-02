moh - a simple and command line based accounting software
Copyright (C) 2012, 2013  Yoriyuki Yamagata

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

You can contact the author by email yoriyuki.y@gmail.com

* How to install

The installation is easy.

1. First, install ruby.  moh was developed using ruby 1.8.7, so if you are using Mac OS X 10.8, you do not need to do anything.

2. Put moh.rb somewhere.  

That's all.

* Usage

** Preparation of Financial Data

To use moh, first you need to prepare your financial data.  moh does
not require the specific format for them.  You only need to put 
lines as follow to some plain text file in a specified directory or
its subdirectories.

[2012-11-29]$ Wallet  Expense 7-11 convenience store 700

This means that 700 yen/doller/euro... of currency are transferred
from the account "Wallet" to "Expense".
"7-11 convenience store" is a comment.  

Accounts can form hierarchies.  For example, you can write Expense:Lunch to indicate the nested accounts.

[2012-11-29]$ Wallet  Expense:Lunch 7-11 convenience store 700

Transactions of Expense:Lunch are counted as those of Expense and Expense:Lunch simultaneously.

If you know how much money in an account, you can reset the balance of the account.

[2013-08-01]$= Wallet 6000

This set the balance of Wallet 6000.  If this is not equal to the balance calculated, moh automatically inserts the transaction to Expense:Unknown or Income:Unknown.

OCaml version of moh uses different formats.  They are supported but using them are strongly discouraged.

moh ignores any line which does not fit this format.

** Generate a summary

Then, you can create a report by invoking moh.  If you put the data
into the directory XXX or its subdirectories, you can obtain the
annual report of Wallet by
 
$ ruby moh.rb -d XXX -s Wallet 20120101 20121231

If you omit -d, the current directory is assumed.  You can change the suffix of files which moh searches.  If you use -t instead of -s, moh outputs all transaction between given dates.

The default behavior is to search *.howm files.  But you can change the suffix of files which contain financial data.
$ ruby moh.rb -d XXX --howm_suffix=txt -s Wallet 20120101 20121231

* Future plan

- Different currency and other price changing materials.

Enjoy!
