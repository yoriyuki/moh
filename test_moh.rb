require 'moh'
require 'test/unit'

class TestYen < Test::Unit::TestCase
  def test_simple
    yen = Yen.new(1, 100)
    assert_equal(100, yen.value)
    Yen.current_rate = 10
    assert_equal(1000, yen.current_value)
  end
end

class TestTransaction < Test::Unit::TestCase
  def test_compare 
    t1 = Transaction.new(Date.new(2013,1,1), 'Book1', Yen.new(1, 100), 'A')
    t2 = Transaction.new(Date.new(2013,1,2), 'Book1', Yen.new(1, 100), 'A')
    t3 = Transaction.new(Date.new(2013,1,2), 'Book2', Yen.new(1, 100), 'A')
    t4 = Transaction.new(Date.new(2013,1,2), 'Book2', Yen.new(1, 200), 'A')
    t5 = Transaction.new(Date.new(2013,1,2), 'Book2', Yen.new(1, 200), 'B')

    assert_equal(true, t1 == t1)
    assert_equal(true, t1 < t2)
    assert_equal(true, t2 < t3)
    assert_equal(true, t3 < t4)
    assert_equal(true, t4 < t5)
  end
end

class TestBook < Test::Unit::TestCase
  
  def test_simple
    t1 = Transaction.new(Date.new(2013,1,1), 'Book1', 
                         Yen.new(1, 100), 'A')
    t2 = Transaction.new(Date.new(2013,1,2), 'Book1', 
                         Yen.new(1, 100), 'A')
    
    book = Book.new("Test")
    book.add_transaction(t1)
    book.add_transaction(t2)
    
    assert_equal(200, book.debit_sum{ |t| true })
    assert_equal(0, book.credit_sum{ |t| true })
  end
end





