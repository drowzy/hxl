defmodule HCL.Parser.CollectionValueTest do
  use ExUnit.Case
  alias HCL.Parser
  alias HCL.Ast.{Tuple, Object, Literal, TemplateExpr}

  test "parses tuples of single type " do
    assert {:ok, [%Tuple{values: values}], _, _, _, _} = Parser.parse_collection("[1, 2, 3]")

    assert values == [
             %Literal{value: {:int, 1}},
             %Literal{value: {:int, 2}},
             %Literal{value: {:int, 3}}
           ]
  end

  test "tuple with newlines" do
    hcl = "[\n  1,\n  2,\n  3\n]"

    assert {:ok, [%Tuple{values: values}], _, _, _, _} = Parser.parse_collection(hcl)
    refute values == []
  end

  test "parses empty tuple" do
    assert {:ok, [%Tuple{values: []}], _, _, _, _} = Parser.parse_collection("[]")
  end

  test "parses tuples of different types " do
    assert {:ok, [%Tuple{values: values}], _, _, _, _} =
             Parser.parse_collection("[1, true, null, \"string\"]")

    assert values == [
             %Literal{value: {:int, 1}},
             %Literal{value: {:bool, true}},
             %Literal{value: {:null, nil}},
             %TemplateExpr{delimiter: nil, lines: ["string"]}
           ]
  end

  test "parses objects with `:` assignment" do
    assert {:ok, [%Object{kvs: kvs}], _, _, _, _} = Parser.parse_collection("{ a: 1, b: true }")
    assert is_map(kvs)
    assert kvs["a"] == %Literal{value: {:int, 1}}
    assert kvs["b"] == %Literal{value: {:bool, true}}
  end

  test "parses objects with `=` assignment" do
    assert {:ok, [%Object{kvs: kvs}], _, _, _, _} = Parser.parse_collection("{ a = 1, b = true }")
    assert is_map(kvs)
    assert kvs["a"] == %Literal{value: {:int, 1}}
    assert kvs["b"] == %Literal{value: {:bool, true}}
  end
end
