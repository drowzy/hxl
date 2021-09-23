Nonterminals

Arg
Args
Assign
Attr
BinaryOp
Collection
ConfigFile
Expr
For
ForCond
ForIds
ForId
ForIntro
Literal
Template
Texts
Text
UnaryOp
.

Terminals

','
'.'
'['
']'
'('
')'
'{'
'}'
':'
'!'
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
'=>'
bool
decimal
for
heredoc
identifier
in
'if'
int
null
text

.

Rootsymbol ConfigFile.

ConfigFile -> Attr : '$1'.

Attr -> identifier '=' Expr : build_ast_node('Attr', #{name => extract_value('$1'), expr => '$3'}).
%
% Expr
%
Expr -> Template                : build_ast_node('TemplateExpr', '$1').
Expr -> identifier '(' Args ')' : build_ast_node('FunctionCall', #{name => unwrap_value(extract_value('$1')), arity => length('$3'), args => '$3'}).
Expr -> identifier              : build_ast_node('Identifier', #{name => unwrap_value(extract_value('$1'))}).
Expr -> For                     : '$1'.
Expr -> Literal                 : build_ast_node('Literal', #{value => '$1'}).
Expr -> Collection              : '$1'.
Expr -> UnaryOp Expr            : build_ast_node('Unary', #{operator => extract_token('$1'), expr => '$2'}).
Expr -> Expr BinaryOp Expr      : build_ast_node('Binary', #{left => '$1', operator => extract_token('$2'), right => '$3'}).

%
% Template
%
Template -> heredoc identifier Texts identifier : #{delimiter => unwrap_value(extract_value('$2')), lines => '$3'}.

Texts -> Text Texts : ['$1' | '$2'].
Texts -> Text : ['$1'].

Text -> text : unwrap_value(extract_value('$1')).
%
% Collection
%
Collection -> '[' Args ']' : build_ast_node('Tuple', #{values => '$2'}).
Collection -> '{' Args '}' : build_ast_node('Object', #{kvs => maps:from_list('$2')}).

%
% Tuple/Object args
%
Args -> Arg ',' Args : ['$1' | '$3'].
Args -> Arg : ['$1'].
Args -> '$empty' : [].

Arg -> identifier Assign Expr : {unwrap_value(extract_value('$1')), '$3'}.
Arg -> Expr : '$1'.

Assign -> '=' : '$1'.
Assign -> ':' : '$1'.
%
% For
%
For -> '[' ForIntro Expr ForCond ']' : build_ast_node('ForExpr', maps:merge('$2', #{body => '$3', conditional => '$4', enumerable_type => for_tuple})).
For -> '{' ForIntro Expr '=>' Expr ForCond '}' : build_ast_node('ForExpr', maps:merge('$2', #{body => {'$3', '$5'}, conditional => '$6', enumerable_type => for_object})).

ForIntro -> for ForIds in Expr ':' : #{keys => '$2', enumerable => '$4'}.

ForIds -> ForId ',' ForIds : ['$1' | '$3'].
ForIds -> ForId : ['$1'].

ForId -> identifier : unwrap_value(extract_value('$1')).

ForCond -> 'if' Expr : '$2'.
ForCond -> '$empty' : nil.

%
% Unary
%
UnaryOp -> '!' : '$1'.
UnaryOp -> '-' : '$1'.
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

