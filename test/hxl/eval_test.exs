defmodule HXL.EvalTest do
  use ExUnit.Case

  test "keys :atoms" do
    hcl = """
    a = 1
    b "c" "d" {
      e = 2
    }
    """

    assert %{a: 1} = parse_and_eval(hcl, keys: :atoms)
  end

  test "keys :atoms with variables" do
    hcl = """
    a = b
    """

    assert %{a: 1} = parse_and_eval(hcl, keys: :atoms, variables: %{"b" => 1})
  end

  test "keys :atoms with functions" do
    hcl = """
    a = upper("a")
    """

    assert %{a: "A"} =
             parse_and_eval(hcl, keys: :atoms, functions: %{"upper" => &String.capitalize/1})
  end

  test "eval/1 blocks with same type" do
    hcl = """
    a "b" {}

    a "c" {}
    """

    ctx = parse_and_eval(hcl)
    assert %{"a" => %{"b" => %{}, "c" => %{}}} == ctx
  end

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

  test "eval/1 attr string interpolation" do
    hcl = ~S"""
    b = "interpolation"
    a = "before ${b} after ${1 + 3}"
    """

    ctx = parse_and_eval(hcl)

    assert %{"a" => "before interpolation after 4"} = ctx
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

  test "eval/1 repeated block" do
    hcl = """
    foo {
      bar = 1
    }

    foo {
      bar = 2
    }
    """

    ctx = parse_and_eval(hcl)

    assert %{"foo" => [%{"bar" => 1}, %{"bar" => 2}]} == ctx
  end

  test "eval/1 repeated nested block" do
    hcl = """
    foo {
      bar {
        baz = 1
      }
    }

    foo {
      bar {
        baz = 2
      }
    }
    """

    ctx = parse_and_eval(hcl)

    assert %{"foo" => [%{"bar" => %{"baz" => 1}}, %{"bar" => %{"baz" => 2}}]} == ctx
  end

  test "eval/1 inner repeated nested block" do
    hcl = """
    foo {
      bar {
        baz = 1
      }
      bar {
        baz = 2
      }
    }

    foo {
      bar {
        baz = 2
      }
    }
    """

    ctx = parse_and_eval(hcl)

    assert %{
             "foo" => [
               %{"bar" => [%{"baz" => 1}, %{"baz" => 2}]},
               %{"bar" => %{"baz" => 2}}
             ]
           } == ctx
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

  test "eval/1 with nested index access ops" do
    hcl = """
    a = ["a", [1,2,3]]
    b = a[1][2]
    """

    assert %{"b" => 3} = parse_and_eval(hcl)
  end

  test "eval/1 with attr access ops" do
    hcl = """
    a = { b = { c = { d = 1} } }
    b = a.b.c.d
    """

    assert %{"b" => 1} = parse_and_eval(hcl)
  end

  test "eval/1 with attrs-splat ops" do
    hcl = """
    a = [{b = 1}, {b = 2}, {b = 3}]
    b = a.*.b
    """

    assert %{"b" => [1, 2, 3]} = parse_and_eval(hcl)
  end

  test "eval/1 attrs-splat with index access" do
    hcl = """
    a = [{b = 1}, {b = 2}, {b = 3}]
    b = a.*.b[0]
    """

    assert %{"b" => 1} = parse_and_eval(hcl)
  end

  test "eval/1 full-splat with index access" do
    hcl = """
    a = [{b = [1,2,3]}, {b = [2,1,3]}, {b = [3,2,1]}]
    b = a[*].b[0]
    """

    assert %{"b" => [1, 2, 3]} = parse_and_eval(hcl)
  end

  test "eval/1 tuple for-expr" do
    hcl = """
    a = [for v in ["a", "b"]: v]
    b = [for i, v in ["a", "b"]: i]
    c = [for i, v in ["a", "b", "c"]: v if i < 2]
    d = [for i, v in ["a", "b", "c"]: v if i == 0]
    """

    assert %{"a" => a, "b" => b, "c" => c, "d" => d} = parse_and_eval(hcl)
    assert a == ["a", "b"]
    assert b == [0, 1]
    assert c == ["a", "b"]
    assert d == ["a"]
  end

  test "eval/1 object for-expr" do
    hcl = """
    a = {for i, v in ["a", "b"]: v => i}
    b = {for i, v in ["a", "b"]: v => i if i == 0}
    c = {for i, v in ["a", "b"]: v => upcase(v)}
    """

    assert %{"a" => a, "b" => b, "c" => c} =
             parse_and_eval(hcl, functions: %{"upcase" => &String.capitalize/1})

    assert a == %{"a" => 0, "b" => 1}
    assert b == %{"a" => 0}
    assert c == %{"a" => "A", "b" => "B"}
  end

  defp parse_and_eval(hcl, opts \\ []) do
    %{document: doc} = hcl |> HXL.Parser.parse!() |> HXL.Eval.eval(opts)

    doc
  end

  hcl = """
  b "c" "d" {
    e = 2
  }
  """

  hcl |> HXL.Parser.parse!() |> HXL.Eval.eval(keys: :atoms)
end
