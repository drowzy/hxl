defmodule HCL.Ast.Body do
  defstruct [:statements]

  @type t :: %__MODULE__{
          statements: list()
        }
end
