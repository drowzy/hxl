defmodule HXL.Ast.Binary do
  @moduledoc false

  defstruct [:operator, :left, :right]

  @type t :: %__MODULE__{
          operator: term(),
          left: term(),
          right: term()
        }
end
