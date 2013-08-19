require 'date'

class Currency
  def initialize(rate,  amount)
    @rate = rate
    @amount = amount
  end

  def value 
    @amount * @rate
  end

  def -@ 
    Currency.new(@rate, -@amount)
  end

end

class Yen < Currency
  @@current_rate = 1

  def current_value 
    @amount * @@current_rate
  end

  def Yen.current_rate=(rate) 
    @@current_rate = rate
  end
end

class Transaction
  include Comparable
  private
  attr_writer :date, :target, :sort, :comment, :currency
  public 
  attr_reader :date, :target, :sort, :comment, :currency

  def initialize(date, target, currency, comment)
    self.date = date
    self.target = target
    self.currency = currency
    self.comment = comment
  end

  def <=>(other)
    (self.date <=> other.date) != 0 ? self.date <=> other.date :
      (self.target <=> other.target) != 0 ? self.target <=> other.target : 
      (self.amount <=> other.amount) != 0 ? self.amount <=> other.amount :
      self.comment <=> other.comment
  end

  def amount
    self.currency.value
  end
end

class Book
  include Comparable
  protected
  attr_reader :children, :transactions, :parent
  attr_writer :name, :children, :transactions, :parent
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
      [self.name]
    end
  end

  def get_grandchild(path, create = false)
    if path.length > 0 then
      name = path.shift
      get_child(name) ? get_child(name).get_grandchild(path, create) : 
        (create ? Book.new(name, self) : nil)
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

  def get_transactions
    if children then
      ts = children.inject(transactions){ |ts, pair| ts + pair[1].get_transactions }
    else
      ts = transactions
    end
    ts.sort!
  end


  def debit_sum
    filtered = get_transactions.find_all { |t| t.amount > 0 && (yield t) }
    return filtered.inject(0) { |sum, t| sum + t.amount }
  end

  def credit_sum
    filtered = get_transactions.find_all { |t| t.amount < 0 && (yield t) }
    return filtered.inject(0) { |sum, t| sum - t.amount }
  end
end

#IO

##Input
def dir_scanner(path, suffix)
  Dir.glob("#{File.expand_path(path)}/**{,/*/**}/*.#{suffix}") {|file| yield(file)}
end

LINE_GENERIC = /^\[(\d{4}-\d{2}-\d{2})\]\$\s+(\S+)\s+(\S+)\s+(.*)\s+(\d+)$/
LINE_OLD_GENERIC = /^\[(\d{4}-\d{2}-\d{2})\]\$\s+(\S+)\s+->\s+(\S+)\s+(\S+)\s+(.*)\s+(\d+)$/
LINE_OLD_EXPENSE = /^\[(\d{4}-\d{2}-\d{2})\]\$\s+(\S+)\s+(.*)\s+(\d+)$/
LINE_OLD_INCOME = /^\[(\d{4}-\d{2}-\d{2})\]\$\$\s+(\S+)\s+(.*)\s+(\d+)$/

class BookReader
  protected
  attr_writer :root_book
  public
  attr_reader :root_book

  def initialize()
    self.root_book = Book.new("Root Book")
  end

  def add_line(date_string, path1, path2, comment, amount)
    begin
      date = Date.parse(date_string)

      book1 = self.root_book.get_grandchild(path1, true)
      book2 = self.root_book.get_grandchild(path2, true)
      currency = Yen.new(1, amount)
      
      t1 = Transaction.new(date, book2, -currency, comment)
      t2 = Transaction.new(date, book1, currency, comment)
      
      book1.add_transaction(t1)
      book2.add_transaction(t2)

      true
      
      rescue ArgumentError
      false
      end
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
      add_line(md[1], ['Wallet'], ['Income', md[2]], md[3], md[4].to_i)
    else
      false
    end
  end

  def parse_line(line) 
    if parse_line_generic(line) then return 
    elsif parse_line_old_generic(line) then return
    elsif parse_line_old_expense(line) then return
    elsif parse_line_old_income(line) then return
    else return end
  end
end

