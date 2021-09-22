Nonterminals

Attr
BinaryOp
ConfigFile
Expr
Literal
.

Terminals

'='
'>'
'>='
'<'
'<='
'=='
'+'
'-'
'/'
'*'
'%'
'&&'
'||'
identifier
int
decimal
bool
null

.

Rootsymbol ConfigFile.

ConfigFile -> Attr : '$1'.

Attr -> identifier '=' Expr : build_ast_node('Attr', #{name => extract_value('$1'), expr => '$3'}).
%
% Expr
%
Expr -> Literal            : build_ast_node('Literal', #{value => '$1'}).
Expr -> Expr BinaryOp Expr : build_ast_node('Binary', #{left => '$1', operator => extract_token('$2'), right => '$3'}).

%
% Binary
%
BinaryOp -> '>'  : '$1'.
BinaryOp -> '>=' : '$1'.
BinaryOp -> '<'  : '$1'.
BinaryOp -> '<=' : '$1'.
BinaryOp -> '==' : '$1'.
BinaryOp -> '+'  : '$1'.
BinaryOp -> '-'  : '$1'.
BinaryOp -> '*'  : '$1'.
BinaryOp -> '/'  : '$1'.
BinaryOp -> '%'  : '$1'.
BinaryOp -> '&&' : '$1'.
BinaryOp -> '||' : '$1'.
%
% Literal
%
Literal -> int     : extract_token_value('$1').
Literal -> decimal : {extract_token('$1'), element(1, string:to_float(extract_value('$1')))}.
Literal -> bool    : extract_token_value('$1').
Literal -> null    : {extract_token('$1'), nil}.

Erlang code.

build_ast_node(Type, Data) ->
    'Elixir.Kernel':struct(list_to_atom("Elixir.HCL.Ast." ++ atom_to_list(Type)), Data).

extract_token_value({Token, _Loc, Value}) ->
    {Token, unwrap_value(Value)}.

extract_token({Token, _Loc}) ->
    Token;
extract_token({Token, _Loc, _Value}) ->
    Token.

extract_value({_Token, _Loc, Value}) ->
    Value.

unwrap_value([Value]) ->
    Value;

unwrap_value(Value) ->
    Value.

