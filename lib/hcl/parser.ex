defmodule HCL.Parser do
  import NimbleParsec

  alias HCL.Ast.{
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

  ########################################
  #
  # ## Lexical
  whitespace = ascii_string([?\s, ?\n], min: 1)
  blankspace = ignore(ascii_string([?\s], min: 1))
  newline = string("\n")
  eq = string("=")
  and_ = string("&&")
  or_ = string("||")
  not_ = string("!")
  sum = string("+")
  diff = string("-")
  product = string("*")
  quotient = string("/")
  remainder = string("%")
  eqeq = string("==")
  not_eq = string("!=")
  lt = string("<")
  gt = string(">")
  lt_eq = string("<=")
  gt_eq = string(">=")
  dot = string(".")
  comma = string(",")
  colon = string(":")
  wildcard = string("*")
  identifier = ascii_string([?a..?z, ?A..?Z, ?-, ?_], min: 1)
  open_brace = string("{")
  close_brace = string("}")
  open_brack = string("[")
  close_brack = string("]")
  open_parens = string("(")
  close_parens = string(")")
  fat_arrow = string("=>")
  assign = choice([eq, colon])

  ###
  # ## Comments
  #

  line_comment =
    choice([
      ignore(string("//")),
      ignore(string("#"))
    ])
    |> optional(blankspace)
    |> utf8_string([not: ?\n], min: 1)
    |> ignore(newline)
    |> tag(:comment)
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__comment__, line_comment)
  ########################################
  #
  # ## Expr
  #
  # ### Literal Value

  #
  # NumericLit = decimal+ ("." decimal+)? (expmark decimal+)?;
  # decimal    = '0' .. '9';
  # expmark    = ('e' | 'E') ("+" | "-")?;
  #

  expmark = ascii_string([?e, ?E, ?+, ?-], max: 1)
  int = integer(min: 1)

  numeric_lit =
    int
    |> optional(ignore(dot) |> concat(int))
    |> optional(expmark |> concat(int))
    |> post_traverse(:tag_and_emit_numeric_lit)

  defp tag_and_emit_numeric_lit(_rest, [int_value], ctx, _line, _offset) do
    {[{:int, int_value}], ctx}
  end

  defp tag_and_emit_numeric_lit(_rest, [frac, base], ctx, _line, _offset) do
    {value, _} = Float.parse("#{base}.#{frac}")
    {[{:decimal, value}], ctx}
  end

  defp tag_and_emit_numeric_lit(_rest, [_pow, exp, _base] = args, ctx, _line, _offset)
       when is_binary(exp) do
    {[{:exp, args}], ctx}
  end

  defp tag_and_emit_numeric_lit(_rest, [_pow, exp, _frac, _base] = args, ctx, _line, _offset)
       when is_binary(exp) do
    {[{:float_exp, args}], ctx}
  end

  #
  #  StringLit = 
  #
  # https://github.com/dashbitco/nimble_parsec/blob/master/examples/simple_language.exs#L17
  string_lit =
    ignore(ascii_char([?"]))
    |> repeat(
      lookahead_not(ascii_char([?"]))
      |> choice([
        ~S(\") |> string() |> replace(?"),
        utf8_char([])
      ])
    )
    |> ignore(ascii_char([?"]))
    |> reduce({List, :to_string, []})

  #
  # null
  #
  null = string("null") |> replace(nil) |> unwrap_and_tag(:null)

  #
  # true | false
  #
  bool =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])
    |> unwrap_and_tag(:bool)

  #
  # LiteralValue = (
  #   NumericLit |
  #   "true" |
  #   "false" |
  #   "null"
  # );
  #
  literal_value =
    choice([
      numeric_lit,
      bool,
      null
    ])
    |> unwrap_and_tag(:literal)
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__literal_value__, literal_value)

  # ### CollectionValue

  arg = parsec(:expr) |> ignore(optional(comma)) |> ignore(optional(whitespace))

  #
  # Tuple = "[" ((Expression ("," Expression)* ","?)?) "]";
  #
  tuple =
    ignore(open_brack)
    |> ignore(optional(whitespace))
    |> repeat(arg)
    |> ignore(optional(whitespace))
    |> ignore(close_brack)
    |> tag(:tuple)

  #
  # objectelem = (Identifier | Expression) ("=" | ":") Expression;
  #
  object_elem =
    identifier
    |> ignore(optional(whitespace))
    |> ignore(assign)
    |> optional(blankspace)
    |> parsec(:expr)
    |> ignore(optional(comma))
    |> ignore(optional(whitespace))

  #
  # object = "{" ((objectelem ("," objectelem)* ","?)?) "}";
  #
  object =
    ignore(open_brace)
    |> optional(blankspace)
    |> repeat(object_elem)
    |> ignore(close_brace)
    |> tag(:object)

  defcombinatorp(:__object__, object)
  defcombinatorp(:__tuple__, tuple)

  #
  # CollectionValue = tuple | object;
  #
  collection_value =
    choice([
      parsec(:__tuple__),
      parsec(:__object__)
    ])
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__collection_value__, collection_value)

  # ### Template Expr
  # TODO If a heredoc template is introduced with the <<- symbol, any literal string at the start of each line is analyzed to find the minimum number of leading spaces, and then that number of prefix spaces is removed from all line-leading literal strings. The final closing marker may also have an arbitrary number of spaces preceding it on its line.
  quoted_template = string_lit |> tag(:qouted_template)

  heredoc_line = utf8_string([not: ?\n], min: 1) |> ignore(newline)

  heredoc_template =
    choice([ignore(string("<<-")), ignore(string("<<"))])
    |> concat(identifier)
    |> ignore(whitespace)
    |> repeat(heredoc_line)
    |> post_traverse(:validate_heredoc_matching_terminator)
    |> tag(:heredoc)

  defcombinatorp(:__qouted_template__, quoted_template)
  defcombinatorp(:__heredoc_template__, heredoc_template)

  template_expr =
    choice([
      parsec(:__qouted_template__),
      parsec(:__heredoc_template__)
    ])
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__template_expr__, template_expr)

  defp validate_heredoc_matching_terminator(_rest, [close_id | content], ctx, _line, _offset) do
    [open_id | _] = Enum.reverse(content)

    if open_id == close_id do
      {content, ctx}
    else
      {:error, "Expected identifier: #{open_id} to be closed. Got: #{close_id}"}
    end
  end

  # ### Variable Expr

  variable_expr =
    identifier
    |> tag(:identifier)
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__variable_expr__, variable_expr)

  # ### Function call

  arguments = optional(repeat(arg))

  function_call =
    identifier
    |> ignore(open_parens)
    |> concat(arguments)
    |> ignore(close_parens)
    |> tag(:function_call)
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__function_call__, function_call)

  # ### for Expression

  for_cond = ignore(string("if")) |> ignore(whitespace) |> parsec(:expr)

  for_identifier =
    identifier
    |> ignore(optional(comma))
    |> ignore(optional(whitespace))
    |> unwrap_and_tag(:identifier)

  for_intro =
    ignore(string("for"))
    |> ignore(whitespace)
    |> repeat(lookahead_not(string("in")) |> parsec(:__for_identifier__))
    |> ignore(optional(whitespace))
    |> ignore(string("in"))
    |> ignore(whitespace)
    |> parsec(:expr)
    |> optional(ignore(whitespace))
    |> ignore(colon)

  defcombinatorp(:__for_identifier__, for_identifier)
  defcombinatorp(:__for_cond__, for_cond)
  defcombinatorp(:__for_intro__, for_intro)

  for_tuple =
    ignore(open_brack)
    |> optional(blankspace)
    |> parsec(:__for_intro__)
    |> ignore(whitespace)
    |> parsec(:expr)
    |> optional(ignore(whitespace) |> parsec(:__for_cond__))
    |> ignore(close_brack)
    |> tag(:for_tuple)

  defcombinatorp(:__for_tuple, for_tuple)

  for_object =
    ignore(open_brace)
    |> optional(blankspace)
    |> parsec(:__for_intro__)
    |> ignore(whitespace)
    |> parsec(:expr)
    |> ignore(whitespace)
    |> ignore(fat_arrow)
    |> ignore(whitespace)
    |> parsec(:expr)
    |> optional(ignore(whitespace) |> parsec(:__for_cond__))
    |> ignore(close_brace)
    |> tag(:for_object)

  defcombinatorp(:__for_tuple__, for_tuple)
  defcombinatorp(:__for_object__, for_object)

  for_expr =
    choice([
      parsec(:__for_tuple__),
      parsec(:__for_object__)
    ])
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__for_expr__, for_expr)

  # ### Expr term operations

  # #### Index
  #
  # [1,2,3][1]
  #
  index =
    ignore(open_brack)
    |> optional(blankspace)
    |> lookahead_not(wildcard)
    |> parsec(:expr)
    |> optional(blankspace)
    |> ignore(close_brack)
    |> unwrap_and_tag(:index_access)

  get_attr = times(ignore(dot) |> concat(identifier), min: 1) |> tag(:attr_access)

  defcombinatorp(:__get_attr__, get_attr)
  defcombinatorp(:__index__, index)

  # #### Splat
  #
  # tuple.*.foo.bar[0] == for[v in tuple: v.foo.bar][0]
  #
  attr_splat =
    ignore(dot)
    |> ignore(wildcard)
    |> parsec(:__get_attr__)
    |> unwrap_and_tag(:attr_splat)

  defcombinatorp(:__attr_splat__, attr_splat)

  #
  # tuple[*].foo.bar[0] == for[v in tuple: v.foo.bar[0]]
  #
  full_splat =
    ignore(open_brack)
    |> optional(blankspace)
    |> ignore(wildcard)
    |> optional(blankspace)
    |> ignore(close_brack)
    |> repeat(
      choice([
        parsec(:__get_attr__),
        parsec(:__index__)
      ])
    )
    |> tag(:full_splat)

  defcombinatorp(:__full_splat__, full_splat)

  splat =
    choice([
      parsec(:__attr_splat__),
      parsec(:__full_splat__)
    ])

  defcombinatorp(:__splat__, splat)

  # ### Expr Term
  #
  # ExprTerm = (
  #   LiteralValue     |
  #   CollectionValue  |
  #   TemplateExpr     |
  #   VariableExpr     |
  #   FunctionCall     |
  #   ForExpr          |
  #   ExprTerm Index   |
  #   ExprTerm GetAttr |
  #   ExprTerm Splat   |
  #   "(" Expression ")"
  # );
  #
  expr_term_op =
    times(
      choice([
        parsec(:__index__),
        parsec(:__splat__),
        parsec(:__get_attr__)
      ]),
      min: 1
    )

  nested_expr =
    ignore(open_parens)
    |> parsec(:expr)
    |> ignore(close_parens)

  expr_term =
    choice([
      parsec(:__literal_value__),
      parsec(:__collection_value__),
      parsec(:__for_expr__),
      parsec(:__template_expr__),
      parsec(:__function_call__),
      parsec(:__variable_expr__),
      nested_expr
    ])
    |> optional(expr_term_op)
    |> tag(:expr_term)
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__expr_term__, expr_term)
  # ### Operations

  compare_op =
    choice([
      eqeq,
      not_eq,
      lt_eq,
      gt_eq,
      lt,
      gt
    ])

  arithmetic_op =
    choice([
      sum,
      diff,
      product,
      quotient,
      remainder
    ])

  logic_op = choice([and_, or_])

  binary_operator = choice([compare_op, arithmetic_op, logic_op])

  binary_op =
    expr_term
    |> optional(ignore(whitespace))
    |> parsec(:__binary_operator__)
    |> optional(ignore(whitespace))
    |> parsec(:__expr_term__)
    |> tag(:binary)

  unary_op = choice([diff, not_]) |> parsec(:__expr_term__) |> tag(:unary)

  defcombinatorp(:__binary_operator__, binary_operator)
  defcombinatorp(:__binary_op__, binary_op)
  defcombinatorp(:__unary_op__, unary_op)

  # operation = choice([unary_op, binary_op]) |> post_traverse(:ast_node_from_tokens)
  operation =
    choice([
      parsec(:__unary_op__),
      parsec(:__binary_op__)
    ])
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__operation__, operation)

  # Conditional
  _conditional =
    parsec(:expr)
    |> concat(blankspace)
    |> string("?")
    |> concat(blankspace)
    |> parsec(:expr)
    |> concat(blankspace)
    |> string(":")
    |> concat(blankspace)
    |> parsec(:expr)

  #
  # Expression = (ExprTerm | Operation | Conditional);
  #
  expr =
    choice([
      parsec(:__operation__),
      parsec(:__expr_term__)
    ])

  ##########################
  # ## Attribute
  #
  # Attribute = Identifier "=" Expression Newline;
  #
  attr =
    identifier
    |> optional(blankspace)
    |> ignore(eq)
    |> optional(blankspace)
    |> parsec(:expr)
    |> tag(:attr)
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__attr__, attr)
  ##########################
  # ## Block
  #
  # Block = Identifier (StringLit|Identifier)* "{" Newline Body "}" Newline;
  #
  block =
    optional(blankspace)
    |> concat(identifier)
    |> concat(blankspace)
    |> repeat(choice([identifier, string_lit]) |> optional(blankspace))
    |> optional(blankspace)
    |> ignore(open_brace)
    |> repeat(ignore(whitespace))
    |> parsec(:body)
    |> ignore(close_brace)
    |> tag(:block)
    |> post_traverse(:ast_node_from_tokens)

  defcombinatorp(:__block__, block)
  ##########################
  # ## body
  #
  # Body = (Attribute | Block | OneLineBlock)*;
  #
  body =
    repeat(
      choice([
        parsec(:__attr__),
        parsec(:__comment__),
        parsec(:__block__)
      ])
      |> ignore(optional(whitespace))
    )
    |> tag(:body)
    |> post_traverse(:ast_node_from_tokens)

  if Mix.env() == :test do
    defparsec(:parse_literal, literal_value)
    defparsec(:parse_collection, collection_value)
    defparsec(:parse_template, template_expr)
    defparsec(:parse_function, function_call)
    defparsec(:parse_for, for_expr)
    defparsec(:parse_op, operation)
    defparsec(:parse_expr, expr)
    defparsec(:parse_attr, attr)
  end

  defcombinatorp(:expr, expr)
  defcombinatorp(:body, body)

  @spec parse(binary()) ::
          {:ok, HCL.Ast.Body.t()}
          | {:error, binary(), {pos_integer(), pos_integer()}, pos_integer()}
  def parse(input) do
    case do_parse(input) do
      {:ok, [ast], "", _, _, _} ->
        {:ok, ast}

      {:ok, _parsed, rest, _ctx, {line, line_offset}, byte_offset} ->
        {:error, rest, {line, line_offset}, byte_offset}

      err ->
        err
    end
  end

  @spec parse!(binary()) :: HCL.Ast.Body.t()
  def parse!(input) do
    case parse(input) do
      {:ok, body} -> body
      _ -> raise "parser err"
    end
  end

  @spec do_parse(binary()) ::
          {:ok, [term()], binary(), map(), {pos_integer(), pos_integer()}, pos_integer()}
  defparsec(:do_parse, parsec(:body) |> ignore(optional(whitespace)) |> eos())

  defp ast_node_from_tokens(_rest, [literal: literal], ctx, _line, _offset) do
    {[%Literal{value: literal}], ctx}
  end

  defp ast_node_from_tokens(_rest, [heredoc: [delimiter | lines]], ctx, _line, _offset) do
    {[%TemplateExpr{delimiter: delimiter, lines: lines}], ctx}
  end

  defp ast_node_from_tokens(_rest, [qouted_template: lines], ctx, _line, _offset) do
    {[%TemplateExpr{lines: lines}], ctx}
  end

  defp ast_node_from_tokens(_rest, [tuple: values], ctx, _line, _offset) do
    {[%Tuple{values: values}], ctx}
  end

  defp ast_node_from_tokens(_rest, [object: kvs], ctx, _line, _offset) do
    kvs =
      kvs
      |> Enum.chunk_every(2)
      |> Map.new(fn [k, v] -> {k, v} end)

    {[%Object{kvs: kvs}], ctx}
  end

  defp ast_node_from_tokens(_rest, [function_call: [name]], ctx, _line, _offset) do
    {[%FunctionCall{name: name, arity: 0, args: []}], ctx}
  end

  defp ast_node_from_tokens(_rest, [function_call: [name | args]], ctx, _line, _offset) do
    call = %FunctionCall{
      name: name,
      arity: length(args),
      args: args
    }

    {[call], ctx}
  end

  defp ast_node_from_tokens(_rest, [identifier: [name]], ctx, _line, _offset) do
    {[%Identifier{name: name}], ctx}
  end

  defp ast_node_from_tokens(_rest, [{for_type, args}], ctx, _line, _offset)
       when for_type in [:for_tuple, :for_object] do
    {ids, rest} = Enum.split_while(args, &identifier?/1)
    {enumerable, body, conditional} = post_process_for_body(for_type, rest)

    for_expr = %ForExpr{
      keys: post_process_for_ids(ids),
      enumerable: enumerable,
      enumerable_type: for_type,
      body: body,
      conditional: conditional
    }

    {[for_expr], ctx}
  end

  defp ast_node_from_tokens(_rest, [binary: [left, op, right]], ctx, _line, _offset) do
    {[%Binary{operator: String.to_existing_atom(op), left: left, right: right}], ctx}
  end

  defp ast_node_from_tokens(_rest, [unary: [op, expr]], ctx, _line, _offset) do
    {[%Unary{operator: String.to_existing_atom(op), expr: expr}], ctx}
  end

  defp ast_node_from_tokens(_rest, [expr_term: [expr]], ctx, _line, _offset) do
    {[expr], ctx}
  end

  defp ast_node_from_tokens(_rest, [expr_term: expr_ops], ctx, _line, _offset) do
    ops_tree =
      expr_ops
      |> Enum.reverse()
      |> build_expr_op_tree()

    {[ops_tree], ctx}
  end

  defp ast_node_from_tokens(_rest, [attr: [name, expr]], ctx, _line, _offset) do
    {[%Attr{name: name, expr: expr}], ctx}
  end

  defp ast_node_from_tokens(_rest, [comment: lines], ctx, _line, _offset) do
    {[%Comment{lines: lines, type: :line}], ctx}
  end

  defp ast_node_from_tokens(_rest, [block: [type | args]], ctx, _line, _offset) do
    {labels, [body]} =
      Enum.split_while(args, fn
        %Body{} -> false
        _ -> true
      end)

    block = %Block{
      type: type,
      labels: labels,
      body: body
    }

    {[block], ctx}
  end

  defp ast_node_from_tokens(_rest, [body: stmts], ctx, _line, _offset) do
    {[%Body{statements: stmts}], ctx}
  end

  defp build_expr_op_tree([op, expr]) do
    %AccessOperation{expr: expr, operation: op}
  end

  defp build_expr_op_tree([op | expr_ops]) do
    %AccessOperation{expr: build_expr_op_tree(expr_ops), operation: op}
  end

  defp post_process_for_ids(ids) do
    for {:identifier, id} <- ids, do: id
  end

  defp post_process_for_body(:for_tuple, [enum, body]) do
    {enum, body, nil}
  end

  defp post_process_for_body(:for_tuple, [enum, body, conditional]) do
    {enum, body, conditional}
  end

  defp post_process_for_body(:for_object, [enum, key_expr, value_expr]) do
    {enum, {key_expr, value_expr}, nil}
  end

  defp post_process_for_body(:for_object, [enum, key_expr, value_expr, conditional]) do
    {enum, {key_expr, value_expr}, conditional}
  end

  defp identifier?({:identifier, _}), do: true
  defp identifier?(_), do: false
end
