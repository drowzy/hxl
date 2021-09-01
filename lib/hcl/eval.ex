defmodule HCL.Eval do
  @moduledoc ~S"""
  Evaluates the HCL AST into either a partially applied structure or fully-applied

  ## Examples

    %HCL.Ast.Body{} = body = HCL.from_binary("a = 1")
    %{"a" => 1} = HCL.Eval.eval(body)
  """

  alias HCL.Ast.{
    Attr,
    Block,
    Body,
    Identifier,
    Literal,
    Object,
    TemplateExpr,
    Tuple,
    Unary
  }

  defstruct ctx: %{}, symbol_table: %{}

  @type t :: %__MODULE__{ctx: Map.t()}

  @doc """
  Evaluates the Ast.
  """
  @spec eval(term(), Keyword.t()) :: {:ok, term()} | {:error, term()}
  def eval(hcl, _opts \\ []) do
    do_eval(hcl, %__MODULE__{})
  end

  defp do_eval(%Body{statements: stmts}, ctx) do
    Enum.reduce(stmts, ctx, fn x, acc ->
      case do_eval(x, acc) do
        {{k, v}, acc} -> %{acc | ctx: Map.put(acc.ctx, k, v)}
        {map, acc} when is_map(map) -> %{acc | ctx: Map.merge(acc.ctx, map)}
      end
    end)
  end

  defp do_eval(%Block{body: body, type: type, labels: labels}, ctx) do
    # Build a nested structure from type + labels.
    # Given the a block:
    # a "b" "c" {
    #   d = 1
    # }
    # The following structure should be created:
    #
    # {
    #   "a" => %{
    #     "b" => %{
    #       "d" => 1
    #     }
    #   }
    # }
    block_scope =
      [type | labels]
      |> scope([])
      |> Enum.reverse()

    block_ctx = do_eval(body, %__MODULE__{symbol_table: ctx.symbol_table})

    {put_in(ctx.ctx, block_scope, block_ctx.ctx), ctx}
  end

  defp do_eval(%Attr{name: name, expr: expr}, ctx) do
    {value, ctx} = do_eval(expr, ctx)

    st = Map.put(ctx.symbol_table, name, value)
    {{name, value}, %{ctx | symbol_table: st}}
  end

  defp do_eval(%Unary{expr: expr, operator: op}, ctx) do
    {value, ctx} = do_eval(expr, ctx)

    {apply(Kernel, op, [value]), ctx}
  end

  defp do_eval(%Literal{value: value}, ctx) do
    {ast_value_to_value(value), ctx}
  end

  defp do_eval(%Identifier{name: name}, ctx) do
    id_value = Map.fetch!(ctx.symbol_table, name)
    {id_value, ctx}
  end

  defp do_eval(%TemplateExpr{delimiter: nil, lines: lines}, ctx) do
    {Enum.join(lines, "\n"), ctx}
  end

  defp do_eval(%Tuple{values: values}, ctx) do
    {values, ctx} =
      Enum.reduce(values, {[], ctx}, fn value, {list, ctx} ->
        {value, ctx} = do_eval(value, ctx)
        {[value | list], ctx}
      end)

    {Enum.reverse(values), ctx}
  end

  defp do_eval(%Object{kvs: kvs}, ctx) do
    Enum.reduce(kvs, {%{}, ctx}, fn {k, v}, {state, ctx} ->
      {value, ctx} = do_eval(v, ctx)
      state = Map.put(state, k, value)
      {state, ctx}
    end)
  end

  defp ast_value_to_value({:int, int}) do
    int
  end

  def scope([key], acc) do
    [key | acc]
  end

  def scope([key | rest], acc) do
    acc = [Access.key(key, %{}) | acc]
    scope(rest, acc)
  end
end
