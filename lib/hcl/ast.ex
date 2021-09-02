defmodule HCL.Ast do
  @type collection_value :: HCL.Ast.Tuple.t() | HCL.Ast.Object.t()
  @type expr_term ::
          HCL.Ast.Literal.t()
          | collection_value()
          | HCL.Ast.ForExpr.t()
          | HCL.Ast.TemplateExpr.t()
          | HCL.Ast.FunctionCall.t()
          | HCL.Ast.Identifier.t()

  @type t :: HCL.Body.t()
end
