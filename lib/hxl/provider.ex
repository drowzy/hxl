defmodule HXL.Provider do
  @moduledoc """
  This module implements `Config.Provider` behaviour, so that HCL files can be used for configuration of releases.

  The provided file will be read by `HXL.Provider` during boot, the resulting Ast is evaluated with the given options,
  with the exception of the `keys`, which will always be set to `:atoms`.

  See `Config.Provider` for more info.

  ## Usage
      config_providers: [
        {HXL.Provider, [{:system, "RELEASE_ROOT", "/path/to/config.hcl"}]}
      ]


  Using a keyword list with options

      config_providers: [
        {HXL.Provider, path: "/path/to/config.hcl", functions: %{}, variables: %{}}
      ]

  """

  @behaviour Config.Provider

  @impl true
  def init(opts) when is_list(opts) do
    {path, opts} = Keyword.pop!(opts, :path)
    Config.Provider.validate_config_path!(path)

    {path, Keyword.put(opts, :keys, :atoms)}
  end

  def init(path), do: init(path: path)

  @impl true
  def load(config, {path, opts}) do
    kw =
      path
      |> HXL.decode_file!(opts)
      |> to_kw()

    Config.Reader.merge(config, kw)
  end

  defp to_kw(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {k, to_kw(v)} end)
    |> Enum.into([])
  end

  defp to_kw(v), do: v
end
