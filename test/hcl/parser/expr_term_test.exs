defmodule HCL.Parser.ExprTermTest do
  use ExUnit.Case
  alias HCL.Ast.{AccessOperation, Tuple, Identifier, Literal}

  test "can parse Expr with index access" do
    assert {:ok,
            [
              %AccessOperation{
                operation: {:index_access, _},
                expr: %Tuple{}
              }
            ], _, _, _, _} = HCL.Parser.parse_expr("[1,2,3][1]")
  end

  test "can parse Expr with get attr operations" do
    assert {:ok,
            [
              %AccessOperation{
                operation: {:attr_access, ["b", "c"]},
                expr: %Identifier{name: "a"}
              }
            ], _, _, _, _} = HCL.Parser.parse_expr("a.b.c")
  end

  test "can parse Expr with attr splat operations" do
    assert {:ok,
            [
              %AccessOperation{
                expr: %Identifier{name: "a"},
                operation: {:attr_splat, {:attr_access, ["b", "c"]}}
              }
            ], _, _, _, _} = HCL.Parser.parse_expr("a.*.b.c")
  end

  test "can parse Expr with multiple splat operations" do
    assert {:ok,
            [
              %AccessOperation{
                expr: %AccessOperation{
                  expr: %Identifier{name: "a"},
                  operation: {:attr_splat, {:attr_access, ["b", "c"]}}
                },
                operation: {:index_access, %Literal{value: {:int, 1}}}
              }
            ], _, _, _, _} = HCL.Parser.parse_expr("a.*.b.c[1]")
  end

  test "can parse Expr with full splat operations" do
    assert {:ok,
            [
              %AccessOperation{
                expr: %Identifier{name: "a"},
                operation:
                  {:full_splat,
                   [
                     {:attr_access, ["b", "c"]},
                     {:index_access, %Literal{value: {:int, 1}}}
                   ]}
              }
            ], _, _, _, _} = HCL.Parser.parse_expr("a[*].b.c[1]")
  end
end
