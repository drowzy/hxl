defmodule HXL.Ast.TemplateExpr do
  @moduledoc false
  defstruct [:delimiter, :lines]

  @type t :: %__MODULE__{
          delimiter: binary(),
          lines: list(binary())
        }
end
