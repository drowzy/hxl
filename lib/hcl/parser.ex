defmodule HCL.Parser do
  @moduledoc false

  alias :hcl_parser, as: Parser

  @doc """
  Lexes and parses a raw binary safely.

  Returns `{:ok, HCL.Ast.t()}` or {:error, term()}
  """
  @spec parse(binary()) :: {:ok, HCL.Ast.t()} | {:error, term()}
  def parse(input) do
    with {:ok, tokens, _, _, _, _} <- HCL.Lexer.tokenize(input),
         {:ok, ast} <- Parser.parse(tokens) do
      {:ok, ast}
    else
      {:ok, [], rest, _ctx, loc, _} ->
        {:error, HCL.Error.format_reason({:lex_error, loc, rest})}

      {:error, {loc, _, reason}} ->
        {:error, HCL.Error.format_reason({:parse_error, loc, reason})}
    end
  end

  @doc """
  Lexes and parses a raw binary.

  Raises `HCL.Error` if lexing or parsing fails
  """
  @spec parse!(binary()) :: HCL.Ast.Body.t()
  def parse!(input) do
    case parse(input) do
      {:ok, body} ->
        body

      {:error, msg} ->
        raise HCL.Error, msg
    end
  end
end
