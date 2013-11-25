# -*- coding: utf-8 -*-
require 'moh'
require 'test/unit'

class TestHelpers < Test::Unit::TestCase
  def test_initial_of
    assert_equal(true, initial_of([], []))
    assert_equal(true, initial_of([], ["A"]))
    assert_equal(true, initial_of(["A"], ["A"]))
    assert_equal(true, initial_of(["A"], ["A", "B"]))
    assert_equal(false, initial_of(["B"], ["A", "B"]))
  end
end


class TestTransaction < Test::Unit::TestCase
  def test_compare 
    Transaction.clear
    t1 = Transaction.new(Date.new(2013,1,1), 'Book', 'Book1', 100, 'A')
    t2 = Transaction.new(Date.new(2013,1,2), 'Book', 'Book1', 100, 'A')
    t3 = Transaction.new(Date.new(2013,1,2), 'Book', 'Book2', 100, 'A')
    t4 = Transaction.new(Date.new(2013,1,2), 'Book', 'Book2', 200, 'A')
    t5 = Transaction.new(Date.new(2013,1,2), 'Book', 'Book2', 200, 'B')

    assert_equal(true, t1 == t1)
    assert_equal(true, t1 < t2)
    assert_equal(true, t2 < t3)
    assert_equal(true, t3 < t4)
    assert_equal(true, t4 < t5)
  end
end

class TestBook < Test::Unit::TestCase
  
  def test_simple
    Transaction.clear
    book1 = Book.new("Book1")
    book2 = Book.new("Book2")
    assert_equal(["Book1"], book1.full_path)
    assert_equal("Book1", book1.fqdn)
    
    t1 = Transaction.new(Date.new(2013,1,1), book1, book2,
                         100, 'A')
    t2 = Transaction.new(Date.new(2013,1,2), book1, book2, 
                         100, 'A')
    
    assert_equal(200, book1.debit_sum{ |t| true })
    assert_equal(0, book1.credit_sum{ |t| true })

    child_book = Book.new("Child", book1)
    assert_equal(child_book, book1.get_child("Child"))
    assert_equal(["Book1", "Child"], child_book.full_path)
    assert_equal(child_book, book1.get_grandchild(["Child"]))
    assert_equal(true, child_book.is_contained(book1))

    t3 = Transaction.new(Date.new(2013,1,3), child_book, book2, 
                         -100, 'A')
    assert_equal(200, book1.debit_sum{ |t| true })
    assert_equal(-100, book1.balance)
  end
end


class TestBookReader < Test::Unit::TestCase
  def test_add_line
    Transaction.clear
    book_reader = BookReader.new
    book_reader.add_line('2013-08-13', ['Wallet'], ['Expense', 'life'], 'electricity', 3000)

    assert_equal(3000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(3000, book_reader.root_book.credit_sum{ |t| true })
  end

  def test_set_balance
    Transaction.clear
    book_reader = BookReader.new
    book_reader.add_line('2013-08-13', ['Wallet'], ['Expense', 'life'], 'electricity', 3000)
    book_reader.set_balance('2013-08-14', ['Wallet'], 0)

    assert_equal(0, book_reader.root_book.balance)
  end


  def test_parse_line_generic
    Transaction.clear
    book_reader = BookReader.new
    book_reader.parse_line_generic('[2013-08-13]$ Wallet Expense:life electricity 3000')

    assert_equal(3000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(3000, book_reader.root_book.credit_sum{ |t| true })    
  end

  def test_parse_line_generic
    Transaction.clear
    book_reader = BookReader.new
    book_reader.parse_line_old_generic('[2013-08-13]$ Wallet -> Expense life electricity 3000')

    assert_equal(3000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(3000, book_reader.root_book.credit_sum{ |t| true })    
  end

  def test_parse_line_old_expense
    Transaction.clear
    book_reader = BookReader.new
    book_reader.parse_line_old_expense('[2013-08-13]$ life electricity 3000')

    assert_equal(3000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(3000, book_reader.root_book.credit_sum{ |t| true })    
  end

  def test_parse_line_old_income
    Transaction.clear
    book_reader = BookReader.new
    book_reader.parse_line_old_income('[2013-08-13]$$ salary XX Inc. 3000')
    assert_equal(3000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(3000, book_reader.root_book.credit_sum{ |t| true })    
  end

  def test_parse_old_line
    Transaction.clear
    book_reader = BookReader.new
    book_reader.parse_old_line('[2013-08-13]$ Wallet Expense:life electricity 3000')
    book_reader.parse_old_line('[2013-08-13]$ Wallet -> Expense life electricity 3000')
    book_reader.parse_old_line('[2013-08-13]$ life electricity 3000')
    book_reader.parse_old_line('[2013-08-13]$$ salary XX Inc. 3000')
    assert_equal(12000, book_reader.root_book.debit_sum{ |t| true })
    assert_equal(12000, book_reader.root_book.credit_sum{ |t| true })
  end
end

class TestBookWriter < Test::Unit::TestCase
  def test_print  
    Transaction.clear
    book_reader = BookReader.new
    book_reader.parse_line('[2013-08-01]$= Wallet 6000')
    book_reader.parse_line('[2013-08-13]$ Wallet Expense:life electricity 3000')
    book_reader.parse_line('[2013-08-13]$ Wallet -> Expense life electricity 3000')
    book_reader.parse_line('[2013-08-13]$ life electricity 3000')
    book_reader.parse_line('[2013-08-13]$$ salary XX Inc. 3000')
    book = book_reader.root_book
    
    book_writer = BookWriter.new(book)
    book_writer.print_summary(Date.new(2013, 01, 01), Date.new(2013, 12, 31))
    book_writer.print_transactions(Date.new(2013, 01, 01), Date.new(2013, 12, 31))
  end
end
