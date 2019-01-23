{
module Text.GHCi.Value.Parser (
  parseValue,
  Value(..),
) where

import Text.GHCi.Value.Lexer
}

%name parseTokens value 
%expect 0
%tokentype { Token }
%token number     { NumberTok $$ }
       string     { StringTok $$ }
       character  { CharacterTok $$ }
       operator   { OperatorTok $$ }
       identifier { IdentifierTok $$ }
       '('        { OpenParen } 
       ')'        { CloseParen }
       '['        { OpenBracket }
       ']'        { CloseBracket }
       '{'        { OpenBrace }
       '}'        { CloseBrace }
       ','        { Comma }
       '='        { Equal }

%%

atom :: { Value }
    : number                           { Num   $1 }
    | string                           { Str   $1 }
    | character                        { Char  $1 }
    | '(' value comma_values ')'       { if null $3
                                           then Paren $2
                                           else Tuple ($2 : reverse $3) }
    | '[' value comma_values ']'       { List ($2 : reverse $3) }
    | error                            { Skip }

-- Reversed list of values, each value being preceded by a comma
comma_values :: { [Value] }
    : {- empty -}                      { []      }
    | comma_values ',' value           { $3 : $1 }

-- Prefix constructor application
prefix :: { Value }
    : identifier prefix_apps           { Prefix $1 (reverse $2) }
    | identifier '{' fields '}'        { Record $1 (reverse $3) }
    | atom                             { $1 }

-- Reversed arguments to a prefix constructor
prefix_apps :: { [Value] }
    : {- empty -}                      { []      }
    | prefix_apps atom                 { $2 : $1 }

-- A record field
field :: { (Id, Value) }
    : identifier       '=' value       { ($1,               $3) }
    | '(' operator ')' '=' value       { ("(" <> $2 <> ")", $5) }

-- Non-empty list of reversed record fields
fields :: { [(Id, Value)] }
    : field                            { [$1] }
    | fields ',' field                 { $3 : $1 }

-- Infix constructor application
infixes :: { Value }
    : prefix infixes_sufs              { if null $2
                                          then $1
                                          else Infix $1 (reverse $2) }

-- Reversed list of operator suffixes
infixes_sufs :: { [(Op, Value)] }
    : {- empty -}                      { []            }
    | infixes_sufs operator prefix     { ($2, $3) : $1 }

-- Entry point
value :: { Value }
    : infixes                          { $1 }

{
-- | Throws an exception, not particularly helpful
happyError :: [Token] -> a
happyError _ = error "parse error"

-- | A @conid@ or @varid@ (possibly ending in hashes, to account for @MagicHash@)
type Id = String

-- | A @conop@ or @varop@
type Op = String

-- | A very simple representation of the output of 'Show'
data Value
  = Prefix Id [Value]
  | Infix Value [(Op, Value)] -- ^ INV: list is non-empty
  | Record Id [(Id, Value)] -- ^ INV: list is non-empty
  | Tuple [Value]
  | List [Value]
  | Num String  -- ^ integer or floating point
  | Char String -- ^ character
  | Str String  -- ^ string
  | Paren Value
  | Skip        -- ^ there was some error and we are trying to pretend it never happened
  deriving Show

-- | Parse a value from a 'String'. Will throw an exception for inputs that
-- could not be parsed
parseValue :: String -> Value
parseValue = parseTokens . lexTokens
}
