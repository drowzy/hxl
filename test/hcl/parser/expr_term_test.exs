defmodule HCL.Parser.ExprTermTest do
  use ExUnit.Case

  alias :hcl_parser, as: Parser
  alias HCL.Lexer
  alias HCL.Ast.{Attr, AccessOperation, Tuple, Identifier}

  test "can parse Expr with index access" do
    assert {:ok,
            %Attr{
              expr: %AccessOperation{
                operation: :index_access,
                key: _key,
                expr: %Tuple{}
              }
            }} = parse("a = [1,2,3][1]")
  end

  test "can parse Expr with get attr operations" do
    assert {:ok,
            %Attr{
              expr: %AccessOperation{
                operation: :attr_access,
                key: "c",
                expr: %AccessOperation{
                  expr: %Identifier{name: "a"},
                  operation: :attr_access,
                  key: "b"
                }
              }
            }} = parse("a = a.b.c")
  end

  test "can parse Expr with attr splat operations" do
    assert {:ok,
            %Attr{
              expr: %AccessOperation{
                operation: :attr_access,
                key: "b",
                expr: %AccessOperation{
                  expr: %Identifier{name: "a"},
                  operation: :attr_splat,
                  key: "*"
                }
              }
            }} = parse("a = a.*.b")
  end

  test "can parse Expr with multiple splat operations" do
    assert {:ok,
            %Attr{
              expr: %AccessOperation{
                expr: %AccessOperation{
                  expr: %AccessOperation{
                    expr: %AccessOperation{
                      expr: %Identifier{name: "a"},
                      key: "*",
                      operation: :attr_splat
                    },
                    key: "b",
                    operation: :attr_access
                  },
                  key: "c",
                  operation: :attr_access
                },
                key: %HCL.Ast.Literal{value: {:int, 1}},
                operation: :index_access
              }
            }} = parse("a = a.*.b.c[1]")
  end

  test "can parse Expr with full splat operations" do
    assert {:ok,
            %HCL.Ast.Attr{
              expr: %HCL.Ast.AccessOperation{
                expr: %HCL.Ast.AccessOperation{
                  expr: %HCL.Ast.AccessOperation{
                    expr: %HCL.Ast.Identifier{name: "a"},
                    key: "*",
                    operation: :full_splat
                  },
                  key: "c",
                  operation: :attr_access
                },
                key: %HCL.Ast.Literal{value: {:int, 1}},
                operation: :index_access
              }
            }} = parse("a = a[*].b.c[1]")
  end

  defp parse(str) do
    {:ok, tokens, _, _, _, _} = Lexer.tokenize(str)
    Parser.parse(tokens)
  end
end
