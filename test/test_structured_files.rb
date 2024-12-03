require 'minitest/autorun'
require 'structured'


class StructuredFilesTest < Minitest::Test

  class Book
    include Structured
    element :title, String
    element :authors, [ String ], optional: true
  end

  def test_book_read_file
    Tempfile.create do |tf|
      tf.write(<<~EOF)
        ---
        title: "War and Peace"
      EOF
      tf.close
      b = Book.new({ read_file: tf.path })
      assert_equal('War and Peace', b.instance_variable_get(:@title))
    end
  end

  def test_book_read_file_fails
    Tempfile.create do |tf|
      tf.write(<<~EOF)
        ---
        title: []
      EOF
      tf.close
      assert_raises(Structured::InputError) do
        Book.new({ read_file: tf.path })
      end
    end
  end

  def test_book_read_file_override
    Tempfile.create do |tf|
      tf.write(<<~EOF)
        ---
        title: "War and Peace"
      EOF
      tf.close
      b = Book.new({ read_file: tf.path, title: "Pride and Prejudice" })
      assert_equal('Pride and Prejudice', b.title)
    end
  end

  def test_read_array
    Tempfile.create do |tf|
      tf.write(<<~EOF)
        ---
        - Peter S. Menell
        - Mark A. Lemley
        - Robert P. Merges
        - Shyamkrishna Balganesh
      EOF
      tf.close
      b = Book.new({ title: "IPNTA", authors: [ 'read_file', tf.path ] })
      assert_equal 4, b.authors.count
      assert_equal 'Peter S. Menell', b.authors.first
    end
  end

  def test_read_array_fails
    Tempfile.create do |tf|
      tf.write(<<~EOF)
        ---
        author1: Peter S. Menell
        author2: Mark A. Lemley
        author3: Robert P. Merges
        author4: Shyamkrishna Balganesh
      EOF
      tf.close
      assert_raises(Structured::InputError) do
        Book.new({ title: "IPNTA", authors: [ 'read_file', tf.path ] })
      end
    end
    assert_raises(Structured::InputError) do
      Book.new({ title: "IPNTA", authors: [ 'read_file', '/dev/null' ] })
    end
  end


end
