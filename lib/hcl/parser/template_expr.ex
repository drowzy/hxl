defmodule HCL.Parser.TemplateExpr do
  import NimbleParsec
  import HCL.Parser.LiteralValue, only: [string_lit: 0]
  import HCL.Parser.Common, only: [whitespace: 0, identifier: 0, newline: 0]
  alias HCL.Ast.TemplateExpr
  # ## Template Expr
  # TODO If a heredoc template is introduced with the <<- symbol, any literal string at the start of each line is analyzed to find the minimum number of leading spaces, and then that number of prefix spaces is removed from all line-leading literal strings. The final closing marker may also have an arbitrary number of spaces preceding it on its line.
  def quoted_template, do: string_lit() |> tag(:qouted_template)

  def heredoc_line, do: utf8_string([not: ?\n], min: 1) |> ignore(newline())

  def heredoc_template do
    choice([ignore(string("<<-")), ignore(string("<<"))])
    |> concat(identifier())
    |> ignore(whitespace())
    |> repeat(heredoc_line())
    |> post_traverse({__MODULE__, :validate_heredoc_matching_terminator, []})
    |> tag(:heredoc)
  end

  def validate_heredoc_matching_terminator(_rest, [close_id | content], ctx, _line, _offset) do
    [open_id | _] = Enum.reverse(content)

    if open_id == close_id do
      {content, ctx}
    else
      {:error, "Expected identifier: #{open_id} to be closed. Got: #{close_id}"}
    end
  end

  def emit_ast(_rest, [{:heredoc, [delimiter | lines]}], ctx, _line, _offset) do
    {[%TemplateExpr{delimiter: delimiter, lines: lines}], ctx}
  end

  def emit_ast(_rest, [{:qouted_template, lines}], ctx, _line, _offset) do
    {[%TemplateExpr{lines: lines}], ctx}
  end

  def template_expr do
    choice([quoted_template(), heredoc_template()]) |> post_traverse({__MODULE__, :emit_ast, []})
  end
end
