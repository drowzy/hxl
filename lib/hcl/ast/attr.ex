defmodule HCL.Ast.Attr do
  defstruct [:name, :expr]

  @type t :: %__MODULE__{
          name: String.t(),
          expr: term()
        }
end
