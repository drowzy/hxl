defmodule HCL.Parser.CollectionValueTest do
  use ExUnit.Case

  alias :hcl_parser, as: Parser
  alias HCL.Lexer
  alias HCL.Ast.{Attr, Tuple, Object, Literal, TemplateExpr}

  test "parses tuples of single type " do
    assert {:ok, %Attr{expr: %Tuple{values: values}}} = parse("a = [1, 2, 3]")

    assert values == [
             %Literal{value: {:int, 1}},
             %Literal{value: {:int, 2}},
             %Literal{value: {:int, 3}}
           ]
  end

  test "tuple with newlines" do
    hcl = "a = [\n  1,\n  2,\n  3\n]"

    assert {:ok, %Attr{expr: %Tuple{values: values}}} = parse(hcl)
    refute values == []
  end

  test "parses empty tuple" do
    assert {:ok, %Attr{expr: %Tuple{values: []}}} = parse("a = []")
  end

  test "parses tuples of different types " do
    {:ok, %Attr{expr: %Tuple{values: values}}} = parse("a = [1, true, null]")

    assert values == [
             %Literal{value: {:int, 1}},
             %Literal{value: {:bool, true}},
             %Literal{value: {:null, nil}}
           ]
  end

  test "parses objects with `:` assignment" do
    assert {:ok, %Attr{expr: %Object{kvs: kvs}}} = parse("a = { a: 1, b: true }")
    assert is_map(kvs)
    assert kvs["a"] == %Literal{value: {:int, 1}}
    assert kvs["b"] == %Literal{value: {:bool, true}}
  end

  test "parses objects with `=` assignment" do
    assert {:ok, %Attr{expr: %Object{kvs: kvs}}} = parse("a = { a = 1, b = true }")
    assert is_map(kvs)
    assert kvs["a"] == %Literal{value: {:int, 1}}
    assert kvs["b"] == %Literal{value: {:bool, true}}
  end

  defp parse(hcl) do
    {:ok, tokens, _, _, _, _} = Lexer.tokenize(hcl)
    Parser.parse(tokens)
  end
end
