defmodule HCLSpecSuite.HereDocTest do
  use ExUnit.Case

  @hcl """
  normal {
    basic = <<EOT
  Foo
  Bar
  Baz
  EOT
    indented = <<EOT
      Foo
      Bar
      Baz
    EOT
    indented_more = <<EOT
      Foo
        Bar
      Baz
    EOT
    interp = <<EOT
      Foo
      ${bar}
      Baz
    EOT
    newlines_between = <<EOT
  Foo

  Bar

  Baz
  EOT
    indented_newlines_between = <<EOT
      Foo

      Bar

      Baz
    EOT

    marker_at_suffix = <<EOT
      NOT EOT
    EOT
  }
  flush {
    basic = <<-EOT
  Foo
  Bar
  Baz
  EOT
    indented = <<-EOT
      Foo
      Bar
      Baz
    EOT
    indented_more = <<-EOT
      Foo
        Bar
      Baz
    EOT
    indented_less = <<-EOT
      Foo
    Bar
      Baz
    EOT
    interp = <<-EOT
      Foo
      ${bar}
      Baz
    EOT
    interp_indented_more = <<-EOT
      Foo
        ${bar}
      Baz
    EOT
    interp_indented_less = <<-EOT
      Foo
    ${space_bar}
      Baz
    EOT
    tabs = <<-EOT
    Foo
    Bar
    Baz
    EOT
    unicode_spaces = <<-EOT
      Foo (there's two "em spaces" before Foo there)
      Bar
      Baz
    EOT
    newlines_between = <<-EOT
  Foo

  Bar

  Baz
  EOT
    indented_newlines_between = <<-EOT
      Foo

      Bar

      Baz
    EOT
  }
  """

  setup do
    conf = HXL.decode!(@hcl)
    {:ok, hcl: conf}
  end

  describe "normal" do
    test "basic", %{hcl: %{"normal" => %{"basic" => basic}}} do
      assert basic == "Foo\nBar\nBaz"
    end

    test "indented", %{hcl: %{"normal" => %{"indented" => indented}}} do
      assert indented == "    Foo\n    Bar\n    Baz"
    end

    test "indented_newlines_between", %{
      hcl: %{"normal" => %{"indented_newlines_between" => indented}}
    } do
      assert indented == "    Foo\n    Bar\n    Baz"
    end

    test "interp", %{hcl: %{"normal" => %{"interp" => interp}}} do
      assert interp == "    Foo\n    ${bar}\n    Baz"
    end

    test "newlines between", %{hcl: %{"normal" => %{"newlines_between" => nb}}} do
      assert nb == "Foo\nBar\nBaz"
    end

    test "marker_at_suffix", %{hcl: %{"normal" => %{"marker_at_suffix" => mas}}} do
      assert String.trim(mas) == "NOT EOT"
    end
  end

  describe "flush" do
    test "basic", %{hcl: %{"flush" => %{"basic" => doc}}} do
      assert doc == "Foo\nBar\nBaz"
    end

    test "indented", %{hcl: %{"flush" => %{"indented" => doc}}} do
      assert doc == "    Foo\n    Bar\n    Baz"
    end

    test "indented_newlines_between", %{hcl: %{"flush" => %{"indented_newlines_between" => doc}}} do
      assert doc == "    Foo\n    Bar\n    Baz"
    end

    test "interp", %{hcl: %{"flush" => %{"interp" => doc}}} do
      assert doc == "    Foo\n    ${bar}\n    Baz"
    end

    test "tabs", %{hcl: %{"flush" => %{"tabs" => doc}}} do
      assert doc == "  Foo\n  Bar\n  Baz"
    end

    test "unicode_spaces", %{hcl: %{"flush" => %{"unicode_spaces" => doc}}} do
      assert doc == "    Foo (there's two \"em spaces\" before Foo there)\n    Bar\n    Baz"
    end
  end
end
