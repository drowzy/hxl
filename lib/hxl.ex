defmodule HXL do
  @moduledoc """
  Documentation for `HXL`.
  """
  alias __MODULE__.{Parser, Eval}

  @type opt ::
          {:variables, map()}
          | {:functions, map()}
          | {:keys, :atoms | :string}
  @type opts :: [opt()]

  @doc """
  Reads a `HCL` document from file.

  Uses same options as `decode/2`

  ## Examples

  iex> HXL.decode_file("/path/to/file.hcl")
  {:ok, %{"a" => "b"}}
  """
  @spec decode_file(Path.t(), opts()) :: {:ok, map()} | {:error, term()}
  def decode_file(path, opts \\ []) do
    with {:ok, bin} <- File.read(path),
         {:ok, _body} = return <- decode(bin, opts) do
      return
    else
      # File error
      {:error, reason} when is_atom(reason) ->
        msg =
          reason
          |> :file.format_error()
          |> List.to_string()

        {:error, msg}

      # Lex/parse error
      {:error, _reason} = err ->
        err
    end
  end

  @doc """
  Reads a `HCL` document from file, returns the document directly or raises `HXL.Error`.

  See `decode_file/1`
  """
  @spec decode_file!(Path.t(), opts) :: map() | no_return()
  def decode_file!(path, opts \\ []) do
    case decode_file(path, opts) do
      {:ok, body} -> body
      {:error, reason} -> raise HXL.Error, reason
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
  * `:keys` - controls how keys in the parsed AST are evaluated. Possible values are:
    * `:strings` (default) - evaluates keys as strings
    * `:atoms` - converts keys to atoms with `String.to_atom/1`
    * `:atoms!` - converts keys to atoms with `String.to_existing_atom/1`
    * `(key -> term)` - converts keys using the provided function


  ## Examples

  Using functions:

      iex> hcl = "a = upper(trim(\"   a  \"))"
      "a = upper(trim(\"   a  \"))"
      iex> HXL.decode(hcl, functions: %{"upper" => &String.capitalize/1, "trim" => &String.trim/1})
      {:ok, %{"a" => "A"}}

  Using variables:

      iex> hcl = "a = b"
      "a = b"
      iex> HXL.decode(hcl, variables: %{"b" => "B"})
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
  Reads a `HCL` document from a binary. Returns the document or  raises `HXL.Error`.

  See `from_binary/1`
  """
  @spec decode!(binary(), opts) :: map() | no_return()
  def decode!(bin, opts \\ []) do
    case decode(bin, opts) do
      {:ok, doc} -> doc
      {:error, reason} -> raise HXL.Error, reason
    end
  end

  @doc """
  Decode a binary to a  `HXL` document AST.

  ## Examples

      iex> HXL.decode_as_ast("a = 1")
      {:ok, %HXL.Ast.Body{
        statements: [
          %HXL.Ast.Attr{
            expr: %HXL.Ast.Literal{value: {:int, 1}}, name: "a"}
        ]
      }}
  """
  @spec decode_as_ast(binary()) :: {:ok, HXL.Ast.t()} | {:error, term()}
  defdelegate decode_as_ast(binary), to: __MODULE__.Parser, as: :parse
end
