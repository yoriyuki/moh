require 'date'
require 'rubygems'
require 'when_exe'
include When
require 'csv'
require 'optparse'

class Transaction
  include Comparable
  private
  attr_writer :date, :target, :sort, :amount, :comment
  public 
  attr_reader :date, :target, :sort, :amount, :comment

  def initialize(date, target, amount, comment)
    self.date = date
    self.target = target
    self.amount = amount
    self.comment = comment
  end

  def <=>(other)
    (self.date <=> other.date) != 0 ? self.date <=> other.date :
      (self.target <=> other.target) != 0 ? self.target <=> other.target : 
      (self.amount <=> other.amount) != 0 ? self.amount <=> other.amount :
      self.comment <=> other.comment
  end

  def is_in_dates(date1, date2)
    (not date1 or date >= date1) && (not date2 or date <= date2)
  end
end

class Book
  include Comparable
  protected
  attr_reader :parent, :children
  attr_writer :name, :children, :transactions, :parent
  public
  attr_reader :name, :transactions

  def add_child(book)
    if self.children then 
      self.children[book.name] = book 
    else
      self.children = {book.name => book}
    end
  end

  def get_child(name)
    self.children ? self.children[name] : nil
  end

  def get_children
    if self.children then self.children.map {|name, b| b} else [] end
  end

  def initialize(name, book = nil)
    self.name = name
    self.transactions = []
    if book then book.add_child(self) end
    self.parent = book
  end

  def full_path
    if parent then
      parent.full_path << self.name
    else 
      self.name.length == 0 ? [] : [self.name]
    end
  end

  def get_grandchild(path, create = false)
    if path.length > 0 then
      path = path.dup
      name = path.shift
      get_child(name) ? get_child(name).get_grandchild(path, create) : 
        (create ? Book.new(name, self).get_grandchild(path, create) : nil)
    else
      self
    end
  end

  def <=>(other) 
    full_path <=> other.full_path
  end

  def add_transaction(transaction)
    transactions << transaction    
  end

  def debit_sum
    if children then
      sum = children.inject(0) do |sum, pair| 
        sum + pair[1].debit_sum { |t| t.amount < 0 && (yield t) }
      end
    else
      sum = 0
    end

    filtered = transactions.find_all { |t| t.amount < 0 && (yield t) }
    return filtered.inject(sum) { |sum, t| sum - t.amount}
  end

  def credit_sum
    if children then
      sum = children.inject(0) do |sum, pair| 
        sum + pair[1].credit_sum { |t| t.amount > 0 && (yield t) }
      end
    else
      sum = 0
    end

    filtered = transactions.find_all { |t| t.amount > 0 && (yield t) }
    return filtered.inject(sum) { |sum, t| sum + t.amount}
  end

  def balance(date=nil)
    debit_sum = debit_sum{|t| t.is_in_dates(nil, date)}
    credit_sum = credit_sum {|t| t.is_in_dates(nil, date)}
    debit_sum - credit_sum    
  end
end

#IO

##Input
LINE_GENERIC = /^\[(\d{4}-\d{2}-\d{2})\]\$\s+(\S+)\s+(\S+)\s+(.*\S)\s+(\d+)\s*$/
LINE_OLD_GENERIC = /^\[(\d{4}-\d{2}-\d{2})\]\$\s+(\S+)\s+->\s+(\S+)\s+(\S*)\s+(.*\S)\s+(\d+)\s*$/
LINE_OLD_EXPENSE = /^\[(\d{4}-\d{2}-\d{2})\]\$\s+(\S+)\s+(.*\S)\s+(\d+)\s*$/
LINE_OLD_INCOME = /^\[(\d{4}-\d{2}-\d{2})\]\$\$\s+(\S+)\s+(.*\S)\s+(\d+)\s*$/
LINE_BALANCE = /^\[(\d{4}-\d{2}-\d{2})\]\$=\s+(\S+)\s+(-?\d+)\s*$/

