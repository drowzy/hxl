defmodule HCL.ParserTest do
  use ExUnit.Case
  alias HCL.Parser

  describe "attr parser" do
    test "parses attr assignment with spaces" do
      assert {:ok, [id, value], _, _, _, _} = Parser.parse("a = 1")
      assert id = "a"
      assert value = 1
    end

    test "parses attr assignment without spaces" do
      assert {:ok, [id, value], _, _, _, _} = Parser.parse("a=1")
      assert id = "a"
      assert value = 1
    end
  end

  describe "block parser" do
    test "parses blocks with identifiers" do
      assert {:ok, ["service", "http", "a", 1], "", _, _, _} = Parser.parse("service http { a = 1 }")
    end

    test "parses blocks with identifiers with newlines" do
      assert {:ok, ["service", "http", "a", 1], "", _, _, _} = Parser.parse("service http {\n a = 1 \n}")
    end
  end
end
