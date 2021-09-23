defmodule HCL.Parser do
  alias :hcl_parser, as: Parser

  @spec parse(binary()) :: {:ok, HCL.Ast.t()} | {:error, term()}
  def parse(input) do
    with {:ok, tokens, _, _, _, _} <- HCL.Lexer.tokenize(input),
         {:ok, ast} <- Parser.parse(tokens) do
      {:ok, ast}
    end
  end

  @spec parse!(binary()) :: HCL.Ast.Body.t()
  def parse!(input) do
    case parse(input) do
      {:ok, body} ->
        body
      {:error, reason} ->
        raise "err #{inspect(reason)}"

      {:error, reason, rest, _ctx, {line, line_offset}, _} ->
        raise "err #{inspect(reason)} rest=#{rest} line: #{inspect(line)} offset=#{line_offset}"
    end
  end
end
