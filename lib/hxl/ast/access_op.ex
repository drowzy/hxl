defmodule HXL.Ast.AccessOperation do
  @moduledoc false

  defstruct [:operation, :expr, :key]

  @type t :: %__MODULE__{
          operation: term(),
          expr: term(),
          key: term()
        }
end
