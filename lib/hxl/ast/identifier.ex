defmodule HXL.Ast.Identifier do
  defstruct [:name]

  @type t :: %__MODULE__{name: term()}
end
