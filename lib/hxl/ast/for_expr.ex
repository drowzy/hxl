defmodule HXL.Ast.ForExpr do
  @moduledoc false

  defstruct [
    :keys,
    :enumerable,
    :enumerable_type,
    :body,
    :conditional
  ]

  @type t :: %__MODULE__{
          keys: list(),
          enumerable: term(),
          enumerable_type: :tuple | :object,
          body: term(),
          conditional: term()
        }
end
