module TextTools

  extend TextTools

  #
  # Breaks a text into lines of a given length. If preserve_lines is set, then
  # all line breaks are preserved; otherwise line breaks are treated as spaces.
  # However, two consecutive line breaks are always preserved, treating them as
  # paragraph breaks.
  #
  def line_break(text, len: 80, prefix: '', preserve_lines: false)
    res = ''
    strlen = len - prefix.length
    text = text.split(/\s*\n\s*\n\s*/).map { |para|
      preserve_lines ? para : para.gsub(/\s*\n\s*/, " ")
    }.join("\n\n")

    while text.length > strlen
      if text =~ /\A[^\n]{0,#{strlen}}\s+/
        res << prefix + $&.rstrip + "\n"
        text = $'
      else
        res << prefix + text[0, strlen]
        text = text[strlen..-1]
      end
    end
    res << prefix + text
    return res
  end


  #
  # Joins a list of items into a textual phrase. If there are two items, then
  # +amp+ is used to join them. If there are three or more items, then +comma+
  # is used for all but the last pair, for which +commaamp+ is used.
  #
  def text_join(list, comma: ", ", amp: " & ", commaamp: " & ")
    return list unless list.is_a?(Array)
    case list.count
    when 0 then raise "Can't textjoin empty list"
    when 1 then list.first
    when 2 then list.join(amp)
    else
      list[0..-2].join(comma) + commaamp + list.last
    end
  end

  #
  # Processes simple markdown for a given text.
  #
  # @param i A two-element array of the starting and ending text for italicized
  #          content.
  # @param b A two-element array of the starting and ending text for bold
  #          content.
  #
  def markdown(text, i: [ '<i>', '</i>' ], b: [ '<b>', '</b>' ])
    return text.gsub(/(?<!\w)\*\*([^*]+)\*\*(?!\w)/) { |t|
      "#{b.first}#$1#{b.last}"
    }.gsub(/(?<!\w)\*([^*]+)\*(?!\w)/) { |t|
      "#{i.first}#$1#{i.last}"
    }
  end

  #
  # Computes the ordinal number (using digits).
  #
  # @param legal Whether to use legal ordinals (2d, 3d)
  #
  def ordinal(num, legal: true)
    case num
    when /1\d$/ then "#{num}th"
    when /1$/ then "#{num}st"
    when /2$/ then legal ? "#{num}d" : "#{num}nd"
    when /3$/ then legal ? "#{num}d" : "#{num}rd"
    else "#{num}th"
    end
  end


end
