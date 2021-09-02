defmodule HCL.Ast.FunctionCall do
  defstruct [:args, :arity, :name]

  @type t :: %__MODULE__{
          args: list(),
          arity: non_neg_integer(),
          name: String.t()
        }
end
