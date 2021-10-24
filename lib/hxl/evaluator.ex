defmodule HXL.Evaluator do
  @moduledoc """
  Defines the behaviour for custom evaluation of the AST returned from `HXL.Parser`

  See `c:eval/2` for more information
  """
  @type t :: module()

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  @doc ~S"""
  This functions is invoked for every AST node. There's a base implementation of a evaluator
  which is expected to be used by implmenters for handling nodes they're not interested in.

  ## Example

  An example would be to implement Terraform specific behaviours such as modules:

       hcl = ""\"
       module "servers" {
        source = "./servers"
        servers = 5
      }
       ""\"

  Using `HXL.Evaluator.Base` the result would be:

      %{"module" => %{"servers" => %{"servers" => 5, "source" => "./servers"}}}

  Using a different evaluator we can change how we interpret the AST:

      defmodule Terraform.Evaluator do
        use HXL.Evaluator

        alias HXL.Ast.{Block, Body, Attr}
        alias HXL.Evaluator.Base

        @impl true
        def eval(%Block{type: "module" = t, labels: [mod_name], body: body}, %HXL.Eval{} = ctx) do
          mod = mod_from_body(body)

          # We're not interesed to put anything in the document but to populate the
          # ctx with the ability to lookup values from the module

          symbol_table = put_in(ctx.symbol_table, [Access.key(t, %{}), mod_name], mod)

          {:ignore, %{ctx | symbol_table: symbol_table}}
        end

        def eval(ast, ctx), do: Base.eval(ast, ctx)

        defp mod_from_body(%Body{statements: stmts}) do
          case Enum.reduce(stmts, {nil, []}, &mod_args/2) do
            {nil, _} ->
              raise ArgumentError, message: "`source` argument are required for Terramform modules"

            {source, args} ->
              HXL.decode_file!(source <> ".tf", evaluator: __MODULE__, variables: mod_variables(args))
          end
        end

        defp mod_args(%Attr{name: "source", expr: expr}, {_, args}) do
          source =
            expr
            |> HXL.Evaluator.Base.eval(%{})
            |> elem(0)

          {source, args}
        end

        defp mod_args(arg, {source, args}) do
          {source, [arg | args]}
        end

        defp mod_variables(args) do
          for arg <- args, into: %{} do
            arg
            |> HXL.Evaluator.Base.eval(%HXL.Eval{})
            |> elem(0)
          end
        end
      end

  Given the following HCL document:

      hcl = ""\"
      module "servers" {
        source = "./servers"
        servers = 5
      }
      instance = module.servers.instances
      ""\"

  And a module file `servers.tf`:

      instances = ["127.0.0.1", "127.0.0.2", "127.0.0.3", "127.0.0.4", "127.0.0.5"]


  Eval using the `Terraform.Evaluator`

       iex>HXL.decode!(hcl, evaluator: Terraform.Evaluator)
       %{"instance" => ["127.0.0.1", "127.0.0.2", "127.0.0.3", "127.0.0.4", "127.0.0.5"]}

  """

  @callback eval(HXL.Ast.t(), HXL.Eval.t()) :: {term(), HXL.Eval.t()}
end
