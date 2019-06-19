{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}

module HashedPrettify
    ( prettify
    ) where

import Data.List (intercalate)
import qualified Data.Text as T
import HashedUtils
import Data.Typeable
import HashedExpression

prettify ::
       forall d rc. (Typeable d, Typeable rc)
    => Expression d rc
    -> String
prettify e@(Expression n mp) =
    let shape = expressionShape e
        node = expressionNode e
        typeName =
            " :: " ++
            (show . typeRep $ (Proxy :: Proxy d)) ++
            " " ++ (show . typeRep $ (Proxy :: Proxy rc))
     in T.unpack (hiddenPrettify e) ++ typeName

hiddenPrettify :: Expression d rc -> T.Text
hiddenPrettify e@(Expression n mp) =
    let shape = expressionShape e
        wrapParentheses x = T.concat ["(", x, ")"]
        node = expressionNode e
        innerPrettify = hiddenPrettify . flip Expression mp
        shapeSignature =
            case shape of
                [] -> ""
                [x] -> T.concat ["[", T.pack . show $ x, "]"]
                [x, y] ->
                    T.concat
                        [ "["
                        , T.pack . show $ x
                        , "]"
                        , "["
                        , T.pack . show $ y
                        , "]"
                        ]
                [x, y, z] ->
                    T.concat
                        [ "["
                        , T.pack . show $ x
                        , "]"
                        , "["
                        , T.pack . show $ y
                        , "]"
                        , "["
                        , T.pack . show $ z
                        , "]"
                        ]
     in case node of
            Var name -> T.concat [T.pack name, shapeSignature]
            DVar name -> T.concat ["d", T.pack name, shapeSignature]
            Const val -> T.concat [T.pack . show $ val, shapeSignature]
            Sum _ args ->
                wrapParentheses . T.intercalate "+" . map innerPrettify $ args
            Mul _ args ->
                wrapParentheses . T.intercalate "*" . map innerPrettify $ args
            Div arg1 arg2 ->
                wrapParentheses . T.concat $
                [innerPrettify arg1, "/", innerPrettify arg2]
            Sqrt arg -> T.concat ["sqrt", wrapParentheses $ innerPrettify arg]
            Sin arg -> T.concat ["sin", wrapParentheses $ innerPrettify arg]
            Cos arg -> T.concat ["cos", wrapParentheses $ innerPrettify arg]
            Tan arg -> T.concat ["tan", wrapParentheses $ innerPrettify arg]
            Exp arg -> T.concat ["exp", wrapParentheses $ innerPrettify arg]
            Log arg -> T.concat ["log", wrapParentheses $ innerPrettify arg]
            Sinh arg -> T.concat ["sinh", wrapParentheses $ innerPrettify arg]
            Cosh arg -> T.concat ["cosh", wrapParentheses $ innerPrettify arg]
            Tanh arg -> T.concat ["tanh", wrapParentheses $ innerPrettify arg]
            Asin arg -> T.concat ["asin", wrapParentheses $ innerPrettify arg]
            Acos arg -> T.concat ["acos", wrapParentheses $ innerPrettify arg]
            Atan arg -> T.concat ["atan", wrapParentheses $ innerPrettify arg]
            Asinh arg -> T.concat ["asinh", wrapParentheses $ innerPrettify arg]
            Acosh arg -> T.concat ["acosh", wrapParentheses $ innerPrettify arg]
            Atanh arg -> T.concat ["atanh", wrapParentheses $ innerPrettify arg]
            RealImag arg1 arg2 -> T.concat [innerPrettify arg1, "+:", innerPrettify arg2]
            RealPart arg -> T.concat ["Re", wrapParentheses $ innerPrettify arg]
            ImagPart arg -> T.concat ["Im", wrapParentheses $ innerPrettify arg]