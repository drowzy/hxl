defmodule HCL.Parser do
  import NimbleParsec

  alias HCL.Ast.{
    Literal,
    TemplateExpr,
    Tuple,
    Object,
    FunctionCall,
    ForExpr
  }

  # https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md

  # io_mode = "async"

  # service "http" "web_proxy" {
  #   listen_addr = "127.0.0.1:8080"
  #   process "main" {
  #     command = ["/usr/local/bin/awesome-app", "server"]
  #   }

  #   process "mgmt" {#     command = ["/usr/local/bin/awesome-app", "mgmt"]
  #   }
  # }
  # ## Lexical
  whitespace = ascii_string([?\s, ?\n], min: 1)
  blankspace = ignore(ascii_string([?\s], min: 1))
  newline = string("\n")
  eq = string("=")
  and_ = string("&&")
  or_ = string("||")
  not_ = string("!")
  sum = string("+")
  diff = string("-")
  product = string("*")
  quotient = string("/")
  remainder = string("%")
  eqeq = string("==")
  not_eq = not_ |> string("=")
  lt = string("<")
  gt = string(">")
  lt_eq = string("<=")
  gt_eq = string(">=")
  dot = string(".")
  comma = string(",")
  colon = string(":")
  wildcard = string("*")
  identifier = ascii_string([?a..?z, ?A..?Z, ?-, ?_], min: 1)
  open_brace = string("{")
  close_brace = string("}")
  open_brack = string("[")
  close_brack = string("]")
  open_parens = string("(")
  close_parens = string(")")
  fat_arrow = string("=>")
  assign = choice([eq, colon])

  # ## Expr https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#expression-terms
  #############################################################################
  ## Literal Value
  ##
  ## TODO

  expmark = ascii_string([?e, ?E, ?+, ?-], max: 1)
  int = integer(min: 1)
  # NumericLit = decimal+ ("." decimal+)? (expmark decimal+)?;
  numeric_lit =
    int
    |> optional(ignore(dot) |> concat(int))
    |> optional(expmark |> concat(int))
    |> post_traverse(:tag_and_emit_numeric_lit)

  # https://github.com/dashbitco/nimble_parsec/blob/master/examples/simple_language.exs#L17
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

  null = string("null") |> replace(nil) |> unwrap_and_tag(:null)

  bool =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])
    |> unwrap_and_tag(:bool)

  literal_value =
    choice([
      numeric_lit,
      bool,
      null
    ])
    |> post_traverse({Literal, :from_tokens, []})

  defp tag_and_emit_numeric_lit(_rest, [int_value], ctx, _line, _offset) do
    {[{:int, int_value}], ctx}
  end

  defp tag_and_emit_numeric_lit(_rest, [frac, base], ctx, _line, _offset) do
    {value, _} = Float.parse("#{base}.#{frac}")
    {[{:decimal, value}], ctx}
  end

  defp tag_and_emit_numeric_lit(_rest, [_pow, exp, _base] = args, ctx, _line, _offset)
       when is_binary(exp) do
    {[{:exp, args}], ctx}
  end

  defp tag_and_emit_numeric_lit(_rest, [_pow, exp, _frac, _base] = args, ctx, _line, _offset)
       when is_binary(exp) do
    {[{:float_exp, args}], ctx}
  end

  #########################################
  # ## CollectionValue

  arg = parsec(:expr) |> ignore(optional(comma)) |> ignore(optional(whitespace))

  tuple =
    ignore(open_brack)
    |> optional(blankspace)
    |> repeat(arg)
    |> ignore(close_brack)
    |> post_traverse({Tuple, :from_tokens, []})

  # TODO should be able to be an expression
  object_elem =
    identifier
    |> ignore(optional(whitespace))
    |> ignore(assign)
    |> optional(blankspace)
    |> parsec(:expr)
    |> ignore(optional(comma))
    |> ignore(optional(whitespace))

  object =
    ignore(open_brace)
    |> optional(blankspace)
    |> repeat(object_elem)
    |> ignore(close_brace)
    |> post_traverse({Object, :from_tokens, []})

  collection_value = choice([tuple, object])

  #########################################
  # ## Template Expr
  # TODO If a heredoc template is introduced with the <<- symbol, any literal string at the start of each line is analyzed to find the minimum number of leading spaces, and then that number of prefix spaces is removed from all line-leading literal strings. The final closing marker may also have an arbitrary number of spaces preceding it on its line.
  quoted_template = string_lit |> tag(:qouted_template)

  heredoc_line = utf8_string([not: ?\n], min: 1) |> ignore(newline)

  heredoc_template =
    choice([ignore(string("<<-")), ignore(string("<<"))])
    |> concat(identifier)
    |> ignore(whitespace)
    |> repeat(heredoc_line)
    |> post_traverse(:validate_heredoc_matching_terminator)
    |> tag(:heredoc)

  defp validate_heredoc_matching_terminator(_rest, [close_id | content], ctx, _line, _offset) do
    [open_id | _] = Enum.reverse(content)

    if open_id == close_id do
      {content, ctx}
    else
      {:error, "Expected identifier: #{open_id} to be closed. Got: #{close_id}"}
    end
  end

  template_expr =
    choice([quoted_template, heredoc_template]) |> post_traverse({TemplateExpr, :from_tokens, []})

  variable_expr = identifier
  arguments = optional(repeat(arg))

  ###########################
  # ## Function call
  #
  #
  function_call =
    identifier
    |> ignore(open_parens)
    |> concat(arguments)
    |> ignore(close_parens)
    |> post_traverse({FunctionCall, :from_tokens, []})

  ##########################
  # ## for Expression
  #
  for_cond = string("if") |> ignore(whitespace) |> parsec(:expr)

  for_identifier =
    identifier
    |> ignore(optional(comma))
    |> ignore(optional(whitespace))
    |> unwrap_and_tag(:identifier)

  for_intro =
    ignore(string("for"))
    |> ignore(whitespace)
    |> repeat(lookahead_not(string("in")) |> concat(for_identifier))
    |> ignore(optional(whitespace))
    |> ignore(string("in"))
    |> ignore(whitespace)
    |> parsec(:expr)
    |> optional(ignore(whitespace))
    |> ignore(colon)

  for_tuple =
    ignore(open_brack)
    |> optional(blankspace)
    |> concat(for_intro)
    |> ignore(whitespace)
    |> parsec(:expr)
    |> optional(ignore(whitespace) |> concat(for_cond))
    |> ignore(close_brack)
    |> tag(:tuple)

  for_object =
    ignore(open_brace)
    |> optional(blankspace)
    |> concat(for_intro)
    |> ignore(whitespace)
    |> parsec(:expr)
    |> ignore(whitespace)
    |> ignore(fat_arrow)
    |> ignore(whitespace)
    |> parsec(:expr)
    |> optional(ignore(whitespace) |> concat(for_cond))
    |> ignore(close_brace)
    |> tag(:object)

  for_expr = choice([for_tuple, for_object]) |> post_traverse({ForExpr, :from_tokens, []})

  # Expr term operations
  index =
    ignore(open_brack)
    |> optional(blankspace)
    |> parsec(:expr)
    |> optional(blankspace)
    |> ignore(close_brack)

  get_attr = repeat(ignore(dot) |> concat(identifier))

  # Splat
  attr_splat =
    ignore(dot)
    |> ignore(wildcard)
    |> concat(get_attr)

  full_splat =
    ignore(open_brack)
    |> optional(blankspace)
    |> ignore(wildcard)
    |> optional(blankspace)
    |> repeat(choice([get_attr, index]))

  splat = choice([attr_splat, full_splat])

  # Expr Term
  expr_term_op = choice([index, splat, get_attr])

  expr_term =
    choice([
      literal_value,
      collection_value,
      for_expr,
      template_expr,
      function_call,
      variable_expr
    ])
    |> optional(expr_term_op)

  # Operations

  compare_op = choice([eqeq, not_eq, lt, gt, lt_eq, gt_eq])
  arithmetic_op = choice([sum, diff, product, quotient, remainder])
  logic_op = choice([and_, or_, not_])

  binary_operator = choice([compare_op, arithmetic_op, logic_op])

  binary_op =
    expr_term
    |> optional(ignore(whitespace))
    |> concat(binary_operator)
    |> optional(ignore(whitespace))
    |> concat(expr_term)

  unary_op = choice([diff, not_]) |> concat(expr_term)
  operation = choice([unary_op, binary_op])

  # Conditional
  _conditional =
    parsec(:expr)
    |> concat(blankspace)
    |> string("?")
    |> concat(blankspace)
    |> parsec(:expr)
    |> concat(blankspace)
    |> string(":")
    |> concat(blankspace)
    |> parsec(:expr)

  expr = choice([operation, expr_term])

  attr =
    identifier
    |> optional(blankspace)
    |> ignore(eq)
    |> optional(blankspace)
    |> concat(expr)

  block =
    optional(blankspace)
    |> concat(identifier)
    |> concat(blankspace)
    |> choice([identifier, string_lit])
    |> concat(blankspace)
    |> ignore(open_brace)
    |> repeat(ignore(whitespace))
    |> parsec(:body)
    |> ignore(close_brace)

  if Mix.env() == :test do
    defparsec(:parse_literal, literal_value)
    defparsec(:parse_collection, collection_value)
    defparsec(:parse_template, template_expr)
    defparsec(:parse_function, function_call)
    defparsec(:parse_for, for_expr)
  end

  defcombinatorp(:expr, expr, export_metadata: true)

  defcombinatorp(:body, repeat(choice([attr, block]) |> ignore(optional(whitespace))),
    export_metadata: true
  )

  defparsec(:parse, parsec(:body) |> ignore(optional(whitespace)) |> eos())
end
