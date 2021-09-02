defmodule HCL.Ast.Tuple do
  defstruct [:values]

  @type t :: %__MODULE__{
          values: list()
        }
end
