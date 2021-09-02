defmodule HCL.Ast.TemplateExpr do
  defstruct [:delimiter, :lines]

  @type t :: %__MODULE__{
          delimiter: binary(),
          lines: list(binary())
        }
end
