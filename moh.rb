require 'date'

class Currency
  def initialize(rate,  amount)
    @rate = rate
    @amount = amount
  end

  def value 
    @amount * @rate
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

  def get_grandchild(path)
    if path.length > 0 then
      name = path.shift
      get_child(name).get_grandchild(path)
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

def dir_scanner(path, suffix)
  Dir.glob("#{File.expand_path(path)}/**{,/*/**}/*.#{suffix}") {|file| yield(file)}
end
