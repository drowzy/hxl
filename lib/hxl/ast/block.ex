defmodule HXL.Ast.Block do
  defstruct [:type, :labels, :body]

  @type t :: %__MODULE__{
          type: term(),
          labels: list(),
          body: term()
        }
end
