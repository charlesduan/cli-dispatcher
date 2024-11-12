module TextTools

  extend TextTools

  #
  # Breaks a text into lines of a given length. If preserve_lines is set, then
  # all line breaks are preserved; otherwise line breaks are treated as spaces.
  # However, two consecutive line breaks are always preserved, treating them as
  # paragraph breaks. Line breaks at the end of the text are never preserved.
  #
  def line_break(
    text, len: 80, prefix: '', first_prefix: nil, preserve_lines: false
  )
    res = ''
    text = text.split(/\s*\n\s*\n\s*/).map { |para|
      preserve_lines ? para : para.gsub(/\s*\n\s*/, " ")
    }.join("\n\n")

    cur_prefix = first_prefix || prefix
    strlen = len - cur_prefix.length
    while text.length > strlen
      if (m = /\A([^\n]{0,#{strlen}})(\s+)/.match(text))
        res << cur_prefix + m[1]
        res << (m[2].include?("\n") ? m[2].gsub(/[^\n]/, '') : "\n")
        text = m.post_match
      else
        res << cur_prefix + text[0, strlen] + "\n"
        text = text[strlen..-1]
      end
      cur_prefix = prefix
      strlen = len - cur_prefix.length
    end

    # If there's no text left, then there were trailing spaces and the final \n
    # is superfluous.
    if text.length > 0
      res << cur_prefix + text
    else
      res.rstrip!
    end

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
    case num.to_s
    when /1\d\z/ then "#{num}th"
    when /1\z/ then "#{num}st"
    when /2\z/ then legal ? "#{num}d" : "#{num}nd"
    when /3\z/ then legal ? "#{num}d" : "#{num}rd"
    else "#{num}th"
    end
  end


end
