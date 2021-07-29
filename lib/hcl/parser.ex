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
  whitespace = ascii_string([?\s, ?\n], min: 1)
  blankspace = ignore(ascii_string([?\s], min: 1))
  eq = string("=")
  identifier = ascii_string([?a..?z, ?A..?Z], min: 1)

  open_brace = string("{")
  close_brace = string("}")
  ## VALUE
  int = integer(min: 1)

  string_lit =
    ignore(string(~s(")))
    |> utf8_string([?a..?z, ?A..?Z], min: 1)
    |> ignore(string(~s(")))

  attr =
    identifier
    |> optional(blankspace)
    |> ignore(eq)
    |> optional(blankspace)
    |> concat(int)

  block =
    optional(blankspace)
    |> concat(identifier)
    |> concat(blankspace)
    |> choice([identifier, string_lit])
    |> concat(blankspace)
    |> ignore(open_brace)
    |> repeat(ignore(whitespace))
    |> parsec(:body)
    |> ignore(whitespace)
    |> ignore(close_brace)

  defcombinatorp(:attr, attr, export_metadata: true)
  defcombinatorp(:block, block, export_metadata: true)
  defcombinatorp(:body, choice([attr, block]), export_metadata: true)

  defparsec(:parse_block, parsec(:block) |> eos())
  defparsec(:parse, parsec(:body) |> ignore(optional(whitespace)) |> eos())
end
