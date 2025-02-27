module Ren.Language.Declaration exposing
    ( nameAsPattern
    , references, referencesNamespace, referencesQualified
    )

{-|

@docs nameAsPattern
@docs references, referencesNamespace, referencesQualified

-}

-- IMPORTS ---------------------------------------------------------------------

import Ren.Language exposing (..)
import Ren.Language.Expression



-- QUERIES ---------------------------------------------------------------------


{-| -}
nameAsPattern : Declaration -> Pattern
nameAsPattern declaration =
    case declaration of
        Function name _ _ ->
            Name name

        Variable name _ ->
            name

        Enum _ variants ->
            ArrayDestructure
                (List.map (\(Variant tag _) -> Name tag) variants)


{-| -}
references : String -> Declaration -> Bool
references name declaration =
    case declaration of
        Function _ _ expr ->
            Ren.Language.Expression.references name expr

        Variable _ expr ->
            Ren.Language.Expression.references name expr

        Enum _ _ ->
            False


{-| -}
referencesNamespace : List String -> Declaration -> Bool
referencesNamespace namespace declaration =
    case declaration of
        Function _ _ expr ->
            Ren.Language.Expression.referencesNamespace namespace expr

        Variable _ expr ->
            Ren.Language.Expression.referencesNamespace namespace expr

        Enum _ _ ->
            False


{-| -}
referencesQualified : List String -> String -> Declaration -> Bool
referencesQualified namespace name declaration =
    case declaration of
        Function _ _ expr ->
            Ren.Language.Expression.referencesQualified namespace name expr

        Variable _ expr ->
            Ren.Language.Expression.referencesQualified namespace name expr

        Enum _ _ ->
            False
