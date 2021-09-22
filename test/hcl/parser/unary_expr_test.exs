defmodule HCL.Parser.UnaryExprTest do
  use ExUnit.Case

  alias :hcl_parser, as: Parser
  alias HCL.Lexer
  alias HCL.Ast.{Attr, Unary, Literal}

  test "can parse unary ops: >, >=, <, <=, ==" do
    for op <- ["-", "!"] do
      op_atom = String.to_existing_atom(op)

      assert {:ok,
              %Attr{
                expr: %Unary{
                  operator: ^op_atom,
                  expr: %Literal{value: {:int, 1}}
                }
              }} = parse("a = #{op}1")
    end
  end

  defp parse(str) do
    {:ok, tokens, _, _, _, _} = Lexer.tokenize(str)
    Parser.parse(tokens)
  end
end
