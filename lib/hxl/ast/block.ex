defmodule HXL.Ast.Block do
  @moduledoc false

  defstruct [:type, :labels, :body]

  @type t :: %__MODULE__{
          type: term(),
          labels: list(),
          body: term()
        }
end
