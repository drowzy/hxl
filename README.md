# HCL

An Elixir implementation of [HCL](https://github.com/hashicorp/hcl)

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
- [ ] One-line blocks
- [ ] Expressions
  - [ ] [Expr term](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#expression-terms)
    - [x] Literal Value
    - [x] Collection Value
    - [x] Template Expr
    - [x] Variable Expr
    - [x] Function Call
    - [x] For Expr
    - [x] ExprTerm Index
    - [x] ExprTerm GetAttr
    - [x] ExprTerm Splat
    - [x] "(" Expression ")"
  - [ ] Operation
  - [ ] Conditional
