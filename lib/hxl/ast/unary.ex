defmodule HXL.Ast.Unary do
  @moduledoc false

  defstruct [:operator, :expr]

  @type t :: %__MODULE__{
          operator: :! | :-,
          expr: HXL.Ast.expr_term()
        }
end
