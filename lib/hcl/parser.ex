defmodule HCL.Parser do
  import NimbleParsec

  # https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md

  # io_mode = "async"

  # service "http" "web_proxy" {
  #   listen_addr = "127.0.0.1:8080"
  #   process "main" {
  #     command = ["/usr/local/bin/awesome-app", "server"]
  #   }

  #   process "mgmt" {
  #     command = ["/usr/local/bin/awesome-app", "mgmt"]
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
  identifier = ascii_string([?a..?z, ?A..?Z, ?-, ?_], min: 1)
  open_brace = string("{")
  close_brace = string("}")
  open_brack = string("[")
  close_brack = string("]")
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
  tuple_elem = parsec(:expr_term) |> ignore(optional(comma)) |> ignore(optional(whitespace))

  tuple =
    ignore(open_brack)
    |> optional(blankspace)
    |> repeat(tuple_elem)
    |> ignore(close_brack)

  # TODO should be able to be an expression
  object_elem =
    identifier
    |> ignore(optional(whitespace))
    |> ignore(assign)
    |> optional(blankspace)
    |> parsec(:expr_term)
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
  expr_term = choice([literal_value, collection_value, template_expr])

  attr =
    identifier
    |> optional(blankspace)
    |> ignore(eq)
    |> optional(blankspace)
    |> parsec(:expr_term)

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

  defcombinatorp(:expr_term, expr_term, export_metadata: true)
  defcombinatorp(:attr, attr, export_metadata: true)
  defcombinatorp(:block, block, export_metadata: true)

  defcombinatorp(:body, repeat(choice([attr, block]) |> ignore(optional(whitespace))),
    export_metadata: true
  )

  defparsec(:parse_block, parsec(:block) |> eos())
  defparsec(:parse, parsec(:body) |> ignore(optional(whitespace)) |> eos())
end
