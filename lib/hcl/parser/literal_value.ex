defmodule HCL.Parser.LiteralValue do
  import NimbleParsec
  import HCL.Parser.Common, only: [dot: 0, int: 0]
  alias HCL.Ast.Literal

  ## LITERAL VALUE
  ##
  ## LiteralValue = (
  ##   NumericLit |
  ##   "true" |
  ##   "false" |
  ##   "null"
  ## );

  ## NUMERIC LITERAL
  #
  # expmark  = ('e' | 'E') ("+" | "-")?;
  def expmark, do: ascii_string([?e, ?E, ?+, ?-], max: 1)

  # NumericLit = decimal+ ("." decimal+)? (expmark decimal+)?;
  def numeric_lit do
    int()
    |> optional(ignore(dot()) |> concat(int()))
    |> optional(expmark() |> concat(int()))
    |> post_traverse({__MODULE__, :tag_and_emit_numeric_lit, []})
  end

  # https://github.com/dashbitco/nimble_parsec/blob/master/examples/simple_language.exs#L17
  def string_lit do
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
  end

  def null, do: string("null") |> replace(nil) |> unwrap_and_tag(:null)

  def bool do
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])
    |> unwrap_and_tag(:bool)
  end

  def literal_value do
    choice([
      numeric_lit(),
      bool(),
      null()
    ])
    |> post_traverse({__MODULE__, :emit_ast, []})
  end

  def tag_and_emit_numeric_lit(_rest, [int_value], ctx, _line, _offset) do
    {[{:int, int_value}], ctx}
  end

  def tag_and_emit_numeric_lit(_rest, [frac, base], ctx, _line, _offset) do
    {value, _} = Float.parse("#{base}.#{frac}")
    {[{:decimal, value}], ctx}
  end

  def tag_and_emit_numeric_lit(_rest, [_pow, exp, _base] = args, ctx, _line, _offset)
      when is_binary(exp) do
    {[{:exp, args}], ctx}
  end

  def tag_and_emit_numeric_lit(_rest, [_pow, exp, _frac, _base] = args, ctx, _line, _offset)
      when is_binary(exp) do
    {[{:float_exp, args}], ctx}
  end

  def emit_ast(_rest, [literal], ctx, _line, _offset) do
    {[%Literal{value: literal}], ctx}
  end
end
