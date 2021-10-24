defmodule TerraformTest do
  use ExUnit.Case
  doctest Terraform

  test "greets the world" do
    assert Terraform.hello() == :world
  end
end
