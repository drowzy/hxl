defmodule HCL.Ast.Binary do
  defstruct [:operator, :left, :right]

  @type t :: %__MODULE__{
    operator: term(),
    left: term(),
    right: term()
  }

end
