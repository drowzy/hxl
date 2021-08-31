defmodule HCL.Ast.Literal do
  @type t :: %__MODULE__{
          value: term()
        }
  defstruct [:value]
end

defmodule HCL.Ast.Identifier do
  @type t :: %__MODULE__{
          name: term()
        }
  defstruct [:name]
end

defmodule HCL.Ast.TemplateExpr do
  @type t :: %__MODULE__{
          delimiter: term(),
          lines: list(term())
        }

  defstruct [:delimiter, :lines]
end

defmodule HCL.Ast.Tuple do
  @type t :: %__MODULE__{
          values: list()
        }
  defstruct [:values]
end

defmodule HCL.Ast.Object do
  @type t :: %__MODULE__{
          kvs: Map.t()
        }
  defstruct [:kvs]
end

defmodule HCL.Ast.FunctionCall do
  @type t :: %__MODULE__{
          args: list(),
          arity: non_neg_integer(),
          name: String.t()
        }

  defstruct [:args, :arity, :name]
end

# TODO might need two different expressions
defmodule HCL.Ast.ForExpr do
  @type t :: %__MODULE__{
          keys: list(),
          enumerable: term(),
          enumerable_type: :tuple | :object,
          body: term(),
          conditional: term()
        }

  defstruct [:keys, :enumerable, :enumerable_type, :body, :conditional]
end

defmodule HCL.Ast.Binary do
  @type t :: %__MODULE__{
          operator: term(),
          left: term(),
          right: term()
        }

  defstruct [:operator, :left, :right]
end

defmodule HCL.Ast.Unary do
  @type t :: %__MODULE__{
          operator: term(),
          expr: term()
        }

  defstruct [:operator, :expr]
end

defmodule HCL.Ast.AccessOperation do
  @type t :: %__MODULE__{
          operation: term(),
          expr: term()
        }
  defstruct [:operation, :expr]
end

defmodule HCL.Ast.Conditional do
  @type t :: %__MODULE__{
          predicate: term(),
          then_stmt: term(),
          else_stmt: term()
        }

  defstruct [:predicate, :then_stmt, :else_stmt]
end

defmodule HCL.Ast.Attr do
  @type t :: %__MODULE__{
          name: String.t(),
          expr: term()
        }

  defstruct [:name, :expr]
end

defmodule HCL.Ast.Block do
  @type t :: %__MODULE__{
          type: term(),
          labels: list(),
          body: term()
        }

  defstruct [:type, :labels, :body]
end

defmodule HCL.Ast.Body do
  @type t :: %__MODULE__{
          statements: list()
        }

  defstruct [:statements]
end
