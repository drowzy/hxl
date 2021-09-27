defmodule HXL.Ast do
  @moduledoc """
  HCL Ast
  """

  @type collection_value :: HXL.Ast.Tuple.t() | HXL.Ast.Object.t()
  @type expr_term ::
          HXL.Ast.Literal.t()
          | collection_value()
          | HXL.Ast.ForExpr.t()
          | HXL.Ast.Binary.t()
          | HXL.Ast.Unary.t()
          | HXL.Ast.TemplateExpr.t()
          | HXL.Ast.FunctionCall.t()
          | HXL.Ast.Identifier.t()

  @type t :: HXL.Ast.Body.t()
end
