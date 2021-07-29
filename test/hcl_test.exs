defmodule HCLTest do
  use ExUnit.Case
  doctest HCL

  test "greets the world" do
    assert HCL.hello() == :world
  end
end