class BookReader
  protected
  attr_writer :root_book
  public
  attr_reader :root_book

  def initialize()
    self.root_book = Book.new('')
  end

  def add_line(date_string, path1, path2, comment, amount)
    begin
      date = Date.parse(date_string)

      book1 = self.root_book.get_grandchild(path1, true)
      book2 = self.root_book.get_grandchild(path2, true)
      
      t1 = Transaction.new(date, book2, amount, comment)
      t2 = Transaction.new(date, book1, -amount, comment)
      
      book1.add_transaction(t1)
      book2.add_transaction(t2)

      true
      
      rescue ArgumentError
      false
      end
    end

  def set_balance(date_string, path, amount)
    begin
      date = Date.parse(date_string)
      rescue ArgumentError
      return false
    end
    
    book = self.root_book.get_grandchild(path, true)
    diff = amount - book.balance(date)

    if diff > 0 then
      add_line(date_string, ['Income', 'Unknown'], path, 'Unknown', diff)
    elsif diff < 0 then
      add_line(date_string, path, ['Expense', 'Unknown'], 'Unknown', -diff)
    end

    true
  end

  def parse_line_generic(line)
    md = LINE_GENERIC.match(line)
    if md then 
      add_line(md[1], md[2].split(':'), md[3].split(':'), md[4], md[5].to_i)
    else
      false
    end
  end

  def parse_line_old_generic(line)
    md = LINE_OLD_GENERIC.match(line)
    if md then
      add_line(md[1], [md[2]], [md[3], md[4]], md[5], md[6].to_i)
    else
      false
    end
  end

  def parse_line_old_expense(line)
    md = LINE_OLD_EXPENSE.match(line)
    if md then
      add_line(md[1], ['Wallet'], ['Expense', md[2]], md[3], md[4].to_i)
    else
      false
    end
  end

  def parse_line_old_income(line)
    md = LINE_OLD_INCOME.match(line)
    if md then
      add_line(md[1], ['Income', md[2]], ['Wallet'], md[3], md[4].to_i)
    else
      false
    end
  end

  def parse_line_set_balance(line)
    md = LINE_BALANCE.match(line)
    if md then
      set_balance(md[1], md[2].split(':'), md[3].to_i)
    else
      false
    end
  end

  def parse_SMBC_line(line)
    columns = CSV.parse_line(line)

    date_string = (Calendar('Gregorian')  ^ when?(columns[0])).to_s

    if columns[1] == nil && columns[2].to_i > 0 then
      add_line(date_string, ['Income', 'unknown'], ['SMVC'], columns[3], columns[2].to_i)
    elsif columns[1].to_i > 0
      add_line(date_string, ['SMVC'], ['Expense', 'unknown'], columns[3], columns[1].to_i)
    end
    false
  end

  def parse_SMBCVISA_line(line)
    columns = CSV.parse_line(line)

    if columns[2].to_i != 0 then
      add_line(columns[0], ['SMVC_VISA'], ['Expense', 'unknown'], columns[1], columns[2].to_i)
    end
  end

  def parse_line(line) 
    if parse_line_old_generic(line) then return 
    elsif parse_line_generic(line) then return
    elsif parse_line_old_expense(line) then return
    elsif parse_line_old_income(line) then return
    elsif parse_line_set_balance(line) then return
    else return end
  end
end

##Output

class BookWriter
  protected
  attr_writer :book

  def fqdn(book = nil)
    if not book then book = self.book end
    book.full_path.inject{|s, n| s + ':' + n}
  end

  def print_transaction(t)
    puts "[#{t.date.to_s}]$\t#{fqdn}\t#{fqdn(t.target)}\t#{t.comment}\t#{t.amount.to_s}"
  end

  public
  attr_reader :book

  def initialize(book)
    self.book = book
  end

  def print_summary(date1, date2)
    debit_sum = book.debit_sum{|t| t.is_in_dates(date1, date2)}
    credit_sum = book.credit_sum {|t| t.is_in_dates(date1, date2)}
    puts "#{fqdn}\t#{credit_sum}\t#{debit_sum}\t#{debit_sum - credit_sum}"
    book.get_children.sort.each{|b| BookWriter.new(b).print_summary(date1, date2)}
  end

  def print_transactions(date1=nil, date2=nil)
    transactions = self.book.transactions.find_all{|t| t.is_in_dates(date1, date2)}
    transactions.sort.each{|t| print_transaction(t)}
    self.book.get_children.sort.each{|b| BookWriter.new(b).print_transactions(date1, date2)}
  end
end

## Main
puts 'moh -- simple, commandline-based accounting software'
puts '(C) 2012, 2013: Yoriyuki Yamagata'
puts 'See LICENSE.txt for the licence.'
opt = OptionParser.new
book_reader = BookReader.new
howm_dir = nil
howm_suffix = 'howm'
smbc_dir = nil
smbc_visa_dir = nil
print_summary = false
print_transactions = false

opt.on('-d [dir]'){|dir| howm_dir = dir}
opt.on('--howm_suffix=[suffix]'){ |suffix| howm_suffix=suffix }
opt.on('--smbc_dir=[dir]'){|dir| smbc_dir = dir}
opt.on('--smbcVISA_dir=[dir]'){ |dir| smbc_visa_dir = dir }
opt.on('-s', '--summary'){ |b| print_summary = true }
opt.on('-t', '--transactions'){ |b| print_transactions = true }

values = []
opt.order!{ |v| values << v }

def dir_scanner(path, suffix)
  Dir.glob("#{File.expand_path(path)}/**{,/*/**}/*.#{suffix}") {|path| yield(path)}
end

if howm_dir then 
  if not howm_suffix then howm_suffix = 'howm' end

  dir_scanner(howm_dir, howm_suffix) do |path|
    File.open(path){ |file| file.each{|line| book_reader.parse_line(line)}}
  end
end

if smbc_dir then
  dir_scanner(smbc_dir, 'cvs') do |path|
    file.readline
    file.each{ |line| book_reader.parse_SMBC_line(line)}
  end
end

if smbc_visa_dir then
  dir_scanner(smbc_visa_dir, 'cvs') do |file|
    file.readline
    file.each{ |line| book_reader.parse_SMBCVISA_line(line)}
  end
end

book_writer = BookWriter.new(book_reader.root_book.get_grandchild(values[0].split(':')))

if print_summary then
  puts '*Summary'
  book_writer.print_summary(Date.parse(values[1]), Date.parse(values[2]))
end

if print_transactions then
  puts '*Transactions'
  book_writer.print_transactions(Date.parse(values[1]), Date.parse(values[2]))
end

