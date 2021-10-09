defmodule HXL.ParserTest do
  use ExUnit.Case
  import HXL.Parser, only: [parse: 1]

  alias HXL.Ast.{
    AccessOperation,
    Attr,
    Binary,
    Block,
    Body,
    Comment,
    ForExpr,
    FunctionCall,
    Identifier,
    Literal,
    Object,
    TemplateExpr,
    Tuple,
    Unary
  }

  describe "body parser" do
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

      assert {:ok, %Body{}} = parse(hcl)
    end

    test "can parse comments" do
      for seq <- ["//", "#"] do
        hcl = """
        #{seq} hello_world
        """

        {:ok, %Body{statements: [%Comment{}]}} = parse(hcl)
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
       }} = parse(hcl)
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
       }} = parse(hcl)
    end
  end

  describe "Binary/unary exprs" do
    test "can parse unary ops: >, >=, <, <=, ==" do
      for op <- ["-", "!"] do
        op_atom = String.to_existing_atom(op)

        assert {:ok,
                %Body{
                  statements: [
                    %Attr{
                      expr: %Unary{
                        operator: ^op_atom,
                        expr: %Literal{value: {:int, 1}}
                      }
                    }
                  ]
                }} = parse("a = #{op}1")
      end
    end

    test "can parse comparison ops: >, >=, <, <=, ==" do
      for op <- [">", ">=", "<", "<=", "=="] do
        op_atom = String.to_existing_atom(op)

        assert {:ok,
                %Body{
                  statements: [
                    %Attr{
                      expr: %Binary{
                        operator: ^op_atom,
                        left: %Literal{value: {:int, 1}},
                        right: %Literal{value: {:int, 2}}
                      }
                    }
                  ]
                }} = parse("a = 1 #{op} 2")
      end
    end

    test "can parse arithemtic ops: +, -, /, *" do
      for op <- ["+", "-", "/", "*"] do
        op_atom = String.to_existing_atom(op)

        assert {:ok,
                %Body{
                  statements: [
                    %Attr{
                      expr: %Binary{
                        operator: ^op_atom,
                        left: %Literal{value: {:int, 1}},
                        right: %Literal{value: {:int, 2}}
                      }
                    }
                  ]
                }} = parse("a = 1 #{op} 2")
      end
    end

    test "can parse logic ops: &&, ||" do
      for op <- ["&&", "||"] do
        op_atom = String.to_existing_atom(op)

        assert {:ok,
                %Body{
                  statements: [
                    %Attr{
                      expr: %Binary{
                        operator: ^op_atom,
                        left: %Literal{value: {:int, 1}},
                        right: %Literal{value: {:int, 2}}
                      }
                    }
                  ]
                }} = parse("a = 1 #{op} 2")
      end
    end
  end

  describe "function calls" do
    test "parses 0-arity functions" do
      assert {:ok, %Body{statements: [%Attr{expr: %FunctionCall{} = call}]}} = parse("a = func()")
      assert call.arity == 0
      assert call.args == []
      assert call.name == "func"
    end

    test "parses 1-arity functions" do
      assert {:ok, %Body{statements: [%Attr{expr: %FunctionCall{} = call}]}} =
               parse("a = func(1)")

      assert call.arity == 1
      refute Enum.empty?(call.args)
      assert call.name == "func"
    end

    test "parses n-arity functions" do
      assert {:ok, %Body{statements: [%Attr{expr: %FunctionCall{} = call}]}} =
               parse("a = func(1, 2, 3, 4, 5)")

      assert call.arity == 5
      refute Enum.empty?(call.args)
      assert call.name == "func"
    end
  end

  describe "collections" do
    test "parses tuples of single type " do
      assert {:ok, %Body{statements: [%Attr{expr: %Tuple{values: values}}]}} =
               parse("a = [1, 2, 3]")

      assert values == [
               %Literal{value: {:int, 1}},
               %Literal{value: {:int, 2}},
               %Literal{value: {:int, 3}}
             ]
    end

    test "tuple with newlines" do
      hcl = "a = [\n  1,\n  2,\n  3\n]"

      assert {:ok, %Body{statements: [%Attr{expr: %Tuple{values: values}}]}} = parse(hcl)
      refute values == []
    end

    test "parses empty tuple" do
      assert {:ok, %Body{statements: [%Attr{expr: %Tuple{values: []}}]}} = parse("a = []")
    end

    test "parses tuples of different types " do
      {:ok, %Body{statements: [%Attr{expr: %Tuple{values: values}}]}} =
        parse("a = [1, true, null, \"string\"]")

      assert values == [
               %Literal{value: {:int, 1}},
               %Literal{value: {:bool, true}},
               %Literal{value: {:null, nil}},
               %TemplateExpr{lines: [{:string_part, "string"}]}
             ]
    end

    test "parses objects with `:` assignment" do
      assert {:ok, %Body{statements: [%Attr{expr: %Object{kvs: kvs}}]}} =
               parse("a = { a: 1, b: true }")

      assert is_map(kvs)
      assert kvs["a"] == %Literal{value: {:int, 1}}
      assert kvs["b"] == %Literal{value: {:bool, true}}
    end

    test "parses objects with `=` assignment" do
      assert {:ok, %Body{statements: [%Attr{expr: %Object{kvs: kvs}}]}} =
               parse("a = { a = 1, b = true }")

      assert is_map(kvs)
      assert kvs["a"] == %Literal{value: {:int, 1}}
      assert kvs["b"] == %Literal{value: {:bool, true}}
    end
  end

  describe "tuple for expr" do
    test "with variable enumerable" do
      assert {:ok, %Body{statements: [%Attr{expr: %ForExpr{} = for_expr}]}} =
               parse("a = [for v in d: v]")

      assert for_expr.keys == ["v"]
      assert for_expr.enumerable == %Identifier{name: "d"}
      assert for_expr.body == %Identifier{name: "v"}
      assert for_expr.enumerable_type == :for_tuple
      assert for_expr.conditional == nil
    end

    test "with multiple keys" do
      assert {:ok, %Body{statements: [%Attr{expr: %ForExpr{} = for_expr}]}} =
               parse("a = [for i, j in d: j]")

      assert for_expr.keys == ["i", "j"]
    end

    test "with inline enumerable" do
      assert {:ok, %Body{statements: [%Attr{expr: %ForExpr{} = for_expr}]}} =
               parse("a = [for v in [1, 2]: v]")

      assert for_expr.keys == ["v"]
      assert %Tuple{} = for_expr.enumerable
      assert for_expr.body == %Identifier{name: "v"}
      assert for_expr.enumerable_type == :for_tuple
    end

    test "with function bodies" do
      assert {:ok, %Body{statements: [%Attr{expr: %ForExpr{} = for_expr}]}} =
               parse("a = [for v in [1, 2]: func(v)]")

      assert %FunctionCall{name: "func"} = for_expr.body
    end

    test "with conditional" do
      assert {:ok, %Body{statements: [%Attr{expr: %ForExpr{} = for_expr}]}} =
               parse("a = [for v in [1, 2]: v if v]")

      assert for_expr.keys == ["v"]
      assert %Tuple{} = for_expr.enumerable
      assert for_expr.body == %Identifier{name: "v"}
      assert for_expr.enumerable_type == :for_tuple
      assert for_expr.conditional == %Identifier{name: "v"}
    end
  end

  describe "object for expr" do
    test "with variable enumerable" do
      assert {:ok, %Body{statements: [%Attr{expr: %ForExpr{} = for_expr}]}} =
               parse("a = {for v in d: v => v}")

      assert for_expr.keys == ["v"]
      assert for_expr.enumerable == %Identifier{name: "d"}
      assert for_expr.body == {%Identifier{name: "v"}, %Identifier{name: "v"}}
      assert for_expr.enumerable_type == :for_object
      assert for_expr.conditional == nil
    end

    test "with multiple keys" do
      assert {:ok, %Body{statements: [%Attr{expr: %ForExpr{} = for_expr}]}} =
               parse("a = {for i, j in d: j => i}")

      assert for_expr.keys == ["i", "j"]
    end

    test "with inline enumerable" do
      assert {:ok, %Body{statements: [%Attr{expr: %ForExpr{} = for_expr}]}} =
               parse("a = {for v in [1, 2]: v => v}")

      assert %Tuple{} = for_expr.enumerable
    end

    test "with function bodies" do
      assert {:ok, %Body{statements: [%Attr{expr: %ForExpr{} = for_expr}]}} =
               parse("a = {for v in [1, 2]: v => func(v)}")

      assert {_, %FunctionCall{name: "func"}} = for_expr.body
    end

    test "with conditional" do
      assert {:ok, %Body{statements: [%Attr{expr: %ForExpr{} = for_expr}]}} =
               parse("a = {for v in [1, 2]: v => v if v}")

      assert for_expr.conditional == %Identifier{name: "v"}
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
                }} = parse(hcl)
      end
    end

    test "quoted template" do
      hcl = ~S(a = "hello world")

      assert {:ok,
              %Body{
                statements: [
                  %Attr{
                    expr: %TemplateExpr{delimiter: nil, lines: [{:string_part, "hello world"}]}
                  }
                ]
              }} = parse(hcl)
    end

    test "template interpolation" do
      hcl = ~S(a = "hello ${1 + 1} world")

      assert {:ok,
              %Body{
                statements: [%Attr{expr: %TemplateExpr{delimiter: nil, lines: lines}}]
              }} = parse(hcl)

      assert [
               {:string_part, "hello "},
               %HXL.Ast.Binary{
                 left: %HXL.Ast.Literal{value: {:int, 1}},
                 operator: :+,
                 right: %HXL.Ast.Literal{value: {:int, 1}}
               },
               {:string_part, " world"}
             ] == lines
    end
  end

  describe "expr term ops" do
    test "can parse Expr with index access" do
      assert {:ok,
              %Body{
                statements: [
                  %Attr{
                    expr: %AccessOperation{
                      operation: :index_access,
                      key: _key,
                      expr: %Tuple{}
                    }
                  }
                ]
              }} = parse("a = [1,2,3][1]")
    end

    test "can parse Expr with get attr operations" do
      assert {:ok,
              %Body{
                statements: [
                  %Attr{
                    expr: %AccessOperation{
                      operation: :attr_access,
                      key: "c",
                      expr: %AccessOperation{
                        expr: %Identifier{name: "a"},
                        operation: :attr_access,
                        key: "b"
                      }
                    }
                  }
                ]
              }} = parse("a = a.b.c")
    end

    test "can parse Expr with attr splat operations" do
      assert {:ok,
              %Body{
                statements: [
                  %Attr{
                    expr: %AccessOperation{
                      expr: %HXL.Ast.Identifier{name: "a"},
                      key: [attr_access: "b"],
                      operation: :attr_splat
                    }
                  }
                ]
              }} = parse("a = a.*.b")
    end

    test "can parse Expr with multiple splat operations" do
      assert {:ok,
              %Body{
                statements: [
                  %Attr{
                    expr: %AccessOperation{
                      expr: %AccessOperation{
                        expr: %Identifier{name: "a"},
                        key: [attr_access: "b", attr_access: "c"],
                        operation: :attr_splat
                      },
                      key: %HXL.Ast.Literal{value: {:int, 1}},
                      operation: :index_access
                    }
                  }
                ]
              }} = parse("a = a.*.b.c[1]")
    end

    test "can parse Expr with full splat operations" do
      assert {:ok,
              %Body{
                statements: [
                  %Attr{
                    expr: %AccessOperation{
                      expr: %HXL.Ast.Identifier{name: "a"},
                      key: [
                        attr_access: "b",
                        attr_access: "c",
                        index_access: %HXL.Ast.Literal{value: {:int, 1}}
                      ],
                      operation: :full_splat
                    }
                  }
                ]
              }} = parse("a = a[*].b.c[1]")
    end
  end

  describe "block parser" do
    test "single identifier block" do
      hcl = """

      service {
        # Comment inside block
        a = 1
      }
      """

      {:ok, %Body{statements: [%Block{type: "service"}]}} = parse(hcl)
    end

    test "one-line blocks" do
      hcl = """
        service http { a = 1 }
        service tcp { a = 1 }
      """

      {:ok, %Body{statements: [%Block{}, %Block{}]}} = parse(hcl)
    end

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
              }} = parse("service http { a = 1 }")
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
              }} = parse("service http {\n a = 1 \n}")
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
              }} = parse(~s(service "http" { a = 1 }))
    end

    test "parses block within a block" do
      hcl = """
      service http {
        command process {
          a = 1
        }
      }
      """

      {:ok, %Body{statements: [%Block{} = b]}} = parse(hcl)
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
       }} = parse(hcl)
    end
  end
end
