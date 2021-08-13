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
