defmodule HXL.Ast.Identifier do
  @moduledoc false

  defstruct [:name]

  @type t :: %__MODULE__{name: term()}
end
