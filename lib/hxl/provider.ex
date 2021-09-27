defmodule HXL.Provider do
  @moduledoc """
  This module implements `Config.Provider` behaviour, so that HCL files can be used for configuration of releases.

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

    {path, opts}
  end

  def init(path), do: init(path: path)

  @impl true
  def load(config, {path, opts}) do
    with {:ok, map} <- HXL.decode_file(path, opts) do
      persist(config, map)
    else
      {:error, reason} -> exit(reason)
    end
  end

  defp persist(_config, map) do
    :ok
  end
end
