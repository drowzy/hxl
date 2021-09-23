defmodule HCL.Lexer do
  import NimbleParsec

  digit = ascii_char([?0..?9])
  non_zero_digit = ascii_char([?1..?9])
  negative_sign = ascii_char([?-])
  whitespace = ascii_string([?\s, ?\n], min: 1)

  # Boolean :: true | false
  #
  bool =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])
    |> post_traverse({:labeled_token, [:bool]})

  # Null
  #
  null = string("null") |> replace(:null) |> post_traverse({:labeled_token, [:null]})

  #
  # Reserved
  #
  reserved = choice([bool, null])

  ignoreed = ignore(whitespace)

  punctuator =
    choice([
      choice([
        string("&&"),
        string("||"),
        string("=="),
        string("!="),
        string("<="),
        string(">="),
        string("=>")
      ]),
      # Keywords
      choice([
        string("for"),
        string("if"),
        string("in")
      ]),
      ascii_char([
        ?=,
        ?!,
        ?+,
        ?-,
        ?*,
        ?/,
        ?%,
        ?<,
        ?>,
        ?.,
        ?,,
        ?:,
        ?*,
        ?{,
        ?},
        ?[,
        ?],
        ?(,
        ?)
      ]),
      times(ascii_char([?.]), 3)
    ])
    |> post_traverse({:atom_token, []})

  # Integer
  int = integer(min: 1) |> post_traverse({:labeled_token, [:int]})

  # FractionalPart :: . Digit+
  #
  # https://github.com/absinthe-graphql/absinthe/blob/master/lib/absinthe/lexer.ex#L127

  integer_part =
    optional(negative_sign)
    |> choice([
      ascii_char([?0]),
      non_zero_digit |> repeat(digit)
    ])

  fractional_part =
    ascii_char([?.])
    |> times(digit, min: 1)

  # ExponentIndicator :: one of `e` `E`
  exponent_indicator = ascii_char([?e, ?E])

  # Sign :: one of + -
  sign = ascii_char([?+, ?-])

  # ExponentPart :: ExponentIndicator Sign? Digit+
  exponent_part =
    exponent_indicator
    |> optional(sign)
    |> times(digit, min: 1)

  # DecimalValue ::
  #   - IntegerPart FractionalPart
  #   - IntegerPart ExponentPart
  #   - IntegerPart FractionalPart ExponentPart
  decimal_value =
    choice([
      integer_part |> concat(fractional_part) |> concat(exponent_part),
      integer_part |> post_traverse({:fill_mantissa, []}) |> concat(exponent_part),
      integer_part |> concat(fractional_part)
    ])
    |> post_traverse({:labeled_token, [:decimal]})

  defp fill_mantissa(_rest, raw, context, _, _), do: {'0.' ++ raw, context}

  # Identifier
  identifier =
    ascii_string([?a..?z, ?A..?Z, ?-, ?_], min: 1)
    |> post_traverse({:labeled_token, [:identifier]})

  #
  # Templates
  #
  string_lit =
    ignore(ascii_char([?"]))
    |> repeat(
      lookahead_not(ascii_char([?"]))
      |> choice([
        ~S(\") |> string() |> replace(?"),
        utf8_char([])
      ])
    )
    |> ignore(ascii_char([?"]))
    |> reduce({List, :to_string, []})
    |> post_traverse({:labeled_token, [:string]})

  text_line =
    utf8_string([not: ?\n], min: 1)
    |> ignore(string("\n"))

  heredoc =
    choice([ignore(string("<<-")), ignore(string("<<"))])
    |> concat(identifier)
    |> ignore(whitespace)
    |> repeat(text_line)
    |> optional(ignore(whitespace))
    |> post_traverse({:tag_heredoc_terminator, []})

  defp tag_heredoc_terminator(_rest, [close_id | content], ctx, loc, byte_offset) do
    content =
      content
      |> Enum.map(&tag_text/1)
      |> Enum.reverse()

    content = [{:heredoc, {0, 0}} | content]

    {[{:identifier, line_and_column(loc, byte_offset, 1), [close_id]} | Enum.reverse(content)],
     ctx}
  end

  defp tag_text(text) when is_binary(text), do: {:text, {-1, -1}, [text]}
  defp tag_text(tag), do: tag

  defparsec(
    :tokenize,
    repeat(
      choice([
        string_lit,
        ignoreed,
        reserved,
        string_lit,
        heredoc,
        punctuator,
        identifier,
        decimal_value,
        int
      ])
    )
  )

  defp atom_token(_rest, [chars], context, loc, byte_offset) when is_binary(chars) do
    token_atom = String.to_atom(chars)
    {[{token_atom, line_and_column(loc, byte_offset, String.length(chars))}], context}
  end

  defp atom_token(_rest, chars, context, loc, byte_offset) do
    value = chars |> Enum.reverse()
    token_atom = value |> List.to_atom()
    {[{token_atom, line_and_column(loc, byte_offset, length(value))}], context}
  end

  defp labeled_token(_rest, chars, context, loc, byte_offset, token_name) do
    value = chars |> Enum.reverse()
    {[{token_name, line_and_column(loc, byte_offset, length(value)), value}], context}
  end

  def line_and_column({line, line_offset}, byte_offset, column_correction) do
    column = byte_offset - line_offset - column_correction + 1
    {line, column}
  end
end
