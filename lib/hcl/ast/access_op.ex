defmodule HCL.Ast.AccessOperation do
  defstruct [:operation, :expr, :key]

  @type t :: %__MODULE__{
          operation: term(),
          expr: term(),
          key: term()
        }
end
