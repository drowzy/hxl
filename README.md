# HCL

---

![CI](https://github.com/drowzy/hcl/actions/workflows/ci.yml/badge.svg)

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
    host        = self.network_interface[0].ip_address
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

{:ok, config_file} = HCL.decode(hcl, functions: %{"file" => &File.read/1})
```

### From file

```elixir
{:ok, config_file} = HCL.decode_file("/path/to/file")
```
### As ast

## HCL Syntax Specification

### Lexical Elements
- [x] [Comments](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#comments-and-whitespace)
- [x] [Identifiers](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#identifiers)
- [ ] [Operators & delimiters](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#operators-and-delimiters)
- [x] [Numeric literals](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#numeric-literals)

### Structural Elements

- [x] Body
- [x] Attributes
- [x] Blocks
- [x] One-line blocks
- [x] Expressions
  - [x] [Expr term](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md#expression-terms)
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

### Represenations
 - [ ] HCL Native syntax
 - [ ] JSON
