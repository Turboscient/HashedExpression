{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}

module Main where

import Data.Array
import Data.Complex
import qualified Data.IntMap.Strict as IM
import Data.Map (empty, fromList, union)
import qualified Data.Set as Set
import HashedDerivative
import HashedExpression
import HashedInterp
import HashedNormalize
import HashedOperation hiding (product, sum)
import qualified HashedOperation
import HashedPrettify
import Prelude hiding
    ( (*)
    , (+)
    , (-)
    , (/)
    , (^)
    , acos
    , acosh
    , asin
    , asinh
    , atan
    , atanh
    , const
    , cos
    , cosh
    , exp
    , log
    , negate
    , product
    , sin
    , sinh
    , sqrt
    , sum
    , tan
    , tanh
    )
import ToF.ToF

import Data.List (intercalate)
import Data.Maybe (fromJust)
import Data.STRef.Strict
import Graphics.EasyPlot
import HashedCollect
import HashedPlot
import HashedSolver
import HashedToC (singleExpressionCProgram)
import HashedUtils
import HashedVar
import Test.Hspec
import ToF.VelocityGenerator

sum1 :: (DimensionType d, Addable et) => [Expression d et] -> Expression d et
sum1 = fromJust . HashedOperation.sum

prod1 :: (DimensionType d, NumType et) => [Expression d et] -> Expression d et
prod1 = fromJust . HashedOperation.product

--
main = do
    let x = variable1D @10 "x"
        y = variable1D @10 "y"
        z = variable1D @10 "z"
        t = variable1D @10 "t"
    let exp =
            (xRe (ft (x +: y) - (z +: t)) <.> xRe (ft (x +: y) - (z +: t))) +
            (xIm (ft (x +: y) - (z +: t)) <.> xIm (ft (x +: y) - (z +: t)))
        vars = Set.fromList ["x", "y"]
        problem = constructProblem exp vars
        values =
            fromList
                [ ("z", V1D $ listArray (0, 9) [1 ..])
                , ("t", V1D $ listArray (0, 9) [5 ..])
                ]
    let codes = generateProblemCode values problem
    writeFile "algorithms/lbfgs/problem.c" $ intercalate "\n" codes
