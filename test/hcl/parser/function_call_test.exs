defmodule HCL.Parser.FunctionCallTest do
  use ExUnit.Case
  alias :hcl_parser, as: Parser
  alias HCL.Lexer
  alias HCL.Ast.{Attr, FunctionCall}

  test "parses 0-arity functions" do
    assert {:ok, %Attr{expr: %FunctionCall{} = call}} = parse("a = func()")
    assert call.arity == 0
    assert call.args == []
    assert call.name == "func"
  end

  test "parses 1-arity functions" do
    assert {:ok, %Attr{expr: %FunctionCall{} = call}} = parse("a = func(1)")
    assert call.arity == 1
    refute Enum.empty?(call.args)
    assert call.name == "func"
  end

  test "parses n-arity functions" do
    assert {:ok, %Attr{expr: %FunctionCall{} = call}} = parse("a = func(1, 2, 3, 4, 5)")
    assert call.arity == 5
    refute Enum.empty?(call.args)
    assert call.name == "func"
  end

  defp parse(str) do
    {:ok, tokens, _, _, _, _} = Lexer.tokenize(str)
    Parser.parse(tokens)
  end
end
