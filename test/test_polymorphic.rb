require 'minitest/autorun'
require 'structured'

class PolymorphicTest < Minitest::Test

  class Thing
    include StructuredPolymorphic
  end

  class Book < Thing
    element :title, String
  end

  class Car < Thing
    element :model, String
  end

  Thing.types car: Car, book: Book

  def test_description
    text = 'A thing class'
    Thing.set_description(text)
    assert_equal(text, Thing.description)

    1.upto(text.length) do |i|
      assert_equal(i, Thing.description(i).length)
    end
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

  def test_polymorphic_explain
    io = StringIO.new
    Thing.explain(io)
    s = io.string
    assert_match(/Thing/, s)
    assert_match(/Book/, s)
    assert_match(/Car/, s)
  end

  def test_polymorphic_template
    s = Thing.template
    assert_match(/type:/, s)
  end


  class ThingContainer
    include Structured
    element :things, { String => Thing }
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
