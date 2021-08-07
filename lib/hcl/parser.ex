defmodule HCL.Parser do
  import NimbleParsec

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
  # ### Literal Value
  # #### NumericLiteral
  int = integer(min: 1)
  expmark = ascii_string([?e, ?E, ?+, ?-], max: 1)

  numeric_lit =
    int
    |> optional(ignore(dot) |> concat(int))
    |> optional(expmark |> concat(int))

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

  null = string("null") |> replace(nil)

  bool =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])

  literal_value = choice([numeric_lit, bool, null])
  arg = parsec(:expr) |> ignore(optional(comma)) |> ignore(optional(whitespace))

  tuple =
    ignore(open_brack)
    |> optional(blankspace)
    |> repeat(arg)
    |> ignore(close_brack)

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

  collection_value = choice([tuple, object])

  # ## Template Expr
  # TODO If a heredoc template is introduced with the <<- symbol, any literal string at the start of each line is analyzed to find the minimum number of leading spaces, and then that number of prefix spaces is removed from all line-leading literal strings. The final closing marker may also have an arbitrary number of spaces preceding it on its line.
  quoted_template = string_lit

  heredoc_line = utf8_string([not: ?\n], min: 1) |> ignore(newline)

  heredoc_template =
    choice([ignore(string("<<-")), ignore(string("<<"))])
    |> concat(identifier)
    |> ignore(whitespace)
    |> repeat(heredoc_line)
    |> post_traverse(:validate_heredoc_matching_terminator)

  defp validate_heredoc_matching_terminator(_rest, [close_id | content], ctx, _line, _offset) do
    [open_id | _] = Enum.reverse(content)

    if open_id == close_id do
      {content, ctx}
    else
      {:error, "Expected identifier: #{open_id} to be closed. Got: #{close_id}"}
    end
  end

  template_expr = choice([quoted_template, heredoc_template])
  variable_expr = identifier
  arguments = optional(repeat(arg))

  ## Function call
  function_call =
    identifier
    |> ignore(open_parens)
    |> concat(arguments)
    |> ignore(close_parens)

  ## for Expression
  for_cond = string("if") |> ignore(whitespace) |> parsec(:expr)

  for_identifier =
    identifier
    |> ignore(optional(comma))
    |> ignore(optional(whitespace))

  for_intro =
    string("for")
    |> ignore(whitespace)
    |> repeat(lookahead_not(string("in")) |> concat(for_identifier))
    |> ignore(optional(whitespace))
    |> ignore(string("in"))
    |> ignore(whitespace)
    |> parsec(:expr)
    |> ignore(whitespace)
    |> ignore(colon)

  for_tuple =
    ignore(open_brack)
    |> optional(blankspace)
    |> concat(for_intro)
    |> ignore(whitespace)
    |> parsec(:expr)
    |> optional(ignore(whitespace) |> concat(for_cond))
    |> ignore(close_brack)

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

  for_expr = choice([for_tuple, for_object])

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
      variable_expr,
      collection_value,
      for_expr,
      template_expr,
      function_call
    ])
    |> optional(expr_term_op)

  # Operations
  and_ = string("&&")
  or_ = string("||")
  not_ = string("!")
  sum = string("+")
  diff = string("-")
  product = string("*")
  quotient = string("/")
  remainder = string("%")
  eq = string("==")
  not_eq = not_ |> string("=")
  lt = string("<")
  gt = string(">")
  lt_eq = string("<=")
  gt_eq = string(">=")

  compare_op = choice([eq, not_eq, lt, gt, lt_eq, gt_eq])
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
  defparsec(:op, operation)

  # Conditional
  conditional =
    parsec(:expr)
    |> concat(blankspace)
    |> string("?")
    |> concat(blankspace)
    |> parsec(:expr)
    |> concat(blankspace)
    |> string(":")
    |> concat(blankspace)
    |> parsec(:expr)

  # expr = choice([operation, expr_term, conditional])
  expr = expr_term

  attr =
    identifier
    |> optional(blankspace)
    |> ignore(eq)
    |> optional(blankspace)
    |> parsec(:expr)

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

  defcombinatorp(:expr, expr, export_metadata: true)
  defcombinatorp(:attr, attr, export_metadata: true)
  defcombinatorp(:block, block, export_metadata: true)

  defcombinatorp(:body, repeat(choice([attr, block]) |> ignore(optional(whitespace))),
    export_metadata: true
  )

  defparsec(:parse_block, parsec(:block) |> eos())
  defparsec(:parse, parsec(:body) |> ignore(optional(whitespace)) |> eos())
end
