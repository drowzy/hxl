defmodule HCL.Ast.Literal do
  @type t :: %__MODULE__{
          value: term()
        }
  defstruct [:value]
end

defmodule HCL.Ast.TemplateExpr do
  @type t :: %__MODULE__{
          delimiter: term(),
          lines: list(term())
        }

  defstruct [:delimiter, :lines]
end
