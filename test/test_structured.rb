require 'minitest/autorun'
require 'structured'


class StructuredTest < Minitest::Test

  class Book
    include Structured
    element :title, String
  end

  def test_description
    text = 'A book class'
    Book.set_description(text)
    assert_equal(text, Book.description)

    1.upto(text.length) do |i|
      assert_equal(i, Book.description(i).length)
    end
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
    assert_raises(Structured::InputError) do
      Book.new({ title: 'War and Peace', :invalid => 123 })
    end
  end

  def test_book_invalid_param_type
    assert_raises(Structured::InputError) do
      Book.new({ title: 12 })
    end
    assert_raises(Structured::InputError) do
      Book.new({ title: { title: "Hello world" } })
    end
  end

  def test_book_missing_param
    assert_raises(Structured::InputError) do
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

  class DefaultObjectItems
    include Structured
    default_element Object
    def receive_any(key, val)
      (@items ||= {})[key] = val
    end
    attr_reader :items
  end

  def test_default_false
    a = DefaultObjectItems.new({ one: false, two: true })
    assert_includes a.items, :one
    assert_kind_of FalseClass, a.items[:one]
    assert_includes a.items, :two
    assert_kind_of TrueClass, a.items[:two]
  end

  class ModDefaultItems
    include Structured
    default_element(Integer, key: {
      type: String,
      preproc: proc { |s| s + "!" },
    })
    def receive_any(key, val)
      (@items ||= {})[key] = val
    end
    attr_reader :items
  end

  def test_mod_default
    a = ModDefaultItems.new({ 'a' => 1 })
    assert_instance_of(Hash, a.items)
    assert_equal({ 'a!' => 1 }, a.items)
  end

  def test_mod_default_key_type
    assert_raises(Structured::InputError) {
      ModDefaultItems.new({ :a => 1 })
    }
  end

  class PreInitializer
    include Structured
    element :title, String

    def pre_initialize
      @actions = [ 'pre-initialize' ]
    end
    def receive_parent(parent)
      @actions.push('receive parent')
    end
    def receive_title(title)
      @actions.push('receive title')
    end
    attr_reader :actions
  end

  def test_preinitialize
    pi = PreInitializer.new({ :title => 'Title' }, parent = 'hello')
    assert_equal([
      'pre-initialize', 'receive parent', 'receive title',
    ], pi.actions)
  end

  class CheckItem
    include Structured
    element :choice, String, check: %w(a b c d)
    element :word, String, check: /\A\w+\z/
    element :opt_no_e, String, optional: true,
      check: proc { |w| !w.include?('e') }
  end

  def test_check_success
    c = CheckItem.new({ choice: 'a', word: 'hello', opt_no_e: 'infinity' })
    assert_equal('a', c.choice)
    assert_equal('hello', c.word)
    assert_equal('infinity', c.opt_no_e)

    c = CheckItem.new({ choice: 'a', word: 'hello' })
    assert_equal('a', c.choice)
    assert_equal('hello', c.word)
  end

  def test_check_fail
    assert_raises(Structured::InputError) {
      CheckItem.new({ choice: 'q', word: 'hello', opt_no_e: 'infinity' })
    }
    assert_raises(Structured::InputError) {
      CheckItem.new({ choice: 'a', word: 'hello!', opt_no_e: 'infinity' })
    }
    assert_raises(Structured::InputError) {
      CheckItem.new({ choice: 'a', word: 'hello', opt_no_e: 'infinite' })
    }
  end

  class BookShelf
    include Structured
    element :kids_books, { Symbol => Book }, optional: true
    default_element Book
    def receive_any(name, book)
      @adult_books[name] = book
    end
    def pre_initialize
      @adult_books = {}
    end
    attr_reader :adult_books
  end

  def test_hierarchy
    b = BookShelf.new({
      kids_books: {
        first: { title: 'Thomas' },
        second: { title: 'Percy' },
      }
    })
    assert_equal 2, b.kids_books.count
    assert_equal 0, b.adult_books.count
    assert_instance_of Book, b.kids_books[:first]
    assert_equal 'Thomas', b.kids_books[:first].title

    assert_instance_of Book, b.kids_books[:second]
    assert_equal 'Percy', b.kids_books[:second].title
  end

  def test_hierarchy_default
    b = BookShelf.new({
      first: { title: 'Thomas' },
      second: { title: 'Percy' },
    })
    assert_nil b.kids_books
    assert_equal 2, b.adult_books.count
    assert_instance_of Book, b.adult_books[:first]
    assert_equal 'Thomas', b.adult_books[:first].title

    assert_instance_of Book, b.adult_books[:second]
    assert_equal 'Percy', b.adult_books[:second].title
  end

  def test_hierarchy_wrong_class
    assert_raises(Structured::InputError) {
      BookShelf.new({ first: "Hello World" })
    }
    assert_raises(Structured::InputError) {
      BookShelf.new({ kids_books: { first: "Hello World" } })
    }

    assert_raises(Structured::InputError) {
      BookShelf.new({ kids_books: { first: { notitle: "given" } } })
    }
  end

  def test_explain
    io = StringIO.new
    BookShelf.explain(io)
    s = io.string
    assert_match(/BookShelf/, s)
    assert_match(/kids_books/, s)
  end

  def test_template
    s = BookShelf.template
    assert_match(/kids_books/, s)
    assert_match(/title/, s)
  end


  class DefaultValues
    include Structured

    element :optval, String, optional: true, default: "default value"
  end

  def test_default_values_given
    dv = DefaultValues.new({ optval: "given value" })
    assert_equal "given value", dv.optval
  end

  def test_default_values_inferred
    dv = DefaultValues.new({})
    assert_equal "default value", dv.optval
  end

  def test_default_values_checks_type
    assert_raises(Structured::InputError) {
      DefaultValues.new({ optval: 15 })
    }
  end


  class AutoConversion
    include Structured
    element :regexp, Regexp, optional: true
    element :str, String, optional: true
    element :table, { String => Integer }, optional: true
  end

  def test_autoconv_regexp
    ac = AutoConversion.new({ regexp: "abc\\s+def" })
    assert_equal(/abc\s+def/, ac.regexp)
  end

  def test_autoconv_string
    ac = AutoConversion.new({ :str => :symbol })
    assert_equal("symbol", ac.str)
  end

  def test_autoconv_hash_string
    ac = AutoConversion.new({ :table => { :key => 15 } })
    assert_equal([ 'key' ], ac.table.keys)
  end

  class DefaultFalseValue
    include Structured

    element :optval, :boolean, optional: true, default: false
  end

  def test_default_false_given
    dfv = DefaultFalseValue.new({ optval: true })
    assert_kind_of TrueClass, dfv.optval
  end

  def test_default_false_inferred
    dfv = DefaultFalseValue.new({})
    assert_kind_of FalseClass, dfv.optval
  end


end


