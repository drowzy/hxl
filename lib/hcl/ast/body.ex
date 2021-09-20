defmodule HCL.Ast.Body do
  defstruct [:statements]

  @type statement :: HCL.Ast.Attr | HCL.Ast.Block
  @type t :: %__MODULE__{
          statements: [statement]
        }
end
