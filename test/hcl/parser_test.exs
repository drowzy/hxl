defmodule HCL.ParserTest do
  use ExUnit.Case
  alias HCL.Parser

  describe "body parser" do
    test "supports multiple attrs" do
      hcl = """
      a = 1
      b = 2
      """

      {:ok, ["a", 1, "b", 2], _, _, _, _} = Parser.parse(hcl)
    end

    test "supports attrs & blocks" do
      hcl = """
      a = 1
      service http {
        b = 2
      }
      """

      {:ok, ["a", 1, "service", "http", "b", 2], _, _, _, _} = Parser.parse(hcl)
    end
  end

  describe "attr parser" do
    test "parses attr assignment with spaces" do
      assert {:ok, [id, value], _, _, _, _} = Parser.parse("a = 1")
      assert id == "a"
      assert value == 1
    end

    test "parses attr assignment without spaces" do
      assert {:ok, [id, value], _, _, _, _} = Parser.parse("a=1")
      assert id == "a"
      assert value == 1
    end

    test "parses decimal values" do
      assert {:ok, [id | values], _, _, _, _} = Parser.parse("a = 1.1")
      assert id == "a"
      assert values == [1, 1]
    end

    test "parses decimal values with expmarks" do
      for exp <- ["e", "E", "+", "-"] do
        assert {:ok, [id | values], _, _, _, _} = Parser.parse("a = 1.1#{exp}1")
        assert id == "a"
        assert values == [1, 1, exp, 1]
      end
    end

    test "parses bool: true" do
      assert {:ok, [id, bool], _, _, _, _} = Parser.parse("a = true")
      assert bool
    end

    test "parses bool: false" do
      assert {:ok, [id, bool], _, _, _, _} = Parser.parse("a = false")
      refute bool
    end

    test "parses null" do
      assert {:ok, [id, null], _, _, _, _} = Parser.parse("a = null")
      assert is_nil(null)
    end
  end

  describe "block parser" do
    test "parses blocks with identifiers" do
      assert {:ok, ["service", "http", "a", 1], "", _, _, _} =
               Parser.parse("service http { a = 1 }")
    end

    test "parses blocks with identifiers with newlines" do
      assert {:ok, ["service", "http", "a", 1], "", _, _, _} =
               Parser.parse("service http {\n a = 1 \n}")
    end

    test "parses blocks with string literals" do
      assert {:ok, ["service", "http", "a", 1], "", _, _, _} =
               Parser.parse(~s(service "http" { a = 1 }))
    end

    test "parses block within a block" do
      hcl = """
      service http {
        command process {
          a = 1
        }
      }
      """

      {:ok, ["service", "http", "command", "process", "a", 1], _, _, _, _} = Parser.parse(hcl)
    end

    test "parses block and attrs inside a block" do
      hcl = """
      service http {
        a = 1
        b = 2
        command process {
          c = 3
        }
      }
      """

      {:ok, ["service", "http", "a", 1, "b", 2, "command", "process", "c", 3], _, _, _, _} =
        Parser.parse(hcl)
    end
  end
end
