defmodule HCL do
  @moduledoc """
  Documentation for `HCL`.
  """
  alias __MODULE__.{Parser, Eval}

  @type opt ::
          {:variables, map()}
          | {:functions, map()}
  @type opts :: [opt()]

  @doc """
  Reads a `HCL` document from file.
  """
  @spec decode_file(Path.t(), opts()) :: {:ok, map()} | {:error, term()}
  def decode_file(path, opts \\ []) do
    with {:ok, bin} <- File.read(path),
         {:ok, _body} = return <- decode(bin, opts) do
      return
    end
  end

  @doc """
  Reads a `HCL` document from file. see `decode_file/1`
  """
  @spec decode_file!(Path.t(), opts) :: map()
  def decode_file!(path, opts \\ []) do
    case decode_file(path, opts) do
      {:ok, body} -> body
      {:error, reason} -> raise "err #{inspect(reason)}"
    end
  end

  @doc """
  Decode a binary to a  `HCL` document.

  `decode/2` parses and evaluates the AST before returning the `HCL` docuement.
  If the document is using functions in it's definition, these needs to be passed in the `opts` part of this functions.
  See bellow for an example

  ## Options

  The following options can be passed to configure evaluation of the document:

  * `:functions` - A map of `(<function_name> -> <function>)` to make available in document evaluation.
  * `:variables` - A map of Top level variables that should be injected into the context when evaluating the document.


  ## Examples

  Using functions:

      iex> hcl = "a = upper(trim(\"   a  \"))"
      "a = upper(trim(\"   a  \"))"
      iex> HCL.decode(hcl, functions: %{"upper" => &String.capitalize/1, "trim" => &String.trim/1})
      {:ok, %{"a" => "A"}}

  Using variables:

      iex> hcl = "a = b"
      "a = b"
      iex> HCL.decode(hcl, variables: %{"b" => "B"})
      {:ok, %{"a" => "B"}}

  """
  @spec decode(binary(), opts()) :: {:ok, map()} | {:error, term()}
  def decode(binary, opts \\ []) do
    with {:ok, body} <- Parser.parse(binary),
         %Eval{document: doc} <- Eval.eval(body, opts) do
      {:ok, doc}
    end
  end

  @doc """
  Reads a `HCL` document from a binary. See `from_binary/1`
  """
  @spec decode!(binary(), opts) :: map()
  def decode!(bin, opts \\ []) do
    bin
    |> Parser.parse!()
    |> Eval.eval(opts)
  end

  @doc """
  Decode a binary to a  `HCL` document AST.

  ## Examples

      iex> HCL.decode_as_ast("a = 1")
      {:ok, %HCL.Ast.Body{
        statements: [
          %HCL.Ast.Attr{
            expr: %HCL.Ast.Literal{value: {:int, 1}}, name: "a"}
        ]
      }}
  """
  @spec decode_as_ast(binary()) :: {:ok, HCL.Ast.t()} | {:error, term()}
  defdelegate decode_as_ast(binary), to: __MODULE__.Parser, as: :parse
end
