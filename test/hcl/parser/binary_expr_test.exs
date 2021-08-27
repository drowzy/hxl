defmodule HCL.Parser.BinaryExprTest do
  use ExUnit.Case
  alias HCL.Ast.{Binary, Literal}

  test "can parse comparison ops: >, >=, <, <=, ==" do
    for op <- [">", ">=", "<", "<=", "=="] do
      op_atom = String.to_existing_atom(op)

      assert {:ok,
              [
                %Binary{
                  operator: ^op_atom,
                  left: %Literal{value: {:int, 1}},
                  right: %Literal{value: {:int, 2}}
                }
              ], _, _, _, _} = HCL.Parser.parse_op("1 #{op} 2")
    end
  end

  test "can parse arithemtic ops: +, -, /, *" do
    for op <- ["+", "-", "/", "*"] do
      op_atom = String.to_existing_atom(op)

      assert {:ok,
              [
                %Binary{
                  operator: ^op_atom,
                  left: %Literal{value: {:int, 1}},
                  right: %Literal{value: {:int, 2}}
                }
              ], _, _, _, _} = HCL.Parser.parse_op("1 #{op} 2")
    end
  end

  test "can parse logic ops: &&, ||" do
    for op <- ["&&", "||"] do
      op_atom = String.to_existing_atom(op)

      assert {:ok,
              [
                %Binary{
                  operator: ^op_atom,
                  left: %Literal{value: {:int, 1}},
                  right: %Literal{value: {:int, 2}}
                }
              ], _, _, _, _} = HCL.Parser.parse_op("1 #{op} 2")
    end
  end
end
