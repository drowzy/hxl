defmodule HXL.Ast.Attr do
  @moduledoc false

  defstruct [:name, :expr]

  @type t :: %__MODULE__{
          name: String.t(),
          expr: term()
        }
end
