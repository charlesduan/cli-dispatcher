require 'minitest/autorun'
require 'structured'


class StructuredTest < Minitest::Test

  class Book
    include Structured
    element :title, String
    attr_reader :title
  end

  def test_book
    b = Book.new({ 'title' => 'War and Peace' })
    assert_equal('War and Peace', b.instance_variable_get(:@title))
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
end


