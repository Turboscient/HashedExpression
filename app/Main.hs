module Main where

import Data.Array.Unboxed as U
import HashedDerivative
import HashedExpression
import HashedFactor
import HashedInterp
import HashedOperation
import HashedPrettify
import HashedSimplify
import Prelude hiding
    ( (*)
    , (+)
    , (-)
    , (/)
    , acos
    , acosh
    , asin
    , asinh
    , atan
    , atanh
    , cos
    , cosh
    , exp
    , log
    , sin
    , sinh
    , sqrt
    , tan
    , tanh
    )

import Test.Hspec
import Test.QuickCheck hiding (scale)

main = do
    let x = var1d 10 "x"
        y = var1d 10 "y"
        z = var1d 10 "z"
        s = var "s"
        f = log $ exp $ sqrt $ cos $ s `scale` (x * y) / y
        fImg = realPart $ f +: z
    print $ prettify fImg
    print $ prettify $ exteriorDerivative fImg
--    print $ prettify . exteriorDerivative $ f
