require 'minitest/autorun'
require 'structured'


class StructuredTest < Minitest::Test

  class Book
    include Structured
    element :title, String
  end

  def test_book
    b = Book.new({ 'title' => 'War and Peace' })
    assert_equal('War and Peace', b.instance_variable_get(:@title))
  end

  def test_book_symbol
    b = Book.new({ title: 'War and Peace' })
    assert_equal('War and Peace', b.instance_variable_get(:@title))
  end

  def test_book_invalid_param
    assert_raises(NameError) do
      Book.new({ title: 'War and Peace', :invalid => 123 })
    end
  end

  def test_book_missing_param
    assert_raises(ArgumentError) do
      Book.new({ })
    end
  end

  class OptionalItem
    include Structured
    element :optitem, String, optional: true
  end
  def test_optional_item
    x = OptionalItem.new({})
    refute(x.instance_variable_defined?(:@optitem))
    x = OptionalItem.new({ :optitem => 'Optional'})
    assert_equal('Optional', x.instance_variable_get(:@optitem))
  end

  class PreprocItem
    include Structured
    element :processed, String, preproc: proc { |x| "#{x}!" }
  end
  def test_preproc
    x = PreprocItem.new(:processed => "hello")
    assert_equal("hello!", x.instance_variable_get(:@processed))
  end

  class ArrayItem
    include Structured
    element :books, [ Book ]
  end
  def test_arrayitems
    x = ArrayItem.new({
      'books' => [
        { :title => 'One' },
        { :title => 'Two' },
      ]
    })
    b = x.instance_variable_get(:@books)
    assert_instance_of(Array, b)
    assert_equal(2, b.count)

    assert_instance_of(Book, b[0])
    assert_equal('One', b[0].title)

    assert_instance_of(Book, b[1])
    assert_equal('Two', b[1].title)
  end

  class HashItems
    include Structured
    element :strhash, { String => String }
    element :objhash, { String => Book }
  end
  def test_hashitems
    x = HashItems.new(
      :strhash => { 'a' => 'b', 'c' => 'd' },
      :objhash => { 'a' => { :title => 'One' }, 'b' => { :title => 'Two' } },
    )
    s = x.instance_variable_get(:@strhash)
    assert_instance_of(Hash, s)
    assert_equal({ 'a' => 'b', 'c' => 'd' }, s)

    o = x.instance_variable_get(:@objhash)
    assert_instance_of(Hash, o)
    assert_equal(2, o.count)

    assert_instance_of(Book, o['a'])
    assert_equal('One', o['a'].title)
    assert_equal('a', o['a'].instance_variable_get(:@key))

    assert_instance_of(Book, o['b'])
    assert_equal('Two', o['b'].title)
    assert_equal('b', o['b'].instance_variable_get(:@key))
  end


  class DefaultItems
    include Structured
    element :title, String, optional: true
    default_element Integer
    def receive_any(key, val)
      (@items ||= {})[key] = val
    end
    attr_reader :items
  end

  def test_default_empty
    a = DefaultItems.new({})
    assert a.items.nil?
    assert_nil a.title
  end

  def test_default_only
    a = DefaultItems.new({
      'one' => 1, :two => 2, three: 3,
    })
    assert_nil a.title
    assert_instance_of(Hash, a.items)
    assert_equal 3, a.items.count
    assert_equal 1, a.items[:one]
    assert_equal 2, a.items[:two]
    assert_equal 3, a.items[:three]
  end


  def test_default_title
    a = DefaultItems.new({
      'one' => 1, :two => 2, three: 3, title: 'Hello World'
    })
    assert_equal 'Hello World', a.title
    assert_instance_of(Hash, a.items)
    assert_equal 3, a.items.count
    assert_equal 1, a.items[:one]
    assert_equal 2, a.items[:two]
    assert_equal 3, a.items[:three]
  end

end


