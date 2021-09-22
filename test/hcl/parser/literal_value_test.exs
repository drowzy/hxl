defmodule HCL.Parser.LiteralValueTest do
  use ExUnit.Case
  alias :hcl_parser, as: Parser
  alias HCL.Lexer
  alias HCL.Ast.{Literal, Attr}

  # defmodule P do
  #   import NimbleParsec
  #   defparsec(:parse_literal, LiteralValue.literal_value())
  # end

  test "parses integers" do
    assert {:ok, %Attr{expr: %Literal{value: {:int, 1}}}} = parse("a = 1")
  end

  test "parses decimals" do
    assert {:ok, %Attr{expr: %Literal{value: {:decimal, 1.1}}}} = parse("a = 1.1")
  end

  test "parses exponetials" do
    for exp <- ["e", "E"] do
      assert {:ok, %Attr{expr: %Literal{value: {:decimal, 100.0}}}} = parse("a = 1#{exp}2")
    end
  end

  test "parses bool: true" do
    assert {:ok, %Attr{expr: %Literal{value: {:bool, bool}}}} = parse("a = true")
    assert bool
  end

  test "parses bool: false" do
    assert {:ok, %Attr{expr: %Literal{value: {:bool, bool}}}} = parse("a = false")
    refute bool
  end

  test "parses null" do
    assert {:ok, %Attr{expr: %Literal{value: {:null, null}}}} = parse("a = null")
    assert is_nil(null)
  end

  defp parse(str) do
    {:ok, tokens, _, _, _, _} = Lexer.tokenize(str)
    Parser.parse(tokens)
  end
end

# HCL.Lexer.tokenize(("a = null")
