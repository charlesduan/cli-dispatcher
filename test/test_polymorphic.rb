require 'minitest/autorun'
require 'structured'

class PolymorphicTest < Minitest::Test

  class Book
    include Structured
    element :title, String
    attr_reader :title
  end

  class Car
    include Structured
    element :model, String
    attr_reader :model
  end

  class Thing
    include StructuredPolymorphic
    types car: Car, book: Book
  end

  def test_polymorphic_car
    t = Thing.new(:type => 'car', :model => 'Toyota')
    assert_instance_of(Car, t)
    assert_equal('Toyota', t.model)
  end

  def test_polymorphic_book
    t = Thing.new(:type => 'book', :title => 'Bluebook')
    assert_instance_of(Book, t)
    assert_equal('Bluebook', t.title)
  end


  class ThingContainer
    include Structured
    element :things, { String => Thing }
    attr_reader :things
  end

  def test_polymorphic_container
    tc = ThingContainer.new(:things => {
      'b' => { :type => 'book', :title => 'Bluebook' },
      'c' => { :type => 'car', :model => 'Toyota' },
    })
    assert_instance_of(ThingContainer, tc)
    tgs = tc.things
    assert_instance_of(Hash, tgs)
    assert_equal(2, tgs.count)

    tb = tgs['b']
    assert_instance_of(Book, tb)
    assert_equal('Bluebook', tb.title)
    assert_equal('b', tb.instance_variable_get(:@key))

    tc = tgs['c']
    assert_instance_of(Car, tc)
    assert_equal('Toyota', tc.model)
    assert_equal('c', tc.instance_variable_get(:@key))
  end

end
