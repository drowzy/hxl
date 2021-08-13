defmodule HCL.Parser.FunctionCallTest do
  use ExUnit.Case
  alias HCL.Parser
  alias HCL.Ast.FunctionCall

  test "parses 0-arity functions" do
    assert {:ok, [%FunctionCall{} = call], _, _, _, _} = Parser.parse_function("func()")
    assert call.arity == 0
    assert call.args == []
    assert call.name == "func"
  end

  test "parses 1-arity functions" do
    assert {:ok, [%FunctionCall{} = call], _, _, _, _} = Parser.parse_function("func(1)")
    assert call.arity == 1
    refute Enum.empty?(call.args)
    assert call.name == "func"
  end

  test "parses n-arity functions" do
    assert {:ok, [%FunctionCall{} = call], _, _, _, _} =
             Parser.parse_function("func(1, 2, 3, 4, 5)")

    assert call.arity == 5
    refute Enum.empty?(call.args)
    assert call.name == "func"
  end
end
