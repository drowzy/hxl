defmodule HCL.Ast.Conditional do
  defstruct [:predicate, :then_stmt, :else_stmt]

  @type t :: %__MODULE__{
          predicate: term(),
          then_stmt: term(),
          else_stmt: term()
        }
end
