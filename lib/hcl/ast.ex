defmodule HCL.Ast.Literal do
  @type t :: %__MODULE__{
          value: term()
        }
  defstruct [:value]

  def from_tokens(_rest, [literal], ctx, _line, _offset) do
    {[%__MODULE__{value: literal}], ctx}
  end
end

defmodule HCL.Ast.TemplateExpr do
  @type t :: %__MODULE__{
          delimiter: term(),
          lines: list(term())
        }

  defstruct [:delimiter, :lines]

  def from_tokens(_rest, [{:heredoc, [delimiter | lines]}], ctx, _line, _offset) do
    {[%__MODULE__{delimiter: delimiter, lines: lines}], ctx}
  end

  def from_tokens(_rest, [{:qouted_template, lines}], ctx, _line, _offset) do
    {[%__MODULE__{lines: lines}], ctx}
  end
end

defmodule HCL.Ast.Tuple do
  @type t :: %__MODULE__{
          values: list()
        }
  defstruct [:values]

  def from_tokens(_rest, values, ctx, _line, _offset) do
    {[%__MODULE__{values: Enum.reverse(values)}], ctx}
  end
end

defmodule HCL.Ast.Object do
  @type t :: %__MODULE__{
          kvs: Map.t()
        }
  defstruct [:kvs]

  def from_tokens(_rest, kvs, ctx, _line, _offset) do
    kvs =
      kvs
      |> Enum.reverse()
      |> Enum.chunk_every(2)
      |> Map.new(fn [k, v] -> {k, v} end)

    {[%__MODULE__{kvs: kvs}], ctx}
  end
end

defmodule HCL.Ast.FunctionCall do
  @type t :: %__MODULE__{
          args: list(),
          arity: non_neg_integer(),
          name: String.t()
        }

  defstruct [:args, :arity, :name]

  def from_tokens(_rest, [name], ctx, _line, _offset) do
    {[%__MODULE__{name: name, arity: 0, args: []}], ctx}
  end

  def from_tokens(_rest, args, ctx, _line, _offset) do
    [name | args] = Enum.reverse(args)

    call = %__MODULE__{
      name: name,
      arity: length(args),
      args: args
    }

    {[call], ctx}
  end
end

# TODO might need two different expressions
defmodule HCL.Ast.ForExpr do
  @type t :: %__MODULE__{
          keys: list(),
          enumerable: term(),
          enumerable_type: :tuple | :object,
          body: term(),
          conditional: term()
        }

  defstruct [:keys, :enumerable, :enumerable_type, :body, :conditional]

  def from_tokens(_rest, [{for_type, args}], ctx, _line, _offset)
      when for_type in [:tuple, :object] do
    {ids, rest} = Enum.split_while(args, &identifier?/1)
    {enumerable, body, conditional} = post_process_for_body(for_type, rest)

    for_expr = %__MODULE__{
      keys: post_process_for_ids(ids),
      enumerable: enumerable,
      enumerable_type: for_type,
      body: body,
      conditional: conditional
    }

    {[for_expr], ctx}
  end

  defp post_process_for_ids(ids) do
    for {:identifier, id} <- ids, do: id
  end

  defp post_process_for_body(:tuple, [enum, body]) do
    {enum, body, nil}
  end

  defp post_process_for_body(:tuple, [enum, body | conditional]) do
    {enum, body, conditional}
  end

  defp post_process_for_body(:object, [enum, key_expr, value_expr]) do
    {enum, {key_expr, value_expr}, nil}
  end

  defp post_process_for_body(:object, [enum, key_expr, value_expr | conditional]) do
    {enum, {key_expr, value_expr}, conditional}
  end

  defp identifier?({:identifier, _}), do: true
  defp identifier?(_), do: false
end
