defmodule HCL.Parser.TemplateExprTest do
  use ExUnit.Case

  alias :hcl_parser, as: Parser
  alias HCL.Lexer
  alias HCL.Ast.{Attr, TemplateExpr}

  test "heredoc template" do
    for op <- ["<<", "<<-"] do
      hcl = """
      a = #{op}EOT
      hello
      world
      EOT
      """

      assert {:ok, %Attr{expr: %TemplateExpr{delimiter: "EOT", lines: ["hello", "world"]}}} =
               parse(hcl)
    end
  end

  test "quoted template" do
    hcl = ~S(a = "hello world")

    assert {:ok, %Attr{expr: %TemplateExpr{lines: ["hello world"]}}} = parse(hcl)
  end

  test "quoted template with escape chars" do
    hcl = ~S(a = "hello world \"string\"")

    assert {:ok, %Attr{expr: %TemplateExpr{lines: ["hello world \"string\""]}}} = parse(hcl)
  end

  defp parse(str) do
    {:ok, tokens, _, _, _, _} = Lexer.tokenize(str)
    Parser.parse(tokens)
  end
end
