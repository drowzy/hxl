defmodule HCL.ParserTest do
  use ExUnit.Case
  alias HCL.Parser
  alias HCL.Ast.{Tuple, Object, Literal, TemplateExpr, FunctionCall}

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

    test "parses tuples" do
      assert {:ok, [_, tuple], _, _, _, _} = Parser.parse("a = [1, true, null, \"string\"]")

      assert tuple == %Tuple{
               values: [
                 %Literal{value: {:int, 1}},
                 %Literal{value: {:bool, true}},
                 %Literal{value: {:null, nil}},
                 %TemplateExpr{delimiter: nil, lines: ["string"]}
               ]
             }
    end

    @tag :skip
    test "parses objects" do
      assert {:ok, [_ | %Object{}], _, _, _, _} = Parser.parse("a = { a: 1, b: true }")
    end

    test "parses variable expressions" do
      assert {:ok, ["a", "b"], _, _, _, _} = Parser.parse("a = b")
    end

    test "parses function calls" do
      assert {:ok, ["a", %FunctionCall{name: "func"}], _, _, _, _} = Parser.parse("a = func(1)")
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
