defmodule HCL.Parser.LiteralValueTest do
  use ExUnit.Case
  alias HCL.Parser
  alias HCL.Ast.Literal

  # defmodule P do
  #   import NimbleParsec
  #   defparsec(:parse_literal, LiteralValue.literal_value())
  # end

  test "parses integers" do
    assert {:ok, [%Literal{value: {:int, 1}}], _, _, _, _} = Parser.parse_literal("1")
  end

  test "parses decimals" do
    assert {:ok, [%Literal{value: {:decimal, 1.1}}], _, _, _, _} = Parser.parse_literal("1.1")
  end

  test "parses exponetials" do
    for exp <- ["e", "E", "+", "-"] do
      assert {:ok, values, _, _, _, _} = Parser.parse_literal("1#{exp}1")
      assert values == [%Literal{value: {:exp, [1, exp, 1]}}]
    end
  end

  test "parses bool: true" do
    assert {:ok, [%Literal{value: {:bool, bool}}], _, _, _, _} = Parser.parse_literal("true")
    assert bool
  end

  test "parses bool: false" do
    assert {:ok, [%Literal{value: {:bool, bool}}], _, _, _, _} = Parser.parse_literal("false")
    refute bool
  end

  test "parses null" do
    assert {:ok, [%Literal{value: {:null, null}}], _, _, _, _} = Parser.parse_literal("null")
    assert is_nil(null)
  end
end
