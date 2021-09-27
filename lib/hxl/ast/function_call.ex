defmodule HXL.Ast.FunctionCall do
  @moduledoc false

  defstruct [:args, :arity, :name]

  @type t :: %__MODULE__{
          args: list(),
          arity: non_neg_integer(),
          name: String.t()
        }
end
