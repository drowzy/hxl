defmodule HXL.Lexer do
  @moduledoc false
  import NimbleParsec

  @newline ?\n
  @carriage_return ?\r
  @space ?\s
  @tab ?\t

  digit = ascii_char([?0..?9])
  non_zero_digit = ascii_char([?1..?9])
  negative_sign = ascii_char([?-])

  whitespace = ascii_char([@space, @tab])

  line_end =
    choice([
      ascii_char([@newline]),
      ascii_char([@carriage_return]) |> optional(ascii_char([@newline]))
    ])

  blankspace = choice([whitespace, line_end])

  ignoreed = ignore(blankspace)

  operators_delimiters_keywords =
    choice([
      choice([
        string("&&"),
        string("||"),
        string("=="),
        string("!="),
        string("<="),
        string(">="),
        string("=>"),
        string("%{"),
        string("${")
      ]),
      # Keywords
      # Asserts so that there isn't any identifiers after the keyword
      choice([
        string("null"),
        string("true"),
        string("false"),
        string("for"),
        string("if"),
        string("endif"),
        string("in")
      ])
      |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9])),
      ascii_char([
        ?=,
        ?!,
        ??,
        ?+,
        ?-,
        ?*,
        ?/,
        ?%,
        ?$,
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
  # LineComment
  #
  line_comment =
    choice([
      ignore(string("//")),
      ignore(string("#"))
    ])
    |> optional(ignore(blankspace))
    |> utf8_string([not: ?\n], min: 1)
    |> ignore(ascii_char([?\n]))
    |> post_traverse({:labeled_token, [:line_comment]})

  #
  # Templates
  #
  template_interpolation =
    choice([
      string("${~"),
      string("${")
    ])
    |> post_traverse({:atom_token, []})
    |> repeat(
      lookahead_not(
        choice([
          ascii_char([?}]),
          string("~}")
        ])
      )
      |> ignore(optional(blankspace))
      |> parsec(:literals)
    )
    |> choice([
      ascii_char([?}]) |> post_traverse({:atom_token, []}),
      string("~}") |> post_traverse({:atom_token, []})
    ])

  template = template_interpolation

  string_lit =
    ignore(ascii_char([?"]))
    |> repeat(
      lookahead_not(ascii_char([?"]))
      |> choice([
        # template_interpolation,
        template,
        ~S(\") |> string() |> replace(?"),
        utf8_char([])
      ])
    )
    |> ignore(ascii_char([?"]))
    |> post_traverse({:assemble_string, []})

  defp assemble_string(_rest, [], ctx, loc, byte_offset) do
    {[do_label_token(:string_part, [""], loc, byte_offset)], ctx}
  end

  defp assemble_string(_rest, content, ctx, loc, byte_offset) do
    {content, _} =
      content
      |> Enum.concat([:halt])
      |> Enum.reduce({[], []}, fn
        :halt, {_values, []} = acc ->
          acc

        :halt, {values, part} ->
          {[do_label_token(:string_part, [List.to_string(part)], loc, byte_offset) | values],
           part}

        token, {values, [] = part} when is_tuple(token) ->
          {[token | values], part}

        token, {values, part} when is_tuple(token) ->
          {[
             token,
             do_label_token(:string_part, [List.to_string(part)], loc, byte_offset) | values
           ], []}

        token, {values, part} ->
          {values, [token | part]}
      end)

    {Enum.reverse(content), ctx}
  end

  # |> reduce({List, :to_string, []})

  text_line =
    utf8_string([not: ?\n], min: 1)
    |> optional(ignore(times(line_end, min: 1)))
    |> post_traverse({:labeled_token, [:text]})

  heredoc =
    choice([ignore(string("<<-")), ignore(string("<<"))])
    |> concat(identifier)
    |> ignore(optional(repeat(line_end)))
    |> post_traverse({:tag_heredoc_open_tag, []})
    |> repeat_while(text_line, {:not_end_tag, []})
    |> optional(ignore(repeat(blankspace)))
    |> concat(identifier)
    |> optional(ignore(blankspace))
    |> post_traverse({:tag_heredoc, []})

  defp not_end_tag(bin, %{open_tag: tag} = ctx, _, _) do
    end_tag? =
      bin
      |> String.trim()
      |> String.starts_with?(tag)

    if end_tag? do
      {:halt, Map.delete(ctx, :open_tag)}
    else
      {:cont, ctx}
    end
  end

  defp tag_heredoc_open_tag(_rest, content, ctx, _loc, _byte_offset) do
    [{:identifier, _, [open_tag]} | _] = content

    {content, Map.put(ctx, :open_tag, open_tag)}
  end

  defp tag_heredoc(_rest, content, ctx, _loc, _byte_offset) do
    content = [{:heredoc, {0, 0}} | Enum.reverse(content)]

    {Enum.reverse(content), ctx}
  end

  defcombinator(
    :literals,
    choice([
      operators_delimiters_keywords,
      identifier,
      decimal_value,
      int
    ])
  )

  defparsec(
    :tokenize,
    repeat(
      choice([
        line_comment,
        string_lit,
        ignoreed,
        string_lit,
        heredoc,
        operators_delimiters_keywords,
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

  defp do_label_token(token_name, value, loc, byte_offset) do
    {token_name, line_and_column(loc, byte_offset, length(value)), value}
  end
end
