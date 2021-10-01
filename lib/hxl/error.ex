defmodule HXL.Error do
  @moduledoc "HXL.Error"

  defexception [:message]

  def exception(msg) when is_binary(msg) do
    %__MODULE__{message: msg}
  end

  def exception(reason) when is_tuple(reason) do
    msg = format_reason(reason)

    %__MODULE__{message: msg}
  end

  def message(%{message: msg}) do
    msg
  end

  @doc """
  Internal errors to printable messages
  """
  def format_reason({:parse_error, {line, offset}, [reason | info]}) do
    "#{upcase_first(reason)}#{line}:#{offset} #{format_info(info)}"
  end

  def format_reason({:lex_error, {line, offset}, rest}) do
    "Unrecognized input: '#{rest}' at #{line}:#{offset}"
  end

  defp format_info(info) when is_list(info) do
    info
    |> Enum.map(&to_string/1)
    |> Enum.join(" ")
  end

  defp upcase_first(<<char::utf8, rest::binary>>),
    do: String.upcase(<<char::utf8>>) <> rest
end
