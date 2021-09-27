defmodule HCL.Ast.Unary do
  defstruct [:operator, :expr]

  @type t :: %__MODULE__{
          operator: :! | :-,
          expr: HCL.Ast.expr_term()
        }
end
