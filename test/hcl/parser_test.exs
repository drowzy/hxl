defmodule HCL.ParserTest do
  use ExUnit.Case
  alias HCL.Parser
  alias HCL.Ast.{Literal, TemplateExpr}

  describe "body parser" do
    @tag :skip
    test "can parse complete config" do
      hcl = """
      io_mode = "async"

      service "web_proxy" {
        listen_addr = "127.0.0.1:8080"

        process "main" {
          command = ["/usr/local/bin/awesome-app", "server"]
        }

        process "mgmt" {
          command = ["/usr/local/bin/awesome-app", "mgmt"]
        }
      }
      """

      {:ok,
       [
         "io_mode",
         "async",
         "service",
         "web_proxy",
         "listen_addr",
         "127.0.0.1:8080",
         "process",
         "main",
         "command",
         "/usr/local/bin/awesome-app",
         "server",
         "process",
         "mgmt",
         "command",
         "/usr/local/bin/awesome-app",
         "mgmt"
       ], _, _, _, _} = Parser.parse(hcl)
    end

    test "supports multiple attrs" do
      hcl = """
      a = 1
      b = 2
      """

      {:ok, ["a", %Literal{value: {:int, 1}}, "b", %Literal{value: {:int, 2}}], _, _, _, _} =
        Parser.parse(hcl)
    end

    test "supports attrs & blocks" do
      hcl = """
      a = 1
      service http {
        b = 2
      }
      """

      {:ok, ["a", %Literal{value: {:int, 1}}, "service", "http", "b", %Literal{value: {:int, 2}}],
       _, _, _, _} = Parser.parse(hcl)
    end
  end

  describe "attr parser" do
    test "parses attr assignment with spaces" do
      assert {:ok, [id, value], _, _, _, _} = Parser.parse("a = 1")
      assert id == "a"
      assert value == %Literal{value: {:int, 1}}
    end

    test "parses attr assignment without spaces" do
      assert {:ok, [id, value], _, _, _, _} = Parser.parse("a=1")
      assert id == "a"
      assert value == %Literal{value: {:int, 1}}
    end

    test "parses decimal values" do
      assert {:ok, [id | values], _, _, _, _} = Parser.parse("a = 1.1")
      assert id == "a"
      assert values == [%Literal{value: {:decimal, 1.1}}]
    end

    test "parses tuples of different types " do
      assert {:ok, [_ | values], _, _, _, _} = Parser.parse("a = [1, true, null, \"string\"]")

      assert values == [
               %Literal{value: {:int, 1}},
               %Literal{value: {:bool, true}},
               %Literal{value: {:null, nil}},
               %TemplateExpr{delimiter: nil, lines: ["string"]}
             ]
    end

    test "parses objects of different types" do
      assert {:ok, [_ | values], _, _, _, _} = Parser.parse("a = { a: 1, b: true }")

      values =
        values
        |> Enum.chunk_every(2)
        |> Map.new(fn [k, v] -> {k, v} end)

      assert values == %{
               "a" => %HCL.Ast.Literal{value: {:int, 1}},
               "b" => %HCL.Ast.Literal{value: {:bool, true}}
             }
    end

    test "parses object elems with `=` assignment" do
      assert {:ok, [_ | values], _, _, _, _} = Parser.parse("a = { a = 1, b = true }")

      values =
        values
        |> Enum.chunk_every(2)
        |> Map.new(fn [k, v] -> {k, v} end)

      assert values == %{
               "a" => %HCL.Ast.Literal{value: {:int, 1}},
               "b" => %HCL.Ast.Literal{value: {:bool, true}}
             }
    end

    test "parses variable expressions" do
      {:ok, ["a", "b"], _, _, _, _} = Parser.parse("a = b")
    end

    test "parses function calls without args" do
      {:ok, ["a", "func", %Literal{value: {:int, 1}}], _, _, _, _} = Parser.parse("a = func(1)")
    end

    test "parses for expr for tuples" do
      {:ok, ["a", "for", "a", "b", "upper", "a"], _, _, _, _} =
        HCL.Parser.parse("a = [for a in b : upper(a)]")
    end

    test "parses for expr for tuples with conditional" do
      {:ok, ["a", "for", "a", "b", "upper", "a", "if", "a"], _, _, _, _} =
        HCL.Parser.parse("a = [for a in b : upper(a) if a]")
    end

    test "parses for expr for objects" do
      {:ok, ["a", "for", "a", "v", "b", "v", "a"], _, _, _, _} =
        HCL.Parser.parse("a = {for a, v in b : v => a}")
    end

    test "parses for expr for objects with conditional" do
      {:ok, ["a", "for", "a", "v", "b", "v", "a", "if", "a"], _, _, _, _} =
        HCL.Parser.parse("a = {for a, v in b : v => a if a}")
    end
  end

  describe "template parser" do
    test "heredoc template" do
      for op <- ["<<", "<<-"] do
        hcl = """
        a = #{op}EOT
        hello
        world
        EOT
        """

        assert {:ok, ["a", %TemplateExpr{delimiter: "EOT", lines: ["hello", "world"]}], _, _, _,
                _} = Parser.parse(hcl)
      end
    end

    test "quoted template" do
      hcl = ~S(a = "hello world")

      assert {:ok, ["a", %TemplateExpr{delimiter: nil, lines: ["hello world"]}], _, _, _, _} =
               Parser.parse(hcl)
    end
  end

  describe "block parser" do
    test "parses blocks with identifiers" do
      assert {:ok, ["service", "http", "a", %Literal{value: {:int, 1}}], "", _, _, _} =
               Parser.parse("service http { a = 1 }")
    end

    test "parses blocks with identifiers with newlines" do
      assert {:ok, ["service", "http", "a", %Literal{value: {:int, 1}}], "", _, _, _} =
               Parser.parse("service http {\n a = 1 \n}")
    end

    test "parses blocks with string literals" do
      assert {:ok, ["service", "http", "a", %Literal{value: {:int, 1}}], "", _, _, _} =
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

      {:ok, ["service", "http", "command", "process", "a", %Literal{value: {:int, 1}}], _, _, _,
       _} = Parser.parse(hcl)
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

      {:ok,
       [
         "service",
         "http",
         "a",
         %Literal{value: {:int, 1}},
         "b",
         %Literal{value: {:int, 2}},
         "command",
         "process",
         "c",
         %Literal{value: {:int, 3}}
       ], _, _, _, _} = Parser.parse(hcl)
    end
  end
end
