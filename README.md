moh - a simple and command line based accounting software
Copyright (C) 2012, 2013, 2014  Yoriyuki Yamagata

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

# How to install

The installation is easy.

1. First, install ruby.  moh works the builtin ruby of Mac OS X Yosemite.  So, If you use MacOS X Yosemite, you do not need to do anything

2. Put moh.rb somewhere.  

That's all.

# Usage

## Preparation of Financial Data

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

moh ignores any line which does not fit this format.

Beside plain text, moh support DayOne dairy app.  Just put your financial data in the same format into your diary.  

## Generate a summary

Then, you can create a report by invoking moh.  If you put the data
into the directory XXX or its subdirectories, you can obtain the
annual report of Wallet by
```shell
$ ruby moh.rb -d XXX -s Wallet 20120101 20121231
```
(In the examples, moh.rb is located in the current directory.  If not, replace moh.rb to the path of moh.rb)

You can specify multiple directories.
```shell
$ ruby moh.rb -d XXX -d YYY -s Wallet 20120101 20121231
```

However, you need at least one -d option to specify the directory.  You can change the suffix of files which moh searches.  If you use -t instead of -s, moh outputs all transaction between given dates.

The default behavior is to search `*.txt` files.  But you can change the suffix of files which contain financial data.
```shell
$ ruby moh.rb -d XXX --txt_suffix=text -s Wallet 20120101 20121231
```

In addition, moh supports DayOne diary application.  Specify the location of DayOne `entries` directory after `--dayone=` option.
```shell
$ ruby moh.rb --dayone=XXX -s Wallet 20120101 20121231
```

You can mix plain text and dayone entries.
```shell
$ ruby moh.rb -d XXX -dayone=YYY -s Wallet 20120101 20121231
```

The default behavior of summary mode prints out summations of all hierarchies of entries.  You can change this behavior by specifying `-D` option.  For example,
```shell
$ ruby moh.rb -d XXX -dayone=YYY -s -D 2 Wallet 20120101 20121231
```
only shows the summaries of one and second levels of nested accounts.

Enjoy!
