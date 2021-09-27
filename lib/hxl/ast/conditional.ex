defmodule HXL.Ast.Conditional do
  @moduledoc false

  defstruct [:predicate, :then, :else]

  @type t :: %__MODULE__{
          predicate: term(),
          then: term(),
          else: term()
        }
end
