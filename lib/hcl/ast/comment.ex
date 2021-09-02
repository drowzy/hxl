defmodule HCL.Ast.Comment do
  defstruct [:lines, :type]

  @type t :: %__MODULE__{
          lines: list(String.t()),
          type: :line | :inline
        }
end
