defmodule HCLSpecSuite.OperatorsTest do
  use ExUnit.Case

  @hcl """
    equality "==" {
      exactly = "a" == "a"
      not     = "a" == "b"

      type_mismatch_number = "1" == 1
      type_mismatch_bool   = "true" == true
    }

    equality "!=" {
      exactly = "a" != "a"
      not     = "a" != "b"

      type_mismatch_number = "1" != 1
      type_mismatch_bool   = "true" != true
    }

    inequality "<" {
      lt  = 1 < 2
      gt  = 2 < 1
      eq  = 1 < 1
    }
    inequality "<=" {
      lt  = 1 <= 2
      gt  = 2 <= 1
      eq  = 1 <= 1
    }
    inequality ">" {
      lt  = 1 > 2
      gt  = 2 > 1
      eq  = 1 > 1
    }
    inequality ">=" {
      lt  = 1 >= 2
      gt  = 2 >= 1
      eq  = 1 >= 1
    }

    arithmetic {
      add      = 2 + 3.5
      add_big  = 3.14159265358979323846264338327950288419716939937510582097494459 + 1
      sub      = 3.5 - 2
      sub_neg  = 2 - 3.5
      mul      = 2 * 4.5
      div      = 1 / 10
      mod      = 11 % 5
      # mod_frac = 11 % 5.1 TODO rem/2 only handles integers
    }

    logical_binary "&&" {
      tt  = true && true
      ft  = false && true
      tf  = true && false
      ff  = false && false
    }
    logical_binary "||" {
      tt  = true || true
      ft  = false || true
      tf  = true || false
      ff  = false || false
    }

    logical_unary "!" {
      t   = !true
      f   = !false
    }

    conditional {
      t   = true ? "a" : "b"
      f   = false ? "a" : "b"
    }
  """

  setup do
    {:ok, map} = HXL.decode(@hcl)

    {:ok, hcl: map}
  end

  test "equality ==", %{hcl: %{"equality" => %{"==" => eq}}} do
    assert eq["exactly"]
    refute eq["not"]
    refute eq["type_mismatch_number"]
    refute eq["type_mismatch_bool"]
  end

  test "equality !=", %{hcl: %{"equality" => %{"!=" => eq}}} do
    refute eq["exactly"]
    assert eq["not"]
    assert eq["type_mismatch_number"]
    assert eq["type_mismatch_bool"]
  end

  test "inequality <", %{hcl: %{"inequality" => %{"<" => eq}}} do
    assert eq["lt"]
    refute eq["gt"]
    refute eq["eq"]
  end

  test "inequality <=", %{hcl: %{"inequality" => %{"<=" => eq}}} do
    assert eq["lt"]
    refute eq["gt"]
    assert eq["eq"]
  end

  test "inequality >", %{hcl: %{"inequality" => %{">" => eq}}} do
    refute eq["lt"]
    assert eq["gt"]
    refute eq["eq"]
  end

  test "inequality >=", %{hcl: %{"inequality" => %{">=" => eq}}} do
    refute eq["lt"]
    assert eq["gt"]
    assert eq["eq"]
  end

  test "arithmetic", %{hcl: %{"arithmetic" => a}} do
    assert a["add"] == 5.5
    assert a["add_big"] == 4.141592653589793
    assert a["sub"] == 1.5
    assert a["sub_neg"] == -1.5
    assert a["mul"] == 9
    assert a["div"] == 0.1
    assert a["mod"] == 1
  end

  test "logical_binary &&", %{hcl: %{"logical_binary" => %{"&&" => eq}}} do
    assert eq["tt"]
    refute eq["ft"]
    refute eq["tf"]
    refute eq["ff"]
  end

  test "logical_binary ||", %{hcl: %{"logical_binary" => %{"||" => eq}}} do
    assert eq["tt"]
    assert eq["ft"]
    assert eq["tf"]
    refute eq["ff"]
  end

  test "logical_unary !", %{hcl: %{"logical_unary" => %{"!" => eq}}} do
    refute eq["t"]
    assert eq["f"]
  end

  test "conditional", %{hcl: %{"conditional" => c}} do
    assert "a" == c["t"]
    assert "b" == c["f"]
  end
end
