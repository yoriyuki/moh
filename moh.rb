require 'date'
require 'optparse'

class Transaction
  include Comparable
  @@pool = []
  def Transaction.each
    @@pool.each { |t| yield t }
  end

  def Transaction.clear
    @@pool = []
  end

  private
  #amount is plus when the money moves from [source] to [target]
  attr_writer :date, :source, :target, :sort, :amount, :comment 
  public 
  attr_reader :date, :source, :target, :sort, :amount, :comment

  # amount > 0
  def initialize(date, source, target, amount, comment)
    self.date = date
    self.comment = comment
    if amount > 0 then
      self.source = source
      self.target = target
      self.amount = amount
    elsif amount < 0 then
      self.source = target
      self.target = source
      self.amount = -amount
    end
      @@pool << self
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

  def from_to(source, target)
    
  end
end

def initial_of(path1, path2) 
  if path1 == [] then 
    return true 
  elsif path2 == [] then
    return false
  elsif path1[0] == path2[0] then
    return initial_of(path1[1..-1], path2[1..-1])
  else
    return false
  end
end


class Book
  include Comparable
  protected
  attr_reader :parent, :children
  attr_writer :name, :children, :parent
  public
  attr_reader :name

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

  def fqdn
    full_path.inject{|s, n| s + ':' + n}
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

  def is_contained(book)
    initial_of(book.full_path, self.full_path)
  end

  def debit_sum
    sum = 0
    Transaction.each do |t|
      if yield(t) & t.source.is_contained(self) then
        sum += t.amount
      end
    end
    return sum
  end

  def credit_sum
    sum = 0
    Transaction.each do |t|
      if yield(t) & t.target.is_contained(self) then
        sum += t.amount
      end
    end
    return sum
  end

  def balance(date=nil)
    debit_sum = debit_sum{|t| t.is_in_dates(nil, date)}
    credit_sum = credit_sum {|t| t.is_in_dates(nil, date)}
    credit_sum - debit_sum
  end
end

#IO

##Input
LINE_GENERIC = /^\[(\d{4}-\d{2}-\d{2})\]\$\s+(\S+)\s+(\S+)\s+(.*\S?)\s+(\d+)\s*$/
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
      
      Transaction.new(date, book1, book2, amount, comment)
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

  def parse_line_set_balance(line)
    md = LINE_BALANCE.match(line)
    if md then
      set_balance(md[1], md[2].split(':'), md[3].to_i)
    else
      false
    end
  end

  def parse_line(line) 
    if parse_line_generic(line) then return
    elsif parse_line_set_balance(line) then return
    else return end
  end

  def parse_old_line(line)
    if parse_line_old_generic(line) then return 
    elsif parse_line_old_income(line) then return
    elsif parse_line_old_expense(line) then return
    else return end
  end
end

##Output

class BookWriter
  protected
  attr_writer :book

  def print_transaction(t)
    puts "[#{t.date.to_s}]$\t#{t.source.fqdn}\t#{t.target.fqdn}\t#{t.comment}\t#{t.amount.to_s}"
  end

  public
  attr_reader :book

  def initialize(book)
    self.book = book
  end

  def print_summary(date1, date2)
    debit = 0
    Transaction.each do |t|
      if 
          t.is_in_dates(date1, date2)    \
        and t.source.is_contained(book)
      then
        debit += t.amount
      end
    end
    credit = 0
    Transaction.each do |t|
      if 
          t.is_in_dates(date1, date2)    \
        and t.target.is_contained(book)
      then
        credit += t.amount
      end
    end
    if credit != 0 or debit != 0 then
      puts "#{book.fqdn}\t#{credit}\t#{debit}\t#{credit - debit}"
    end
    book.get_children.sort.each{|b| BookWriter.new(b).print_summary(date1, date2)}
  end

  def print_transactions(date1=nil, date2=nil)
    transactions = []
    Transaction.each do |t|
      if 
          t.is_in_dates(date1, date2)    \
        and t.source.is_contained(book)
      then
        transactions << t
      end
    end
    transactions.sort.each{|t| print_transaction(t)}
  end
end


## Main
if $0 == __FILE__ then
puts 'moh -- simple, commandline-based accounting software'
puts '(C) 2012, 2013: Yoriyuki Yamagata'
puts 'See LICENSE.txt for the licence.'
opt = OptionParser.new
book_reader = BookReader.new
howm_dir = nil
howm_suffix = 'howm'
print_summary = false
print_transactions = false
Version = "0.2.0"

opt.on('-d [dir]'){|dir| howm_dir = dir}
opt.on('--howm_suffix=[suffix]'){ |suffix| howm_suffix=suffix }
opt.on('-s', '--summary'){ |b| print_summary = true }
opt.on('-t', '--transactions'){ |b| print_transactions = true }

values = []
opt.order!{ |v| values << v }

def dir_scanner(path, suffix)
  Dir.glob("#{File.expand_path(path)}/**{,/*/**}/*.#{suffix}") {|path| yield(path)}
end

if howm_dir then 
  dir_scanner(howm_dir, howm_suffix) do |path|
    File.open(path){ |file| file.each{|line| 
          book_reader.parse_line(line)
        }}
  end
end

if values.length == 3 then
  book = book_reader.root_book.get_grandchild(values[0].split(':'))
  book_writer = BookWriter.new(book)
end

if print_summary then
  puts '*Summary'
  book_writer.print_summary(Date.parse(values[1]), Date.parse(values[2]))
end

if print_transactions then
  puts '*Transactions'
  book_writer.print_transactions(Date.parse(values[1]), Date.parse(values[2]))
end

end
