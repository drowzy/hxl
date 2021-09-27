defmodule HXL.Ast.Body do
  defstruct [:statements]

  @type statement :: HXL.Ast.Attr | HXL.Ast.Block
  @type t :: %__MODULE__{
          statements: [statement]
        }
end
