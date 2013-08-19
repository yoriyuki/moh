require 'moh'
require 'test/unit'

class TestYen < Test::Unit::TestCase
  def test_simple
    yen = Yen.new(1, 100)
    assert_equal(100, yen.value)
    Yen.current_rate = 10
    assert_equal(1000, yen.current_value)

    assert_equal(-100, (-yen).value)
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

    child_book = Book.new("Child", book)
    assert_equal(child_book, book.get_child("Child"))
    assert_equal(["Test", "Child"], child_book.full_path)
    assert_equal(child_book, book.get_grandchild(["Child"]))

    t3 = Transaction.new(Date.new(2013,1,3), 'Book1', 
                         Yen.new(1, -100), 'A')
    child_book.add_transaction(t3)
    assert_equal([t1, t2, t3], book.get_transactions)
    assert_equal(100, book.credit_sum{ |t| true })
  end
end


class TestBookReader < Test::Unit::TestCase
  def test_add_line
    book_reader = BookReader.new
    book_reader.add_line('2013-08-13', ['Wallet'], ['Expense', 'life'], 'electricity', 3000)

    assert_equal(3000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(3000, book_reader.root_book.credit_sum{ |t| true })
  end

  def test_parse_line_generic
    book_reader = BookReader.new
    book_reader.parse_line_generic('[2013-08-13]$ Wallet Expense:life electricity 3000')

    assert_equal(3000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(3000, book_reader.root_book.credit_sum{ |t| true })    
  end

  def test_parse_line_generic
    book_reader = BookReader.new
    book_reader.parse_line_old_generic('[2013-08-13]$ Wallet -> Expense life electricity 3000')

    assert_equal(3000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(3000, book_reader.root_book.credit_sum{ |t| true })    
  end

  def test_parse_line_old_expense
    book_reader = BookReader.new
    book_reader.parse_line_old_expense('[2013-08-13]$ life electricity 3000')

    assert_equal(3000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(3000, book_reader.root_book.credit_sum{ |t| true })    
  end

  def test_parse_line_old_income
    book_reader = BookReader.new
    book_reader.parse_line_old_income('[2013-08-13]$$ salary XX Inc. 3000')
    assert_equal(3000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(3000, book_reader.root_book.credit_sum{ |t| true })    
  end

  def test_parse_line
    book_reader = BookReader.new
    book_reader.parse_line('[2013-08-13]$ Wallet Expense:life electricity 3000')
    book_reader.parse_line('[2013-08-13]$ Wallet -> Expense life electricity 3000')
    book_reader.parse_line('[2013-08-13]$ life electricity 3000')
    book_reader.parse_line('[2013-08-13]$$ salary XX Inc. 3000')
    assert_equal(12000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(12000, book_reader.root_book.credit_sum{ |t| true })        
  end


end


