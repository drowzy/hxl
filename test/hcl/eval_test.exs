defmodule HCL.EvalTest do
  use ExUnit.Case

  test "eval/1 attr literal int" do
    hcl = """
    a = 1
    """

    ctx = parse_and_eval(hcl)

    assert %{"a" => 1} == ctx
  end

  test "eval/1 attr literal string" do
    hcl = ~S"""
    a = "string"
    """

    ctx = parse_and_eval(hcl)

    assert %{"a" => "string"} == ctx
  end

  test "eval/1 attr tuple" do
    hcl = ~S"""
    a = [1,2,3]
    """

    ctx = parse_and_eval(hcl)

    assert %{"a" => [1, 2, 3]} == ctx
  end

  test "eval/1 block tuple" do
    hcl = """
    a "b" {
      c = [1,2,3]
    }
    """

    ctx = parse_and_eval(hcl)

    assert %{"a" => %{"b" => %{"c" => [1, 2, 3]}}} == ctx
  end

  test "eval/1 object" do
    hcl = """
    a = { b = 1 }
    """

    ctx = parse_and_eval(hcl)

    assert %{"a" => %{"b" => 1}} == ctx
  end

  test "eval/1 nested object" do
    hcl = """
    a = { b = { c = { d = "e" } } }
    """

    ctx = parse_and_eval(hcl)

    assert %{"a" => %{"b" => %{"c" => %{"d" => "e"}}}} == ctx
  end

  test "eval/1 nested block tuple" do
    hcl = """
    a "b" {
      c "d" {
        e = 1
      }
    }
    """

    ctx = parse_and_eval(hcl)

    assert %{"a" => %{"b" => %{"c" => %{"d" => %{"e" => 1}}}}} == ctx
  end

  test "eval/1 variable assign" do
    hcl = """
    a = 1
    b = a
    """

    %{"a" => a, "b" => b} = parse_and_eval(hcl)

    assert a == b
  end

  test "eval/1 unary operation assign" do
    hcl = """
    a = 1
    b = -a
    """

    %{"a" => a, "b" => b} = parse_and_eval(hcl)

    assert -a == b
  end

  test "eval/1 binary operation" do
    hcl = """
    a = 1 + 1
    b = a
    """

    %{"a" => a, "b" => b} = parse_and_eval(hcl)

    assert a == b
  end

  test "eval/1 multiple binary operations" do
    hcl = """
    a = 1 + (2 * 3)
    """

    assert %{"a" => a} = parse_and_eval(hcl)
    assert a == 7
  end

  defp parse_and_eval(hcl) do
    %{ctx: ctx} =
      hcl
      |> HCL.Parser.parse!()
      |> HCL.Eval.eval()

    ctx
  end
end
