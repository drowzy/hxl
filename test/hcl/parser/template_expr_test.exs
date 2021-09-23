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

  # test "quoted template" do
  #   hcl = ~S("hello world")

  #   assert {:ok, [%TemplateExpr{lines: ["hello world"]}], _, _, _, _} = Parser.parse_template(hcl)
  # end

  # test "quoted template with escape chars" do
  #   hcl = ~S("hello world \"string\"")

  #   assert {:ok, [%TemplateExpr{lines: ["hello world \"string\""]}], _, _, _, _} =
  #            Parser.parse_template(hcl)
  # end

  defp parse(str) do
    {:ok, tokens, _, _, _, _} = Lexer.tokenize(str)
    Parser.parse(tokens)
  end
end
