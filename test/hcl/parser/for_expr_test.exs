defmodule HCL.Parser.ForExprTest do
  use ExUnit.Case
  alias HCL.Ast.{ForExpr, Tuple, FunctionCall}

  describe "tuple for expr" do
    test "with variable enumerable" do
      assert {:ok, [%ForExpr{} = for_expr], _, _, _, _} = HCL.Parser.parse_for("[for v in d: v]")

      assert for_expr.keys == ["v"]
      assert for_expr.enumerable == "d"
      assert for_expr.body == "v"
      assert for_expr.enumerable_type == :tuple
      assert for_expr.conditional == nil
    end

    test "with multiple keys" do
      assert {:ok, [%ForExpr{} = for_expr], _, _, _, _} =
               HCL.Parser.parse_for("[for i, j in d: j]")

      assert for_expr.keys == ["i", "j"]
    end

    test "with inline enumerable" do
      assert {:ok, [%ForExpr{} = for_expr], _, _, _, _} =
               HCL.Parser.parse_for("[for v in [1, 2]: v]")

      assert for_expr.keys == ["v"]
      assert %Tuple{} = for_expr.enumerable
      assert for_expr.body == "v"
      assert for_expr.enumerable_type == :tuple
    end

    test "with function bodies" do
      assert {:ok, [%ForExpr{} = for_expr], _, _, _, _} =
               HCL.Parser.parse_for("[for v in [1, 2]: func(v)]")

      assert %FunctionCall{name: "func"} = for_expr.body
    end

    test "with conditional" do
      assert {:ok, [%ForExpr{} = for_expr], _, _, _, _} =
               HCL.Parser.parse_for("[for v in [1, 2]: v if v]")

      assert for_expr.keys == ["v"]
      assert %Tuple{} = for_expr.enumerable
      assert for_expr.body == "v"
      assert for_expr.enumerable_type == :tuple
      assert for_expr.conditional == ["if", "v"]
    end
  end

  describe "object for expr" do
    test "with variable enumerable" do
      assert {:ok, [%ForExpr{} = for_expr], _, _, _, _} =
               HCL.Parser.parse_for("{for v in d: v => v}")

      assert for_expr.keys == ["v"]
      assert for_expr.enumerable == "d"
      assert for_expr.body == {"v", "v"}
      assert for_expr.enumerable_type == :object
      assert for_expr.conditional == nil
    end

    test "with multiple keys" do
      assert {:ok, [%ForExpr{} = for_expr], _, _, _, _} =
               HCL.Parser.parse_for("{for i, j in d: j => i}")

      assert for_expr.keys == ["i", "j"]
    end

    test "with inline enumerable" do
      assert {:ok, [%ForExpr{} = for_expr], _, _, _, _} =
               HCL.Parser.parse_for("{for v in [1, 2]: v => v}")

      assert %Tuple{} = for_expr.enumerable
    end

    test "with function bodies" do
      assert {:ok, [%ForExpr{} = for_expr], _, _, _, _} =
               HCL.Parser.parse_for("{for v in [1, 2]: v => func(v)}")

      assert {_, %FunctionCall{name: "func"}} = for_expr.body
    end

    test "with conditional" do
      assert {:ok, [%ForExpr{} = for_expr], _, _, _, _} =
               HCL.Parser.parse_for("{for v in [1, 2]: v => v if v}")

      assert for_expr.conditional == ["if", "v"]
    end
  end
end