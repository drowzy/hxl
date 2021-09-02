defmodule HCL.ParserTest do
  use ExUnit.Case
  alias HCL.Parser

  alias HCL.Ast.{
    Attr,
    Block,
    Body,
    Comment,
    FunctionCall,
    Identifier,
    Literal,
    Object,
    TemplateExpr,
    Tuple
  }

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

    test "can parse comments" do
      for seq <- ["//", "#"] do
        hcl = """
        #{seq} hello_world
        """
        {:ok, %Body{statements: [%Comment{}]}} = Parser.parse(hcl)
      end
    end

    test "supports multiple attrs" do
      hcl = """
      a = 1
      b = 2
      """

      {:ok,
       %Body{
         statements: [
           %Attr{name: "a", expr: %Literal{value: {:int, 1}}},
           %Attr{name: "b", expr: %Literal{value: {:int, 2}}}
         ]
       }} = Parser.parse(hcl)
    end

    test "supports attrs & blocks" do
      hcl = """
      a = 1
      service http {
        b = 2
      }
      """

      {:ok,
       %Body{
         statements: [
           %Attr{name: "a", expr: %Literal{value: {:int, 1}}},
           %Block{
             type: "service",
             labels: ["http"],
             body: %Body{statements: [%Attr{name: "b", expr: %Literal{value: {:int, 2}}}]}
           }
         ]
       }} = Parser.parse(hcl)
    end
  end

  describe "attr parser" do
    test "parses attr assignment with spaces" do
      assert {:ok, %Body{statements: [attr]}} = Parser.parse("a = 1")
      assert attr.name == "a"
      assert attr.expr == %Literal{value: {:int, 1}}
    end

    test "parses attr assignment without spaces" do
      assert {:ok, %Body{statements: [attr]}} = Parser.parse("a=1")
      assert attr.name == "a"
      assert attr.expr == %Literal{value: {:int, 1}}
    end

    test "parses decimal values" do
      assert {:ok, %Body{statements: [attr]}} = Parser.parse("a = 1.1")
      assert attr.name == "a"
      assert attr.expr == %Literal{value: {:decimal, 1.1}}
    end

    test "parses tuples" do
      assert {:ok, %Body{statements: [%Attr{expr: tuple}]}} =
               Parser.parse("a = [1, true, null, \"string\"]")

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
      assert {:ok, %Body{statements: [%Attr{expr: %Object{}}]}} =
               Parser.parse("a = { a: 1, b: true }")
    end

    test "parses variable expressions" do
      assert {:ok, %Body{statements: [attr]}} = Parser.parse("a = b")
      assert attr.name == "a"
      assert attr.expr == %Identifier{name: "b"}
    end

    test "parses function calls" do
      assert {:ok, %Body{statements: [%Attr{name: "a", expr: %FunctionCall{name: "func"}}]}} =
               Parser.parse("a = func(1)")
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

        assert {:ok,
                %Body{
                  statements: [
                    %Attr{
                      name: "a",
                      expr: %TemplateExpr{delimiter: "EOT", lines: ["hello", "world"]}
                    }
                  ]
                }} = Parser.parse(hcl)
      end
    end

    test "quoted template" do
      hcl = ~S(a = "hello world")

      assert {:ok,
              %Body{
                statements: [%Attr{expr: %TemplateExpr{delimiter: nil, lines: ["hello world"]}}]
              }} = Parser.parse(hcl)
    end
  end

  describe "block parser" do
    test "parses blocks with identifiers" do
      assert {:ok,
              %Body{
                statements: [
                  %Block{
                    body: %Body{
                      statements: [%Attr{expr: %Literal{value: {:int, 1}}, name: "a"}]
                    },
                    labels: ["http"],
                    type: "service"
                  }
                ]
              }} = Parser.parse("service http { a = 1 }")
    end

    test "parses blocks with identifiers with newlines" do
      assert {:ok,
              %Body{
                statements: [
                  %Block{
                    body: %Body{
                      statements: [%Attr{expr: %Literal{value: {:int, 1}}, name: "a"}]
                    },
                    labels: ["http"],
                    type: "service"
                  }
                ]
              }} = Parser.parse("service http {\n a = 1 \n}")
    end

    test "parses blocks with string literals" do
      assert {:ok,
              %Body{
                statements: [
                  %Block{
                    body: %Body{
                      statements: [%Attr{expr: %Literal{value: {:int, 1}}, name: "a"}]
                    },
                    labels: ["http"],
                    type: "service"
                  }
                ]
              }} = Parser.parse(~s(service "http" { a = 1 }))
    end

    test "parses block within a block" do
      hcl = """
      service http {
        command process {
          a = 1
        }
      }
      """

      {:ok, %Body{statements: [%Block{} = b]}} = Parser.parse(hcl)
      assert b.type == "service"
      assert b.labels == ["http"]
      assert %Body{statements: [%Block{}]} = b.body
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
       %Body{
         statements: [
           %Block{
             body: %Body{
               statements: [
                 %Attr{expr: %Literal{value: {:int, 1}}, name: "a"},
                 %Attr{expr: %Literal{value: {:int, 2}}, name: "b"},
                 %Block{
                   body: %Body{statements: [%Attr{expr: %Literal{value: {:int, 3}}, name: "c"}]},
                   labels: ["process"],
                   type: "command"
                 }
               ]
             },
             labels: ["http"],
             type: "service"
           }
         ]
       }} = Parser.parse(hcl)
    end
  end
end
