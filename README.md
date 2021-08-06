# HCL

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hcl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hcl, "~> 0.1.0"}
  ]
end
```

## HCL Syntax Specification

### Lexical Elements
- [ ] [Comments](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#comments-and-whitespace)
- [x] [Identifiers](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#identifiers)
- [ ] [Operators & delimiters](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#operators-and-delimiters)
- [x] [Numeric literals](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#numeric-literals)

### Structural Elements

- [x] Body
- [x] Attributes
- [x] Blocks
- [ ] Online blocks
- [ ] Expressions
  - [ ] [Expr term](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#expression-terms)
    - [x] Literal Value
    - [x] Collection Value
    - [x] Template Expr
    - [ ] Variable Expr
    - [ ] Function Call
    - [ ] For Expr
    - [ ] ExprTerm Index
    - [ ] ExprTerm GetAttr
    - [ ] ExprTerm Splat
    - [ ] "(" Expression ")"
  - [ ] Operation
  - [ ] Conditional



Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/hcl](https://hexdocs.pm/hcl).
