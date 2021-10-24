defmodule HXL.Evaluator.Base do
  use HXL.Evaluator

  alias HXL.Ast.{
    AccessOperation,
    Attr,
    Binary,
    Block,
    Body,
    Comment,
    Conditional,
    ForExpr,
    FunctionCall,
    Identifier,
    Literal,
    Object,
    TemplateExpr,
    Tuple,
    Unary
  }

  @impl true
  def eval(%Body{statements: stmts}, ctx) do
    Enum.reduce(stmts, ctx, fn x, acc ->
      case eval(x, acc) do
        {{k, v}, acc} ->
          %{acc | document: Map.put(acc.document, ctx.key_encoder.(k), v)}

        {map, acc} when is_map(map) ->
          %{acc | document: Map.merge(acc.document, map)}

        {:ignore, acc} ->
          acc
      end
    end)
  end

  def eval(%Block{body: body, type: type, labels: labels}, ctx) do
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

    block_ctx = eval(body, %{ctx | document: %{}})

    {put_in(ctx.document, block_scope, block_ctx.document), ctx}
  end

  def eval(%Attr{name: name, expr: expr}, ctx) do
    {value, ctx} = eval(expr, ctx)

    st = Map.put(ctx.symbol_table, name, value)
    {{name, value}, %{ctx | symbol_table: st}}
  end

  def eval(%Comment{}, ctx) do
    {:ignore, ctx}
  end

  def eval(%Unary{expr: expr, operator: op}, ctx) do
    {value, ctx} = eval(expr, ctx)

    {eval_unary_op(op, value), ctx}
  end

  def eval(%Binary{left: left, operator: op, right: right}, ctx) do
    {left_value, ctx} = eval(left, ctx)
    {right_value, ctx} = eval(right, ctx)

    value = eval_bin_op(op, left_value, right_value)

    {value, ctx}
  end

  def eval(%Literal{value: value}, ctx) do
    {ast_value_to_value(value), ctx}
  end

  def eval(%Identifier{name: name}, ctx) do
    id_value = Map.fetch!(ctx.symbol_table, name)
    {id_value, ctx}
  end

  def eval(%TemplateExpr{delimiter: _, lines: lines}, ctx) do
    {Enum.join(lines, "\n"), ctx}
  end

  def eval(%Tuple{values: values}, ctx) do
    {values, ctx} =
      Enum.reduce(values, {[], ctx}, fn value, {list, ctx} ->
        {value, ctx} = eval(value, ctx)
        {[value | list], ctx}
      end)

    {Enum.reverse(values), ctx}
  end

  def eval(%Object{kvs: kvs}, ctx) do
    Enum.reduce(kvs, {%{}, ctx}, fn {k, v}, {state, ctx} ->
      {value, ctx} = eval(v, ctx)
      state = Map.put(state, k, value)
      {state, ctx}
    end)
  end

  def eval(%Conditional{predicate: pred, then: then, else: else_}, ctx) do
    if pred |> eval(ctx) |> elem(0) do
      eval(then, ctx)
    else
      eval(else_, ctx)
    end
  end

  def eval(%FunctionCall{name: name, arity: arity, args: args}, %{functions: funcs} = ctx) do
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
            {eval_arg, ctx} = eval(arg, ctx)
            {[eval_arg | acc], ctx}
          end)

        {Kernel.apply(func, Enum.reverse(args)), ctx}
    end
  end

  def eval(
        %ForExpr{
          enumerable: enum,
          conditional: conditional,
          enumerable_type: e_t,
          keys: keys,
          body: body
        },
        ctx
      ) do
    {enum, ctx} = eval(enum, ctx)
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

  def eval(%AccessOperation{expr: expr, operation: op, key: key}, ctx) do
    {expr_value, ctx} = eval(expr, ctx)
    access_fn = eval_op(op, key, ctx)

    {Kernel.get_in(expr_value, List.wrap(access_fn)), ctx}
  end

  def eval({k, v}, ctx) do
    {k_value, ctx} = eval(k, ctx)
    {v_value, ctx} = eval(v, ctx)

    {{k_value, v_value}, ctx}
  end

  def eval_op(:index_access, index_expr, ctx) do
    {index, _} = eval(index_expr, ctx)

    Access.at(index)
  end

  def eval_op(:attr_access, attr, _ctx) do
    Access.key!(attr)
  end

  def eval_op(op, attrs, ctx) when op in [:attr_splat, :full_splat] do
    accs = for {op, key} <- attrs, do: eval_op(op, key, ctx)

    access_map(accs)
  end

  defp access_map(ops) do
    fn :get, data, next when is_list(data) ->
      data |> Enum.map(&get_in(&1, ops)) |> Enum.map(next)
    end
  end

  defp ast_value_to_value({_, value}), do: value

  defp eval_unary_op(:!, expr), do: !expr
  defp eval_unary_op(op, expr), do: apply(Kernel, op, [expr])

  defp eval_bin_op(:&&, left, right) do
    left && right
  end

  defp eval_bin_op(:||, left, right) do
    left || right
  end

  defp eval_bin_op(op, left, right) do
    apply(Kernel, op, [left, right])
  end

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
          {value, _} = eval(body, ctx)
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
          {value, _} = eval(body, ctx)
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
      |> eval(ctx)
      |> elem(0)
    end
  end
end
