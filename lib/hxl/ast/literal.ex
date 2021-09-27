defmodule HXL.Ast.Literal do
  @moduledoc false

  defstruct [:value]

  @type t :: %__MODULE__{value: term()}
end
