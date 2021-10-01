defmodule HXL.Parser do
  @moduledoc false

  alias :hcl_parser, as: Parser

  @doc """
  Lexes and parses a raw binary safely.

  Returns `{:ok, HXL.Ast.t()}` or {:error, term()}
  """
  @spec parse(binary()) :: {:ok, HXL.Ast.t()} | {:error, term()}
  def parse(input) do
    with {:ok, tokens, <<>>, _, _, _} <- HXL.Lexer.tokenize(input),
         {:ok, ast} <- Parser.parse(tokens) do
      {:ok, ast}
    else
      {:ok, _tokens, rest, _ctx, loc, _} ->
        {:error, HXL.Error.format_reason({:lex_error, loc, rest})}

      {:error, {loc, _, reason}} ->
        {:error, HXL.Error.format_reason({:parse_error, loc, reason})}
    end
  end

  @doc """
  Lexes and parses a raw binary.

  Raises `HXL.Error` if lexing or parsing fails
  """
  @spec parse!(binary()) :: HXL.Ast.Body.t()
  def parse!(input) do
    case parse(input) do
      {:ok, body} ->
        body

      {:error, msg} ->
        raise HXL.Error, msg
    end
  end
end
