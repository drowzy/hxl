defmodule HXL.Eval do
  @moduledoc false

  alias HXL.Ast.{
    AccessOperation,
    Attr,
    Binary,
    Block,
    Body,
    Comment,
    ForExpr,
    FunctionCall,
    Identifier,
    Literal,
    Object,
    TemplateExpr,
    Tuple,
    Unary
  }

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

    key_encoder =
      opts
      |> Keyword.get(:keys, :strings)
      |> key_encoder()

    do_eval(hcl, %__MODULE__{
      key_encoder: key_encoder,
      functions: functions,
      symbol_table: symbol_table
    })
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

  defp do_eval(%Body{statements: stmts}, ctx) do
    Enum.reduce(stmts, ctx, fn x, acc ->
      case do_eval(x, acc) do
        {{k, v}, acc} ->
          %{acc | document: Map.put(acc.document, ctx.key_encoder.(k), v)}

        {map, acc} when is_map(map) ->
          %{acc | document: Map.merge(acc.document, map)}

        {:ignore, acc} ->
          acc
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
      |> Enum.map(ctx.key_encoder)
      |> scope([])
      |> Enum.reverse()

    block_ctx = do_eval(body, %{ctx | document: %{}})

    {put_in(ctx.document, block_scope, block_ctx.document), ctx}
  end

  defp do_eval(%Attr{name: name, expr: expr}, ctx) do
    {value, ctx} = do_eval(expr, ctx)

    st = Map.put(ctx.symbol_table, name, value)
    {{name, value}, %{ctx | symbol_table: st}}
  end

  defp do_eval(%Comment{}, ctx) do
    {:ignore, ctx}
  end

  defp do_eval(%Unary{expr: expr, operator: op}, ctx) do
    {value, ctx} = do_eval(expr, ctx)

    {apply(Kernel, op, [value]), ctx}
  end

  defp do_eval(%Binary{left: left, operator: op, right: right}, ctx) do
    {left_value, ctx} = do_eval(left, ctx)
    {right_value, ctx} = do_eval(right, ctx)

    {apply(Kernel, op, [left_value, right_value]), ctx}
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

  defp do_eval(%FunctionCall{name: name, arity: arity, args: args}, %{functions: funcs} = ctx) do
    case Map.get(funcs, name) do
      nil ->
        raise ArgumentError,
          message:
            "FunctionCalls cannot be used without providing a function with the same arity in #{__MODULE__}.eval/2. Got: #{name}/#{arity}"

      func when not is_function(func, arity) ->
        raise ArgumentError,
          message:
            "FunctionCall arity missmatch Expected: #{name}/#{arity} got: arity=#{:erlang.fun_info(func)[:arity]}"

      func ->
        {args, ctx} =
          Enum.reduce(args, {[], ctx}, fn arg, {acc, ctx} ->
            {eval_arg, ctx} = do_eval(arg, ctx)
            {[eval_arg | acc], ctx}
          end)

        {Kernel.apply(func, Enum.reverse(args)), ctx}
    end
  end

  defp do_eval(
         %ForExpr{
           enumerable: enum,
           conditional: conditional,
           enumerable_type: e_t,
           keys: keys,
           body: body
         },
         ctx
       ) do
    {enum, ctx} = do_eval(enum, ctx)
    {acc, reducer} = closure(keys, conditional, body, ctx)

    for_into =
      case e_t do
        :for_tuple -> &Function.identity/1
        :for_object -> &Enum.into(&1, %{})
      end

    iterated =
      enum
      |> Enum.reduce(acc, reducer)
      |> elem(0)
      |> Enum.reverse()
      |> for_into.()

    {iterated, ctx}
  end

  defp do_eval(%AccessOperation{expr: expr, operation: op, key: key}, ctx) do
    {expr_value, ctx} = do_eval(expr, ctx)
    access_fn = eval_op(op, key, ctx)

    {Kernel.get_in(expr_value, List.wrap(access_fn)), ctx}
  end

  defp do_eval({k, v}, ctx) do
    {k_value, ctx} = do_eval(k, ctx)
    {v_value, ctx} = do_eval(v, ctx)

    {{k_value, v_value}, ctx}
  end

  defp eval_op(:index_access, index_expr, ctx) do
    {index, _} = do_eval(index_expr, ctx)

    Access.at(index)
  end

  defp eval_op(:attr_access, attr, _ctx) do
    Access.key!(attr)
  end

  defp eval_op(op, attrs, ctx) when op in [:attr_splat, :full_splat] do
    accs = for {op, key} <- attrs, do: eval_op(op, key, ctx)

    access_map(accs)
  end

  defp access_map(ops) do
    fn :get, data, next when is_list(data) ->
      data |> Enum.map(&get_in(&1, ops)) |> Enum.map(next)
    end
  end

  defp ast_value_to_value({_, value}), do: value

  def scope([key], acc) do
    [key | acc]
  end

  def scope([key | rest], acc) do
    acc = [Access.key(key, %{}) | acc]
    scope(rest, acc)
  end

  defp closure([key], conditional, body, ctx) do
    conditional_fn = closure_cond(conditional)

    reducer = fn v, {acc, ctx} ->
      ctx = %{ctx | symbol_table: Map.put(ctx.symbol_table, key, v)}

      acc =
        if conditional_fn.(ctx) do
          {value, _} = do_eval(body, ctx)
          [value | acc]
        else
          acc
        end

      {acc, ctx}
    end

    {{[], ctx}, reducer}
  end

  defp closure([index, value], conditional, body, ctx) do
    conditional_fn = closure_cond(conditional)

    reducer = fn v, {acc, i, ctx} ->
      st =
        ctx.symbol_table
        |> Map.put(index, i)
        |> Map.put(value, v)

      ctx = %{ctx | symbol_table: st}

      acc =
        if conditional_fn.(ctx) do
          {value, _} = do_eval(body, ctx)
          [value | acc]
        else
          acc
        end

      {acc, i + 1, ctx}
    end

    {{[], 0, ctx}, reducer}
  end

  defp closure_cond(nil), do: fn _ctx -> true end

  defp closure_cond(expr) do
    fn ctx ->
      expr
      |> do_eval(ctx)
      |> elem(0)
    end
  end
end
