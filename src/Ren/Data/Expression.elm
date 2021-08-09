module Ren.Data.Expression exposing
    ( Expression(..), Accessor, Identifier, Operator, Pattern, Literal
    , local, scoped, operator, field
    , array, boolean, number, int, object, string
    , operatorFromName, operatorToName, operatorFromSymbol, operatorToSymbol
    , referencesName, referencesScopedName, referencesModule
    , fromJSON, decoder
    , fromSource, parser
    )

{-|


## Table of Contents

  - Types
      - [Expression](#Expression)
      - [Accessor](#Accessor)
      - [Identifier](#Identifier)
      - [Literal](#Literal)
      - [Operator](#Operator)
      - [Pattern](#Pattern)
  - Helpers
      - Identifier Helpers
          - [local](#local)
          - [scoped](#scoped)
          - [operator](#operator)
          - [field](#field)
      - Literal Helpers
          - [array](#array)
          - [boolean](#boolean)
          - [number](#number)
          - [int](#int)
          - [object](#object)
          - [string](#string)
      - Operator Helpers
          - [operatorFromName](#operatorFromName)
          - [operatorToName](#operatorToName)
          - [operatorFromSymbol](#operatorFromSymbol)
          - [operatorToSymbol](#operatorToSymbol)
      - Queries
          - [referencesName](#referencesName)
          - [referencesScopedName](#referencesScopedName)
          - [refernecesModule](#referencesModule)
  - Parsing
      - [fromJSON](#fromJSON)
      - [decoder](#decoder)
      - [fromSource](#fromSource)
      - [parser](#parser)

---


## Types

@docs Expression, Accessor, Identifier, Operator, Pattern, Literal

---


## Helpers


### Identifier Helpers

@docs local, scoped, operator, field


### Literal Helpers

@docs array, boolean, number, int, object, string


### Operator Helpers

@docs operatorFromName, operatorToName, operatorFromSymbol, operatorToSymbol


### Queries

@docs referencesName, referencesScopedName, referencesModule

---


## Parsing

@docs fromJSON, decoder
@docs fromSource, parser

-}

-- IMPORTS ---------------------------------------------------------------------

import Dict
import Json.Decode exposing (Decoder)
import Json.Decode.Extra
import Parser exposing ((|.), (|=), Parser)
import Parser.Extra
import Pratt
import Ren.Data.Expression.Accessor as Accessor
import Ren.Data.Expression.Identifier as Identifier exposing (Identifier)
import Ren.Data.Expression.Literal as Literal
import Ren.Data.Expression.Operator as Operator
import Ren.Data.Expression.Pattern as Pattern



-- TYPES -----------------------------------------------------------------------


{-| -}
type Expression
    = Access Expression (List Accessor)
    | Application Expression (List Expression)
    | Conditional Expression Expression Expression
    | Identifier Identifier
    | Infix Operator Expression Expression
    | Lambda (List Pattern) Expression
    | Literal Literal
    | Match Expression (List ( Pattern, Maybe Expression, Expression ))
    | SubExpression Expression


{-| An `Accessor` is what we use to access fields or indecies of an object or
array. They can be fixed as in:

    foo.bar

Or they can be computed:

    foo [ "baz" ]

In fact, array indexing is just a computed accessor with a `Number` literal as
the computed expression:

    arr [ 0 ]

-}
type alias Accessor =
    Accessor.Accessor Expression


{-| An `Identifier` is what we use when we need to refer to something by its name.
Lower case names are `Local` identifiers:

    foo

But we can also have scoped identifiers if we import another module and give it
a name

    Foo.bar

We also have some more interesting types of identifiers. **Operators** can be
used as identifiers!

    (+) 1 2

And so can object fields:

    .foo obj

-}
type alias Identifier =
    Identifier.Identifier


{-| We support the typical literals that you might expect. Like JavaScript we have
a single Number literal to cover both Integers and Floats, rather than making them
distinct:

    1

    0.99

There are boolean literals:

    true

    false

String literals can use either single or double quotes:

    "Hello World!"
    'Superior quotes here'

Array literals correspond directly to JavaScript arrays (unlike other languages
that may compile arrays/lists into something else):

    [ 1, 'hello', false ]

As do object literals:

    { foo: fun x => ...
    , bar: 0.123456789
    }

-}
type alias Literal =
    Literal.Literal Expression


{-| Unlike a language like Haskell or PureScript, we don't allow custom operators.
Below is a list of all the operators Ren has, and their names. Refer to the
language docs if you want to know what all of these do!

    -- Functions
    |>  Pipe
    >>  Compose

    -- Maths
    +   Add
    -   Sub
    *   Mul
    /   Div
    ^   Pow
    %   Mod

    -- Comparison
    ==  Eq
    !=  NotEq
    <   Lt
    <=  Lte
    >   Gt
    >=  Gte

    -- Logic
    &   And
    |   Or

    -- Arrays
    ::  Cons
    ++  Join

-}
type alias Operator =
    Operator.Operator


{-| Patterns are used in function arguments and encompass a few different things.
Simple name bindings are patterns:

    fun foo => ...

But we can also do JS-style array and object destructuring:

    fun { foo } => ...
    fun [ bar ] => ...

And we can nest patterns inside these destructuring patterns as you might expect:

    fun { foo: { bar } } => ...
    fun [ bar, { baz } ] => ...

And finally there is the wildcard pattern when you want to _ignore_ an argument
but still require it to exist:

    fun _ => ...

The wildcard pattern can be used to "comment out" arguments by prefixing the
underscore on a simple name pattern:

    fun _foo => ...

-}
type alias Pattern =
    Pattern.Pattern



-- IDENITIFER HELPERS ----------------------------------------------------------


{-| Create an `Identifier` expression from a local name.
-}
local : String -> Expression
local name =
    Identifier <| Identifier.Local name


{-| Create an `Identifier` expression from a list of namespaces and a name.
-}
scoped : List String -> String -> Expression
scoped namespace name =
    Identifier <| Identifier.Scoped namespace name


{-| Create an `Identifier` expression from an `Operator`.
-}
operator : Operator -> Expression
operator op =
    Identifier <| Identifier.Operator op


{-| Create an `Identifier` expression from a record field name.
-}
field : String -> Expression
field name =
    Identifier <| Identifier.Field name



-- OPERATOR HELPERS ------------------------------------------------------------


{-| Convert an `Operator` to its symbollic representation in Ren code.
-}
operatorToSymbol : Operator -> String
operatorToSymbol op =
    case op of
        Operator.Pipe ->
            "|>"

        Operator.Compose ->
            ">>"

        Operator.Add ->
            "+"

        Operator.Sub ->
            "-"

        Operator.Mul ->
            "*"

        Operator.Div ->
            "/"

        Operator.Pow ->
            "^"

        Operator.Mod ->
            "%"

        Operator.Eq ->
            "=="

        Operator.NotEq ->
            "!="

        Operator.Lt ->
            "<"

        Operator.Lte ->
            "<="

        Operator.Gt ->
            ">"

        Operator.Gte ->
            ">="

        Operator.And ->
            "&"

        Operator.Or ->
            "|"

        Operator.Cons ->
            "::"

        Operator.Join ->
            "++"


{-| Create an `Operator` from its symbollic representation in Ren code.
-}
operatorFromSymbol : String -> Maybe Operator
operatorFromSymbol op =
    case op of
        "|>" ->
            Just Operator.Pipe

        ">>" ->
            Just Operator.Compose

        "+" ->
            Just Operator.Add

        "-" ->
            Just Operator.Sub

        "*" ->
            Just Operator.Mul

        "/" ->
            Just Operator.Div

        "^" ->
            Just Operator.Pow

        "%" ->
            Just Operator.Mod

        "==" ->
            Just Operator.Eq

        "!=" ->
            Just Operator.NotEq

        "<" ->
            Just Operator.Lt

        "<=" ->
            Just Operator.Lte

        ">" ->
            Just Operator.Gt

        ">=" ->
            Just Operator.Gte

        "&" ->
            Just Operator.And

        "|" ->
            Just Operator.Or

        "::" ->
            Just Operator.Cons

        "++" ->
            Just Operator.Join

        _ ->
            Nothing


{-| Convert an `Operator` to its (unqualified) name. This is the name that is
used in the Elm source code.
-}
operatorToName : Operator -> String
operatorToName op =
    case op of
        Operator.Pipe ->
            "Pipe"

        Operator.Compose ->
            "Compose"

        Operator.Add ->
            "Add"

        Operator.Sub ->
            "Sub"

        Operator.Mul ->
            "Mul"

        Operator.Div ->
            "Div"

        Operator.Pow ->
            "Pow"

        Operator.Mod ->
            "Mod"

        Operator.Eq ->
            "Eq"

        Operator.NotEq ->
            "NotEq"

        Operator.Lt ->
            "Lt"

        Operator.Lte ->
            "Lte"

        Operator.Gt ->
            "Gt"

        Operator.Gte ->
            "Gte"

        Operator.And ->
            "And"

        Operator.Or ->
            "Or"

        Operator.Cons ->
            "Cons"

        Operator.Join ->
            "Join"


{-| Create an `Operator` from its name used the in Elm source code.
-}
operatorFromName : String -> Maybe Operator
operatorFromName op =
    case op of
        "Pipe" ->
            Just Operator.Pipe

        "Compose" ->
            Just Operator.Compose

        "Add" ->
            Just Operator.Add

        "Sub" ->
            Just Operator.Sub

        "Mul" ->
            Just Operator.Mul

        "Div" ->
            Just Operator.Div

        "Pow" ->
            Just Operator.Pow

        "Mod" ->
            Just Operator.Mod

        "Eq" ->
            Just Operator.Eq

        "NotEq" ->
            Just Operator.NotEq

        "Lt" ->
            Just Operator.Lt

        "Lte" ->
            Just Operator.Lte

        "Gt" ->
            Just Operator.Gt

        "Gte" ->
            Just Operator.Gte

        "And" ->
            Just Operator.And

        "Or" ->
            Just Operator.Or

        "Cons" ->
            Just Operator.Cons

        "Join" ->
            Just Operator.Join

        _ ->
            Nothing



-- LITERAL HELPRES -------------------------------------------------------------


{-| Create an array literal expression from an Elm list of expressions.
-}
array : List Expression -> Expression
array elements =
    Literal <| Literal.Array elements


{-| Create a boolean literal expression from an Elm Bool.
-}
boolean : Bool -> Expression
boolean b =
    Literal <| Literal.Boolean b


{-| Create a number literal expression from an Elm Float.
-}
number : Float -> Expression
number f =
    Literal <| Literal.Number f


{-| Create a number literal expression from an Elm Int. Remember numbers in
Ren are always floating-point, so this will convert the argument to an Elm
Float first.
-}
int : Int -> Expression
int i =
    Literal <| Literal.Number (Basics.toFloat i)


{-| Create an object literal expression from an Elm list of key/value piars.
-}
object : List ( String, Expression ) -> Expression
object fields =
    Literal <| Literal.Object <| Dict.fromList fields


{-| Create a string literal expression from an Elm string.
-}
string : String -> Expression
string s =
    Literal <| Literal.String s



-- QUERIES ---------------------------------------------------------------------


{-| -}
referencesName : String -> Expression -> Bool
referencesName name_ expression =
    case expression of
        Access expr accessors ->
            referencesName name_ expr
                || List.any
                    (\accessor ->
                        case accessor of
                            Accessor.Computed e ->
                                referencesName name_ e

                            Accessor.Fixed _ ->
                                False
                    )
                    accessors

        Application func args ->
            referencesName name_ func
                || List.any (referencesName name_) args

        Conditional predicate true false ->
            referencesName name_ predicate
                || referencesName name_ true
                || referencesName name_ false

        Identifier (Identifier.Local id) ->
            id == name_

        Identifier _ ->
            False

        Infix _ lhs rhs ->
            referencesName name_ lhs
                || referencesName name_ rhs

        Lambda _ body ->
            referencesName name_ body

        Literal (Literal.Array elements) ->
            List.any (referencesName name_) elements

        Literal (Literal.Object entries) ->
            Dict.toList entries
                |> List.any (Tuple.second >> referencesName name_)

        Literal (Literal.Template segments) ->
            List.any
                (\segment ->
                    case segment of
                        Literal.Text _ ->
                            False

                        Literal.Expr expr ->
                            referencesName name_ expr
                )
                segments

        Literal _ ->
            False

        Match expr cases ->
            referencesName name_ expr
                || List.any
                    (\( _, guard, body ) ->
                        Maybe.map (referencesName name_) guard
                            |> Maybe.withDefault False
                            |> (||) (referencesName name_ body)
                    )
                    cases

        SubExpression expr ->
            referencesName name_ expr


{-| -}
referencesScopedName : List String -> String -> Expression -> Bool
referencesScopedName namespace_ name_ expression =
    case expression of
        Access expr accessors ->
            referencesScopedName namespace_ name_ expr
                || List.any
                    (\accessor ->
                        case accessor of
                            Accessor.Computed e ->
                                referencesScopedName namespace_ name_ e

                            Accessor.Fixed _ ->
                                False
                    )
                    accessors

        Application func args ->
            referencesScopedName namespace_ name_ func
                || List.any (referencesScopedName namespace_ name_) args

        Conditional predicate true false ->
            referencesScopedName namespace_ name_ predicate
                || referencesScopedName namespace_ name_ true
                || referencesScopedName namespace_ name_ false

        Identifier (Identifier.Scoped ns id) ->
            ns == namespace_ && id == name_

        Identifier _ ->
            False

        Infix _ lhs rhs ->
            referencesScopedName namespace_ name_ lhs
                || referencesScopedName namespace_ name_ rhs

        Lambda _ body ->
            referencesScopedName namespace_ name_ body

        Literal (Literal.Array elements) ->
            List.any (referencesScopedName namespace_ name_) elements

        Literal (Literal.Object entries) ->
            Dict.toList entries
                |> List.any (Tuple.second >> referencesScopedName namespace_ name_)

        Literal (Literal.Template segments) ->
            List.any
                (\segment ->
                    case segment of
                        Literal.Text _ ->
                            False

                        Literal.Expr expr ->
                            referencesScopedName namespace_ name_ expr
                )
                segments

        Literal _ ->
            False

        Match expr cases ->
            referencesScopedName namespace_ name_ expr
                || List.any
                    (\( _, guard, body ) ->
                        Maybe.map (referencesScopedName namespace_ name_) guard
                            |> Maybe.withDefault False
                            |> (||) (referencesScopedName namespace_ name_ body)
                    )
                    cases

        SubExpression expr ->
            referencesScopedName namespace_ name_ expr


{-| -}
referencesModule : List String -> Expression -> Bool
referencesModule namespace_ expression =
    case expression of
        Access expr accessors ->
            referencesModule namespace_ expr
                || List.any
                    (\accessor ->
                        case accessor of
                            Accessor.Computed e ->
                                referencesModule namespace_ e

                            Accessor.Fixed _ ->
                                False
                    )
                    accessors

        Application func args ->
            referencesModule namespace_ func
                || List.any (referencesModule namespace_) args

        Conditional predicate true false ->
            referencesModule namespace_ predicate
                || referencesModule namespace_ true
                || referencesModule namespace_ false

        Identifier (Identifier.Scoped ns _) ->
            ns == namespace_

        Identifier (Identifier.Operator Operator.Pipe) ->
            [ "$Function" ] == namespace_

        Identifier (Identifier.Operator Operator.Compose) ->
            [ "$Function" ] == namespace_

        Identifier (Identifier.Operator Operator.Add) ->
            [ "$Math" ] == namespace_

        Identifier (Identifier.Operator Operator.Sub) ->
            [ "$Math" ] == namespace_

        Identifier (Identifier.Operator Operator.Mul) ->
            [ "$Math" ] == namespace_

        Identifier (Identifier.Operator Operator.Div) ->
            [ "$Math" ] == namespace_

        Identifier (Identifier.Operator Operator.Pow) ->
            [ "$Math" ] == namespace_

        Identifier (Identifier.Operator Operator.Mod) ->
            [ "$Math" ] == namespace_

        Identifier (Identifier.Operator Operator.Eq) ->
            [ "$Comparison" ] == namespace_

        Identifier (Identifier.Operator Operator.NotEq) ->
            [ "$Comparison" ] == namespace_

        Identifier (Identifier.Operator Operator.Lt) ->
            [ "$Comparison" ] == namespace_

        Identifier (Identifier.Operator Operator.Lte) ->
            [ "$Comparison" ] == namespace_

        Identifier (Identifier.Operator Operator.Gt) ->
            [ "$Comparison" ] == namespace_

        Identifier (Identifier.Operator Operator.Gte) ->
            [ "$Comparison" ] == namespace_

        Identifier (Identifier.Operator Operator.And) ->
            [ "$Logic" ] == namespace_

        Identifier (Identifier.Operator Operator.Or) ->
            [ "$Logic" ] == namespace_

        Identifier (Identifier.Operator Operator.Cons) ->
            [ "$Array" ] == namespace_

        Identifier (Identifier.Operator Operator.Join) ->
            [ "$Array" ] == namespace_

        Identifier _ ->
            False

        Infix _ lhs rhs ->
            referencesModule namespace_ lhs
                || referencesModule namespace_ rhs

        Lambda _ body ->
            referencesModule namespace_ body

        Literal (Literal.Array elements) ->
            List.any (referencesModule namespace_) elements

        Literal (Literal.Object entries) ->
            Dict.toList entries
                |> List.any (Tuple.second >> referencesModule namespace_)

        Literal (Literal.Template segments) ->
            List.any
                (\segment ->
                    case segment of
                        Literal.Text _ ->
                            False

                        Literal.Expr expr ->
                            referencesModule namespace_ expr
                )
                segments

        Literal _ ->
            False

        Match expr cases ->
            referencesModule namespace_ expr
                || List.any
                    (\( _, guard, body ) ->
                        Maybe.map (referencesModule namespace_) guard
                            |> Maybe.withDefault False
                            |> (||) (referencesModule namespace_ body)
                    )
                    cases

        SubExpression expr ->
            referencesModule namespace_ expr



-- PARSING JSON ----------------------------------------------------------------


{-| Parse an `Expression` from an Elm JSON `Value`. You might find this handy if
you're working with some tooling that emits a Ren AST as JSON.
-}
fromJSON : Json.Decode.Value -> Result Json.Decode.Error Expression
fromJSON json =
    Json.Decode.decodeValue decoder json


{-| The decoder used in [`fromJSON`](#fromJSON). This might be handy if you have
a JSON string rather than an Elm `Value` and you want to decode it using
`Json.Decode.decodeString`.
-}
decoder : Decoder Expression
decoder =
    Json.Decode.oneOf
        [ accessDecoder
        , applicationDecoder
        , conditionalDecoder
        , identifierDecoder
        , infixDecoder
        , lambdaDecoder
        , literalDecoder
        , matchDecoder
        ]


{-| -}
lazyDecoder : Decoder Expression
lazyDecoder =
    Json.Decode.lazy (\_ -> decoder)



-- PARSING JSON: EXPRESSION.ACCESS ---------------------------------------------


{-| -}
accessDecoder : Decoder Expression
accessDecoder =
    Json.Decode.Extra.taggedObject "Expression.Access" <|
        Json.Decode.map2 Access
            (Json.Decode.field "expression" lazyDecoder)
            (Json.Decode.field "accessors" <|
                Json.Decode.list (Accessor.decoder lazyDecoder)
            )



-- PARSING JSON: EXPRESSION.APPLICATION ----------------------------------------


{-| -}
applicationDecoder : Decoder Expression
applicationDecoder =
    Json.Decode.Extra.taggedObject "Expression.Application" <|
        Json.Decode.map2 Application
            (Json.Decode.field "function" lazyDecoder)
            (Json.Decode.field "arguments" <|
                Json.Decode.list lazyDecoder
            )



-- PARSING JSON: EXPRESSION.CONDITIONAL ----------------------------------------


{-| -}
conditionalDecoder : Decoder Expression
conditionalDecoder =
    Json.Decode.Extra.taggedObject "Expression.Conditional" <|
        Json.Decode.map3 Conditional
            (Json.Decode.field "if" lazyDecoder)
            (Json.Decode.field "then" lazyDecoder)
            (Json.Decode.field "else" lazyDecoder)



-- PARSING JSON: EXPRESSION.IDENITIFER -----------------------------------------


{-| -}
identifierDecoder : Decoder Expression
identifierDecoder =
    Json.Decode.Extra.taggedObject "Expression.Identifier" <|
        Json.Decode.map Identifier
            (Json.Decode.field "identifier" Identifier.decoder)



-- PARSING JSON: EXPRESSION.INFIX ----------------------------------------------


{-| -}
infixDecoder : Decoder Expression
infixDecoder =
    Json.Decode.Extra.taggedObject "Expression.Infix" <|
        Json.Decode.map3 Infix
            (Json.Decode.field "operator" Operator.decoder)
            (Json.Decode.field "lhs" lazyDecoder)
            (Json.Decode.field "rhs" lazyDecoder)



-- PARSING JSON: EXPRESSION.LAMBDA ---------------------------------------------


{-| -}
lambdaDecoder : Decoder Expression
lambdaDecoder =
    Json.Decode.Extra.taggedObject "Expression.Lambda" <|
        Json.Decode.map2 Lambda
            (Json.Decode.field "arguments" <|
                Json.Decode.list Pattern.decoder
            )
            (Json.Decode.field "body" lazyDecoder)



-- PARSING JSON: EXPRESSION.LITERAL --------------------------------------------


{-| -}
literalDecoder : Decoder Expression
literalDecoder =
    Json.Decode.Extra.taggedObject "Expression.Literal" <|
        Json.Decode.map Literal
            (Json.Decode.field "literal" <|
                Literal.decoder lazyDecoder
            )



-- PARSING JSON: EXPRESSION.MATCH ----------------------------------------------


{-| -}
matchDecoder : Decoder Expression
matchDecoder =
    Json.Decode.Extra.taggedObject "Expression.Match" <|
        Json.Decode.map2 Match
            (Json.Decode.field "expression" lazyDecoder)
            (Json.Decode.field "cases" <|
                Json.Decode.list caseDecoder
            )


{-| -}
caseDecoder : Decoder ( Pattern, Maybe Expression, Expression )
caseDecoder =
    Json.Decode.Extra.taggedObject "Expression.Match.Case" <|
        Json.Decode.map3 (\pattern guard body -> ( pattern, guard, body ))
            (Json.Decode.field "pattern" Pattern.decoder)
            (Json.Decode.field "guard" <| Json.Decode.maybe lazyDecoder)
            (Json.Decode.field "expression" lazyDecoder)



-- PARSING SOURCE CODE ---------------------------------------------------------


{-| Parse an `Expression` from some Ren source code. It doesn't seem all that
likely you'll need to use this over `Declaration.fromSource` or `Module.fromSource`
but just in case it is, here you go.
-}
fromSource : String -> Result (List Parser.DeadEnd) Expression
fromSource src =
    Parser.run parser src


{-| The parse used in `fromSource`. It's unclear why you'd need this, but it's
exposed just in case you do.
-}
parser : Parser Expression
parser =
    Parser.succeed identity
        |. Parser.Extra.ignorables
        |= Pratt.expression
            { oneOf =
                [ conditionalParser
                , applicationParser
                , accessParser
                , lambdaParser
                , matchParser
                , Pratt.literal literalParser
                , parenthesisedParser
                , Pratt.literal identifierParser
                ]
            , andThenOneOf = Operator.parser Infix
            , spaces = Parser.Extra.ignorables
            }


{-| -}
parenthesisedParser : Pratt.Config Expression -> Parser Expression
parenthesisedParser prattConfig =
    Parser.succeed SubExpression
        |. Parser.symbol "("
        |. Parser.Extra.ignorables
        |= Pratt.subExpression 0 prattConfig
        |. Parser.Extra.ignorables
        |. Parser.symbol ")"
        |> Parser.backtrackable


{-| -}
lazyParser : Parser Expression
lazyParser =
    Parser.lazy (\_ -> parser)



-- PARSING SOURCE: EXPRESSION.ACCESS -------------------------------------------


{-| -}
accessParser : Pratt.Config Expression -> Parser Expression
accessParser prattConfig =
    Parser.succeed (\expr accessor accessors -> Access expr (accessor :: accessors))
        |= Parser.oneOf
            [ literalParser
            , parenthesisedParser prattConfig
            , identifierParser
            ]
        |= Accessor.parser lazyParser
        |= Parser.loop []
            (\accessors ->
                Parser.oneOf
                    [ Parser.succeed (\accessor -> accessor :: accessors)
                        |= Accessor.parser lazyParser
                        |> Parser.map Parser.Loop
                    , Parser.succeed (List.reverse accessors)
                        |> Parser.map Parser.Done
                    ]
            )
        |> Parser.backtrackable



-- PARSING SOURCE: EXPRESSION.APPLICATION --------------------------------------


{-| -}
applicationParser : Pratt.Config Expression -> Parser Expression
applicationParser prattConfig =
    Parser.succeed (\function arg args -> Application function (arg :: args))
        |= Parser.oneOf
            [ accessParser prattConfig
            , parenthesisedParser prattConfig
            , identifierParser
            ]
        |. Parser.Extra.ignorables
        |= applicationArgumentParser prattConfig
        |. Parser.Extra.ignorables
        |= Parser.loop []
            (\args ->
                Parser.oneOf
                    [ Parser.succeed (\arg -> arg :: args)
                        |= applicationArgumentParser prattConfig
                        |. Parser.Extra.ignorables
                        |> Parser.map Parser.Loop
                    , Parser.succeed (List.reverse args)
                        |> Parser.map Parser.Done
                    ]
            )
        |> Parser.backtrackable


{-| -}
applicationArgumentParser : Pratt.Config Expression -> Parser Expression
applicationArgumentParser prattConfig =
    Parser.oneOf
        [ parenthesisedParser prattConfig
        , accessParser prattConfig
        , lambdaParser prattConfig
        , literalParser
        , identifierParser
        ]



-- PARSING SOURCE: EXPRESSION.CONDITIONAL --------------------------------------


{-| -}
conditionalParser : Pratt.Config Expression -> Parser Expression
conditionalParser prattConfig =
    Parser.succeed Conditional
        |. Parser.keyword "if"
        |. Parser.Extra.ignorables
        |= Pratt.subExpression 0 prattConfig
        |. Parser.keyword "then"
        |. Parser.Extra.ignorables
        |= Pratt.subExpression 0 prattConfig
        |. Parser.keyword "else"
        |. Parser.Extra.ignorables
        |= Pratt.subExpression 0 prattConfig



-- PARSING SOURCE: EXPRESSION.IDENTIFIER ---------------------------------------


{-| -}
identifierParser : Parser Expression
identifierParser =
    Parser.succeed Identifier
        |= Identifier.parser



-- PARSING SOURCE: EXPRESSION.LAMBDA -------------------------------------------


{-| -}
lambdaParser : Pratt.Config Expression -> Parser Expression
lambdaParser prattConfig =
    Parser.succeed Lambda
        |. Parser.keyword "fun"
        |. Parser.Extra.ignorables
        |= Parser.sequence
            { start = ""
            , separator = " "
            , end = ""
            , item =
                Parser.succeed identity
                    |. Parser.Extra.ignorables
                    |= Pattern.parser
            , spaces = Parser.succeed ()
            , trailing = Parser.Optional
            }
        |. Parser.Extra.ignorables
        |. Parser.symbol "=>"
        |. Parser.Extra.ignorables
        |= Pratt.subExpression 0 prattConfig



-- PARSING SOURCE: EXPRESSION.LITERAL ------------------------------------------


{-| -}
literalParser : Parser Expression
literalParser =
    Parser.succeed Literal
        |= Literal.parser
            (\name -> Identifier (Identifier.Local name))
            lazyParser



-- PARSING SOURCE: EXPRESSION.MATCH --------------------------------------------


{-| -}
matchParser : Pratt.Config Expression -> Parser Expression
matchParser prattConfig =
    Parser.succeed Match
        |. Parser.keyword "when"
        |. Parser.Extra.ignorables
        |= lazyParser
        |. Parser.Extra.ignorables
        |= Parser.loop []
            (\cases ->
                Parser.oneOf
                    [ Parser.succeed (\pattern guard expr -> ( pattern, guard, expr ) :: cases)
                        |. Parser.keyword "is"
                        |. Parser.Extra.ignorables
                        |= Pattern.parser
                        |. Parser.Extra.ignorables
                        |= Parser.oneOf
                            [ Parser.succeed Just
                                |. Parser.keyword "if"
                                |. Parser.Extra.ignorables
                                |= Pratt.subExpression 0 prattConfig
                                |. Parser.Extra.ignorables
                            , Parser.succeed Nothing
                            ]
                        |. Parser.symbol "=>"
                        |. Parser.Extra.ignorables
                        |= Pratt.subExpression 0 prattConfig
                        |> Parser.map Parser.Loop
                    , Parser.succeed (\expr -> ( Pattern.Wildcard Nothing, Nothing, expr ) :: cases)
                        |. Parser.keyword "else"
                        |. Parser.Extra.ignorables
                        |. Parser.symbol "=>"
                        |. Parser.Extra.ignorables
                        |= Pratt.subExpression 0 prattConfig
                        |> Parser.map Parser.Loop
                    , Parser.succeed (List.reverse cases)
                        |> Parser.map Parser.Done
                    ]
            )
