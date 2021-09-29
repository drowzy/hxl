defmodule HXL.ProviderTest do
  use ExUnit.Case

  test "can use provider" do
    path = Path.join([__DIR__, "fixtures", "provider.hcl"])
    opts = HXL.Provider.init(path: path)
    config = HXL.Provider.load([], opts)

    Application.put_all_env(config)

    assert "value" = get_in(config, [:config, :value])
    assert get_in(config, [:config, :active])

    assert Application.get_env(:config, :active)

    config2 = HXL.Provider.load([other_config: [value: "value"]], opts)

    Application.put_all_env(config2)

    refute Application.get_env(:config, :disabled)

    assert "value" == Application.get_env(:other_config, :value)
  end

  test "overrides any `:keys` opts" do
    path = Path.join([__DIR__, "fixtures", "provider.hcl"])
    opts = HXL.Provider.init(path: path, keys: :string)
    config = HXL.Provider.load([], opts)

    Enum.each(config, fn {k, _} -> assert is_atom(k) end)
  end
end
