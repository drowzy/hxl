defmodule HCL.Ast.AccessOperation do
  defstruct [:operation, :expr]

  @type t :: %__MODULE__{
          operation: term(),
          expr: term()
        }
end
