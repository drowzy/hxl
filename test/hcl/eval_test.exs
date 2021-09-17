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

  test "eval/1 ignores comments" do
    hcl = """
    # Block comment
    """

    assert hcl |> parse_and_eval() |> Enum.empty?()
  end

  test "eval/1 function calls without providing functions should raise" do
    hcl = """
    a = trim("   a ")
    """

    assert_raise ArgumentError, fn ->
      parse_and_eval(hcl)
    end
  end

  test "eval/1 function calls without incorrect arity should raise" do
    hcl = """
    a = trim("   a ")
    """

    assert_raise ArgumentError, fn ->
      parse_and_eval(hcl, functions: %{"trim" => fn _a, _b -> :ok end})
    end
  end

  test "eval/1 with function calls the provided function" do
    hcl = """
    a = trim("   a ")
    """

    assert %{"a" => "a"} = parse_and_eval(hcl, functions: %{"trim" => &String.trim/1})
  end

  test "eval/1 with function in functions" do
    hcl = """
    a = upcase(trim("   a "))
    """

    assert %{"a" => "A"} =
             parse_and_eval(hcl,
               functions: %{
                 "trim" => &String.trim/1,
                 "upcase" => &String.capitalize/1
               }
             )
  end

  test "eval/1 with index access ops" do
    hcl = """
    a = [1, 2, 3]
    b = a[1]
    c = a[2]
    """

    assert %{"b" => 2, "c" => 3} = parse_and_eval(hcl)
  end

  test "eval/1 with attr access ops" do
    hcl = """
    a = { b = { c = 1 } }
    b = a.b.c
    """

    assert %{"b" => 1} = parse_and_eval(hcl)
  end

  defp parse_and_eval(hcl, opts \\ []) do
    %{ctx: ctx} =
      hcl
      |> HCL.Parser.parse!()
      |> HCL.Eval.eval(opts)

    ctx
  end
end
