defmodule HCL.Parser.TemplateExprTest do
  use ExUnit.Case
  alias HCL.Parser
  alias HCL.Ast.TemplateExpr

  test "heredoc template" do
    for op <- ["<<", "<<-"] do
      hcl = """
      #{op}EOT
      hello
      world
      EOT
      """

      assert {:ok, [%TemplateExpr{delimiter: "EOT", lines: ["hello", "world"]}], _, _, _, _} =
               Parser.parse_template(hcl)
    end
  end

  test "quoted template" do
    hcl = ~S("hello world")

    assert {:ok, [%TemplateExpr{lines: ["hello world"]}], _, _, _, _} = Parser.parse_template(hcl)
  end

  test "quoted template with escape chars" do
    hcl = ~S("hello world \"string\"")

    assert {:ok, [%TemplateExpr{lines: ["hello world \"string\""]}], _, _, _, _} =
             Parser.parse_template(hcl)
  end
end