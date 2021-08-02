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
  eq = string("=")
  dot = string(".")
  comma = string(",")
  colon = string(":")
  identifier = ascii_string([?a..?z, ?A..?Z], min: 1)
  open_brace = string("{")
  close_brace = string("}")
  open_brack = string("[")
  close_brack = string("]")
  assign = choice([eq, colon])

  # ## Expr https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#expression-terms
  # ### Literal Value
  # #### NumericLiteral
  int = integer(min: 1)
  expmark = ascii_char([?e, ?E, ?+, ?-])

  numeric_lit =
    int
    |> optional(ignore(dot) |> concat(int))
    |> optional(expmark |> concat(int))

  string_lit =
    ignore(string(~s(")))
    |> utf8_string([?a..?z, ?A..?Z], min: 1)
    |> ignore(string(~s(")))

  null = string("null") |> replace(nil)

  bool =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])

  literal_value = choice([numeric_lit, bool, null])
  tuple_elem = literal_value |> ignore(optional(comma)) |> ignore(optional(whitespace))
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
    |> concat(literal_value)
    |> ignore(optional(whitespace))
  object =
    ignore(open_brace)
    |> optional(blankspace)
    |> repeat(object_elem)
    |> ignore(close_brace)
  collection_value = choice([tuple, object])
  expr_term = choice([literal_value, collection_value])

  attr =
    identifier
    |> optional(blankspace)
    |> ignore(eq)
    |> optional(blankspace)
    |> concat(expr_term)

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

  defcombinatorp(:attr, attr, export_metadata: true)
  defcombinatorp(:block, block, export_metadata: true)

  defcombinatorp(:body, repeat(choice([attr, block]) |> ignore(optional(whitespace))),
    export_metadata: true
  )

  defparsec(:parse_block, parsec(:block) |> eos())
  defparsec(:parse, parsec(:body) |> ignore(optional(whitespace)) |> eos())
end
