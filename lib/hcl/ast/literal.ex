defmodule HCL.Ast.Literal do
  defstruct [:value]

  @type t :: %__MODULE__{value: term()}
end
