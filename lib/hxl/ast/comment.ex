defmodule HXL.Ast.Comment do
  @moduledoc false

  defstruct [:lines, :type]

  @type t :: %__MODULE__{
          lines: list(String.t()),
          type: :line | :inline
        }
end
