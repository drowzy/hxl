defmodule HXL.Eval do
  @moduledoc false

  alias HXL.Ast.Body
  defstruct [:functions, :key_encoder, document: %{}, symbol_table: %{}]

  @type t :: %__MODULE__{
          document: map(),
          functions: map(),
          symbol_table: map(),
          key_encoder: (binary -> term())
        }
  @doc """
  Evaluates the Ast by walking the tree recursivly.

  The resulting document is fully evaluated. Note if any syntax elements such as undefined variables / functions,
  will result in an error being raised.


  ## Examples

      hcl = "a = trim("    a ")"
      {:ok, %HXL.Ast.Body{} = body} = HXL.decode_as_ast(hcl)
      %{"a" => "a"} = HXL.Eval.eval(body, functions: %{"trim" => &String.trim/1})

      hcl = "a = b"
      {:ok, %HXL.Ast.Body{} = body} = HXL.decode_as_ast(hcl)
      %{"a" => 1} = HXL.Eval.eval(body, variables: %{"b" => 1})
  """

  @spec eval(term(), Keyword.t()) :: t()
  def eval(hcl, opts \\ []) do
    functions = Keyword.get(opts, :functions, %{})
    symbol_table = Keyword.get(opts, :variables, %{})
    evaluator = Keyword.get(opts, :evaluator, HXL.Evaluator.Base)

    key_encoder =
      opts
      |> Keyword.get(:keys, :strings)
      |> key_encoder()

    ctx = %__MODULE__{
      key_encoder: key_encoder,
      functions: functions,
      symbol_table: symbol_table
    }

    do_eval(hcl, evaluator, ctx)
  end

  # Evals the top the top level body
  defp do_eval(%Body{statements: stmts}, evaluator, ctx) do
    Enum.reduce(stmts, ctx, fn x, acc ->
      case evaluator.eval(x, acc) do
        {{k, v}, acc} ->
          %{acc | document: Map.put(acc.document, ctx.key_encoder.(k), v)}

        {map, acc} when is_map(map) ->
          %{acc | document: Map.merge(acc.document, map)}

        {:ignore, acc} ->
          acc
      end
    end)
  end

  defp key_encoder(:strings), do: &Function.identity/1
  defp key_encoder(:atoms), do: &String.to_atom/1
  defp key_encoder(:atoms!), do: &String.to_existing_atom/1
  defp key_encoder(fun) when is_function(fun, 1), do: fun

  defp key_encoder(arg),
    do:
      raise(
        ArgumentError,
        "Invalid :keys option '#{inspect(arg)}', valid options :strings, :atoms, :atoms!, (binary -> term)"
      )
end
