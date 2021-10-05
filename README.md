# HXL

---

![CI](https://github.com/drowzy/hxl/actions/workflows/ci.yml/badge.svg)
[![Hex.pm Version](https://img.shields.io/hexpm/v/hxl.svg?style=flat-square)](https://hex.pm/packages/hxl)

An Elixir implementation of [HCL](https://github.com/hashicorp/hcl)

## Features

* Decode from string or file
* Aims to be fully compliant with the [HCL](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md) specification
* Function & variables support during evaluation

## Example Usage

```elixir
hcl = """
resource "upcloud_server" "server1" {
  hostname = "terraform.example.com"

  zone = "nl-ams1"

  plan = "1xCPU-1GB"

  template {
    size = 25
    storage = "01000000-0000-4000-8000-000030200200"
  }

  network_interface {
    type = "public"
  }

  login {
    user = "root"
    keys = [
      "ssh-rsa public key",
    ]
    create_password = true
    password_delivery = "email"
  }

  connection {
    host        = "127.0.0.2"
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/rsa_private_key")
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Hello world!'"
    ]
  }
}
"""

{:ok, config_file} = HXL.decode(hcl, functions: %{"file" => &File.read/1})
```

### From file

```elixir
{:ok, config_file} = HXL.decode_file("/path/to/file")
```

### As ast

```elixir
hcl = """
service "http" {
  a = 1
  b = 2
}
"""

{:ok %HXL.Body{}} = HXL.decode_as_ast(hcl)

```

## Installation

Add `hxl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hxl, "~> 0.1.0"}
  ]
end
```

## HCL Syntax Specification

### [Lexical Elements](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#lexical-elements)

- [x] Comments
- [x] Identifiers
- [x] Operators & delimiters
- [x] Numeric literals

### [Structural Language](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#structural-elements)

- [x] Body
- [x] Attributes
- [x] Blocks
- [x] One-line blocks

### [Expression language](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#expressions)

- [x] Expressions
  - [x] Expr term
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
  - [x] Operation
  - [x] Conditional

### [Template Language](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#templates)
- [] TemplateLiteral
- [] TemplateInterpolation
- [] TemplateDirective

### Representations
 - [x] HCL Native syntax
 - [ ] JSON
