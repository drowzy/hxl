defmodule HCL.Ast.Object do
  defstruct [:kvs]

  @type t :: %__MODULE__{
          kvs: map()
        }
end
