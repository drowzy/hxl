defmodule HCL.Parser.BinaryExprTest do
  use ExUnit.Case

  alias :hcl_parser, as: Parser
  alias HCL.Ast.{Attr, Binary, Literal}
  alias HCL.Lexer

  test "can parse comparison ops: >, >=, <, <=, ==" do
    for op <- [">", ">=", "<", "<=", "=="] do
      op_atom = String.to_existing_atom(op)

      assert {:ok,
              %Attr{
                expr: %Binary{
                  operator: ^op_atom,
                  left: %Literal{value: {:int, 1}},
                  right: %Literal{value: {:int, 2}}
                }
              }} = parse("a = 1 #{op} 2")
    end
  end

  test "can parse arithemtic ops: +, -, /, *" do
    for op <- ["+", "-", "/", "*"] do
      op_atom = String.to_existing_atom(op)

      assert {:ok,
              %Attr{
                expr: %Binary{
                  operator: ^op_atom,
                  left: %Literal{value: {:int, 1}},
                  right: %Literal{value: {:int, 2}}
                }
              }} = parse("a = 1 #{op} 2")
    end
  end

  test "can parse logic ops: &&, ||" do
    for op <- ["&&", "||"] do
      op_atom = String.to_existing_atom(op)

      assert {:ok,
              %Attr{
                expr: %Binary{
                  operator: ^op_atom,
                  left: %Literal{value: {:int, 1}},
                  right: %Literal{value: {:int, 2}}
                }
              }} = parse("a = 1 #{op} 2")
    end
  end

  defp parse(str) do
    {:ok, tokens, _, _, _, _} = Lexer.tokenize(str)
    Parser.parse(tokens)
  end
end
