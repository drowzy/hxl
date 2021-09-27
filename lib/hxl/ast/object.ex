defmodule HXL.Ast.Object do
  @moduledoc false

  defstruct [:kvs]

  @type t :: %__MODULE__{
          kvs: map()
        }
end
