defmodule HCL.Parser.UnaryExprTest do
  use ExUnit.Case
  alias HCL.Ast.{Unary, Literal}

  test "can parse unary ops: >, >=, <, <=, ==" do
    for op <- ["-", "!"] do
      op_atom = String.to_existing_atom(op)

      assert {:ok,
              [
                %Unary{
                  operator: ^op_atom,
                  expr: %Literal{value: {:int, 1}}
                }
              ], _, _, _, _} = HCL.Parser.parse_op("#{op}1")
    end
  end
end
