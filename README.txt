moh - a simple and command line based accounting software
Copyright (C) 2012  Yoriyuki Yamagata

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

1. First, install ocaml and make command "ocaml" work from your shell.
2. Put moh.ml somewhere.  

That's all.

* Usage

** Preparation of Financial Data

To use moh, first you need to prepare your financial data.  moh does
not require the specific format for them.  You only need to put the
line as follow to some plain text file in the specified directory or
its subdirectories.

[2012-11-29]$ Wallet -> Expense lunch 7-11 convenience store 700

This means that 700 yen/doller/euro... of currency are transferred
from the account "Wallet" to "Expense", and its category is "lunch".
"7-11 convenience store" is a comment.

Wallet, Expense and Income are special accounts.  The above
transaction can be written as

[2012-11-29]$ lunch 7-11 convenience store 700

If you are paid salary 400000 Yen, you can write as

[2012-11-29]$$ salary 400000

moh ignores any line which does not fit these format.

** Generate a report

Then, you can create a report by invoking moh.  If you put the data
into the directory XXX or its subdirectories, you can obtain the
annual report of Wallet by
 
ocaml moh.ml -d XXX Wallet 20120101 20121231

If you omit -d, the current directory is assumed.

* Future plan

- Balance sheet
- Different currency and other price changing materials.

Enjoy!
