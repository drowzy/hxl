defmodule HCL.Parser.LiteralValueTest do
  use ExUnit.Case
  alias HCL.Parser.LiteralValue
  alias HCL.Ast.Literal

  defmodule P do
    import NimbleParsec
    defparsec(:parse_value, LiteralValue.literal_value())
  end

  test "parses integers" do
    assert {:ok, [%Literal{value: {:int, 1}}], _, _, _, _} = P.parse_value("1")
  end

  test "parses decimals" do
    assert {:ok, [%Literal{value: {:decimal, 1.1}}], _, _, _, _} = P.parse_value("1.1")
  end

  test "parses exponetials" do
    for exp <- ["e", "E", "+", "-"] do
      assert {:ok, values, _, _, _, _} = P.parse_value("1#{exp}1")
      assert values == [%Literal{value: {:exp, [1, exp, 1]}}]
    end
  end

  test "parses bool: true" do
    assert {:ok, [%Literal{value: {:bool, bool}}], _, _, _, _} = P.parse_value("true")
    assert bool
  end

  test "parses bool: false" do
    assert {:ok, [%Literal{value: {:bool, bool}}], _, _, _, _} = P.parse_value("false")
    refute bool
  end

  test "parses null" do
    assert {:ok, [%Literal{value: {:null, null}}], _, _, _, _} = P.parse_value("null")
    assert is_nil(null)
  end
end
