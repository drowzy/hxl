defmodule HXL.Ast.Tuple do
  @moduledoc false

  defstruct [:values]

  @type t :: %__MODULE__{
          values: list()
        }
end
