Nonterminals

Access
Arg
Args
Assign
Attr
AttrSplat
BinaryOp
Block
Body
Collection
Comment
ConfigFile
Definition
Definitions
Expr
For
ForCond
ForIds
ForId
ForIntro
FullSplat
GetAttr
GetAttrs
Index
Literal
Label
Labels
Splat
SplatAccessor
SplatAccessors
StringLit
StringLits
Template
TemplateDirective
TemplateLang
TemplateInterpolation
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
'?'
'='
'>'
'>='
'<'
'<='
'!='
'=='
'+'
'-'
'/'
'*'
'%'
'$'
'&&'
'||'
'=>'
'%{'
'${'
decimal
'else'
endif
false
for
heredoc
identifier
in
'if'
int
line_comment
null
string_part
text
true

.

Rootsymbol ConfigFile.

%
% ConfigFile = Body;
%
ConfigFile -> Body : build_ast_node('Body', #{statements => '$1'}).

%
% Body = (Attribute | Block | OneLineBlock)*;
%
Body -> Definitions : '$1'.
Definitions -> Definition Definitions : ['$1' | '$2'].
Definitions -> '$empty' : [] .
Definition -> Attr : '$1'.
Definition -> Block : '$1'.
Definition -> Comment : '$1'.

%
% Block = Identifier (StringLit|Identifier)* "{" Newline Body "}" Newline;
% OneLineBlock = Identifier (StringLit|Identifier)* "{" (Identifier "=" Expression)? "}" Newline;
%
Block -> identifier Labels '{' ConfigFile '}': build_ast_node('Block', #{type => unwrap_value(extract_value('$1')), labels => '$2', body => '$4' }).

Labels -> Label Labels : ['$1' | '$2'].
Labels -> '$empty' : [].

Label -> identifier : unwrap_value(extract_value('$1')).
Label -> string_part : unwrap_value(extract_value('$1')).

%
% Attribute = Identifier "=" Expression Newline;
%
Attr -> identifier '=' Expr : build_ast_node('Attr', #{name => unwrap_value(extract_value('$1')), expr => '$3'}).

%
% Comment
%
Comment -> line_comment : build_ast_node('Comment', #{type => line, lines => extract_value('$1')}).


%
% Expression = (
%   ExprTerm |
%   Operation |
%   Conditional
% );
%
% ExprTerm = (
%   LiteralValue |
%   CollectionValue |
%   TemplateExpr |
%   VariableExpr |
%   FunctionCall |
%   ForExpr |
%   ExprTerm Index |
%   ExprTerm GetAttr |
%   ExprTerm Splat |
%   "(" Expression ")"
%  );
%
Expr -> Template                : build_ast_node('TemplateExpr', '$1').
Expr -> identifier '(' Args ')' : build_ast_node('FunctionCall', #{name => unwrap_value(extract_value('$1')), arity => length('$3'), args => '$3'}).
Expr -> identifier              : build_ast_node('Identifier', #{name => unwrap_value(extract_value('$1'))}).
Expr -> For                     : '$1'.
Expr -> Literal                 : build_ast_node('Literal', #{value => '$1'}).
Expr -> Collection              : '$1'.
Expr -> UnaryOp Expr            : build_ast_node('Unary', #{operator => extract_token('$1'), expr => '$2'}).
Expr -> Expr BinaryOp Expr      : build_ast_node('Binary', #{left => '$1', operator => extract_token('$2'), right => '$3'}).
Expr -> Expr Access : build_ast_node('AccessOperation', #{expr => '$1', operation => element(1, '$2'), key => element(2, '$2')}).
Expr -> Expr '?' Expr ':' Expr : build_ast_node('Conditional', #{predicate => '$1', then => '$3', 'else' => '$5'}).
Expr -> '(' Expr ')': '$2'.

%
% Access
% Index = "[" Expression "]";
% GetAttr = "." Identifier;
% Splat = attrSplat | fullSplat;
% attrSplat = "." "*" GetAttr*;
% fullSplat = "[" "*" "]" (GetAttr | Index)*;
%
Access -> Index   : '$1' .
Access -> GetAttr : '$1' .
Access -> Splat   : '$1' .

Index -> '[' Arg ']' : {index_access, '$2'}.

GetAttrs -> GetAttr GetAttrs : ['$1' | '$2'].
GetAttrs -> '$empty' : [].
GetAttr -> '.' identifier : {attr_access, unwrap_value(extract_value('$2'))}.

%
% Splat
%
SplatAccessors -> SplatAccessor SplatAccessors : ['$1' | '$2'].
SplatAccessors -> '$empty': [].
SplatAccessor -> Index : '$1'.
SplatAccessor -> GetAttr : '$1'.
Splat -> AttrSplat : '$1'.
Splat -> FullSplat : '$1'.
AttrSplat -> '.' '*' GetAttrs : {attr_splat, '$3'}.
FullSplat -> '[' '*' ']' SplatAccessors : {full_splat, '$4'}.

%
% TemplateExpr = quotedTemplate | heredocTemplate;
% quotedTemplate = StringLit;
% heredocTemplate = (
%   ("<<" | "<<-") Identifier Newline
%   (content)
%   Identifier Newline
% );
%
% StringLit = '"' (content) '"';
%
Template -> heredoc identifier Texts identifier : #{delimiter => unwrap_value(extract_value('$2')), lines => '$3'}.
Template -> StringLits : #{delimiter => nil, lines => '$1'}.

StringLits -> StringLit StringLits : ['$1' | '$2'].
StringLits -> StringLit : ['$1'].
StringLit -> string_part : extract_token_value('$1').
StringLit -> TemplateLang : '$1'.

TemplateLang -> TemplateInterpolation : '$1'.
TemplateLang -> TemplateDirective : '$1'.

TemplateInterpolation -> '${' Expr '}' : '$2'.
TemplateDirective -> '%{' 'if' Expr '}' StringLit '%{' endif '}' : {'$3', '$5'} .
TemplateDirective -> '%{' 'if' Expr '}' StringLit '%{' 'else' '}' StringLit '%{' endif '}' : {'$3', '$5', '$9'} .

Texts -> Text Texts : ['$1' | '$2'].
Texts -> Text : ['$1'].

Text -> text : unwrap_value(extract_value('$1')).

%
% CollectionValue = tuple | object;
% tuple = "[" (
%         (Expression ("," Expression)* ","?)?
%          ) "]";
% object = "{" (
%         (objectelem ("," objectelem)* ","?)?
%           ) "}";
% objectelem = (Identifier | Expression) ("=" | ":") Expression;
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
% ForExpr = forTupleExpr | forObjectExpr;
% forTupleExpr = "[" forIntro Expression forCond? "]";
% forObjectExpr = "{" forIntro Expression "=>" Expression "..."? forCond? "}";
% forIntro = "for" Identifier ("," Identifier)? "in" Expression ":";
% forCond = "if" Expression;
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
%
% Operation = unaryOp | binaryOp;
% unaryOp = ("-" | "!") ExprTerm;
% binaryOp = ExprTerm binaryOperator ExprTerm;
% binaryOperator = compareOperator | arithmeticOperator | logicOperator;
% compareOperator = "==" | "!=" | "<" | ">" | "<=" | ">=";
% arithmeticOperator = "+" | "-" | "*" | "/" | "%";
% logicOperator = "&&" | "||" | "!";
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
BinaryOp -> '!=' : '$1'.
BinaryOp -> '+'  : '$1'.
BinaryOp -> '-'  : '$1'.
BinaryOp -> '*'  : '$1'.
BinaryOp -> '/'  : '$1'.
BinaryOp -> '%'  : {'rem', element(2, '$1')}.
BinaryOp -> '&&' : '$1'.
BinaryOp -> '||' : '$1'.
%
% LiteralValue = (
%   NumericLit |
%   "true" |
%   "false" |
%   "null"
% );
%
Literal -> int     : extract_token_value('$1').
Literal -> decimal : {extract_token('$1'), element(1, string:to_float(extract_value('$1')))}.
Literal -> true    : {bool, true}.
Literal -> false   : {bool, false}.
Literal -> null    : {null, nil}.

Erlang code.

build_ast_node(Type, Data) ->
    'Elixir.Kernel':struct(list_to_atom("Elixir.HXL.Ast." ++ atom_to_list(Type)), Data).

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

