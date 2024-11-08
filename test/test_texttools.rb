require 'minitest/autorun'
require 'texttools'

class TextToolsTest < Minitest::Test

  include TextTools

  def test_line_break_basic
    assert_equal("Line\nBreak", line_break("Line Break", len: 5))
  end

  def test_line_break_prefix
    assert_equal("*Line\n*Break", line_break("Line Break", len: 6, prefix: '*'))
  end

  def test_line_break_short
    assert_equal("Line\nBrea\nk", line_break("Line Break", len: 4))
    assert_equal("Lin\ne\nBre\nak", line_break("Line Break", len: 3))
  end

  def test_line_break_para
    assert_equal(
      "Line break\ntext\n\nwith para\nbreak",
      line_break("Line break text\n\nwith para break", len: 11)
    )
  end

  def test_line_break_ignore_breaks
    assert_equal(
      "Line break\ntext\n\nwith para\nbreak",
      line_break("Line\nbreak\n text\n\n with \npara \n break", len: 11)
    )
  end

  def test_line_break_preserve_breaks
    assert_equal(
      "Line\nbreak text\n\nwith para\nbreak",
      line_break(
        "Line\nbreak text\n\n with para break", len: 11, preserve_lines: true
      )
    )
  end

  def test_line_break_trailing_spaces
    assert_equal(
      "line break\ntext",
      line_break("line break text          ", len: 11)
    )
  end

  def test_text_join_one
    assert_equal("one", text_join(%w(one)))
  end

  def test_text_join_two
    assert_equal("one and two", text_join(%w(one two), amp: ' and '))
  end

  def test_text_join_three
    assert_equal(
      "one, two, and three", text_join(%w(one two three), commaamp: ", and ")
    )
  end

  def test_markdown
    assert_equal("Hello <i>world</i>", markdown("Hello *world*"))
    assert_equal("Hello <b>world</b>", markdown("Hello **world**"))
  end

  def test_markdown_mid
    assert_equal("Hello <i>big</i> world", markdown("Hello *big* world"))
    assert_equal("Hello <b>big</b> world", markdown("Hello **big** world"))
  end

  def test_markdown_punct
    assert_equal("Hello '<i>big</i>' world", markdown("Hello '*big*' world"))
    assert_equal("Hello '<b>big</b>' world", markdown("Hello '**big**' world"))
  end

  def test_ordinals
    assert_equal("1st", ordinal(1))
    assert_equal("2d", ordinal(2))
    assert_equal("2nd", ordinal(2, legal: false))
    assert_equal("3d", ordinal(3))
    assert_equal("3rd", ordinal(3, legal: false))
    assert_equal("4th", ordinal(4))
    assert_equal("11th", ordinal(11))
    assert_equal("20th", ordinal(20))
    assert_equal("21st", ordinal(21))
  end

end
