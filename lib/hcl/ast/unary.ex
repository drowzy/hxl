defmodule HCL.Ast.Unary do
  defstruct [:operator, :expr]

  @type t :: %__MODULE__{
          operator: term(),
          expr: term()
        }
end
