defmodule HCL.Ast.Conditional do
  defstruct [:predicate, :then, :else]

  @type t :: %__MODULE__{
          predicate: term(),
          then: term(),
          else: term()
        }
end
