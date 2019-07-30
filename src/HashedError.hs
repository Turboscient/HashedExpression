{-|
Module      : HashedError
Description : Responsible for calculating the calculation error amount of expressions based on Interval Analysis.
Maintainer  : ghaffh1@mcmaster.ca


The main idea behind implementation of HaheshError is to track down the amount of error generated based on different
mathematical operations. For this purpose we are going to use the simple idea of Interval Analyis.
-}

{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}

module HashedError where

import Data.Array
import Data.Complex
import qualified Data.IntMap.Strict as IM
import Data.Map (Map, fromList)
import qualified Data.Map as Map
import Debug.Trace (traceId, traceShowId)
import HashedExpression
    ( C
    , ET(..)
    , Expression(..)
    , ExpressionMap
    , Node(..)
    , One
    , R
    , Three
    , Two
    , Zero
    )
import HashedNode
import HashedPrettify (prettify, showExp)
import HashedUtils

-- | Interval generation based on the value mapped to the function
intervalGen ::
    Double -> -- ^ The value mapped to the function
    Double -> -- ^ Radius for generating the interval
    [Double]  -- ^ Output range
intervalGen a b = [(a - b),a..(a + b)]

-- | Class for calculating the intervals
class InterValable a b| a -> b where
  myInterval :: Double -> a -> b

instance InterValable Double [Double] where
  myInterval :: Double -> Double -> [Double]
  myInterval radius val = intervalGen val radius

instance InterValable (Array Int Double) (Array Int [Double]) where
  myInterval :: Double  -> (Array Int Double) -> (Array Int [Double])
  myInterval radius val = listArray (bounds val) [ intervalGen (val ! i) radius | i <- indices val ]

instance InterValable (Array (Int,Int) Double) (Array (Int,Int) [Double]) where
  myInterval :: Double  -> (Array (Int,Int) Double) -> (Array (Int,Int) [Double])
  myInterval radius val = listArray (bounds val) [ intervalGen (val ! (i,j)) radius | (i,j) <- indices val ]

instance InterValable (Array (Int,Int,Int) Double) (Array (Int,Int,Int) [Double]) where
    myInterval :: Double  -> (Array (Int,Int,Int) Double) -> (Array (Int,Int,Int) [Double])
    myInterval radius val = listArray (bounds val) [ intervalGen (val ! (i,j,k)) radius | (i,j,k) <- indices val ]


-- | This operation emulates the mathematical operation
-- | Turn expression to the right type
--
expZeroR :: ExpressionMap -> Int -> Expression Zero R
expZeroR = flip Expression

expOneR :: ExpressionMap -> Int -> Expression One R
expOneR = flip Expression

expTwoR :: ExpressionMap -> Int -> Expression Two R
expTwoR = flip Expression

expThreeR :: ExpressionMap -> Int -> Expression Three R
expThreeR = flip Expression

expZeroC :: ExpressionMap -> Int -> Expression Zero C
expZeroC = flip Expression

expOneC :: ExpressionMap -> Int -> Expression One C
expOneC = flip Expression

expTwoC :: ExpressionMap -> Int -> Expression Two C
expTwoC = flip Expression

expThreeC :: ExpressionMap -> Int -> Expression Three C
expThreeC = flip Expression


-- | Choose branch base on condition value
--
chooseBranch :: [Double] -> Double -> [a] -> a
chooseBranch marks val branches
    | val < head marks = head branches
    | otherwise =
        snd . last . filter ((val >=) . fst) $ zip marks (tail branches)

-- | These should be commented properly.
--
class Evaluable d rc output | d rc -> output where
  eval :: ValMaps -> Expression d rc -> output

-- |
--
instance Evaluable Zero R Double where
    eval :: ValMaps -> Expression Zero R -> Double
    eval valMap e@(Expression n mp)
        | [] <- retrieveShape n mp =
            case retrieveNode n mp of
                Var name ->
                    case Map.lookup name $ vm0 valMap of
                        Just val -> val
                        _ -> error "no value associated with the variable"
                Const val -> val
                Sum R args -> sum . map (eval valMap . expZeroR mp) $ args
--                Mul R args -> product . map (eval valMap . expZeroR mp) $ args
--                Neg R arg -> -(eval valMap $ expZeroR mp arg)
--                Scale R arg1 arg2 ->
--                    eval valMap (expZeroR mp arg1) *
--                    eval valMap (expZeroR mp arg2)
--                Power x arg -> eval valMap (expZeroR mp arg) ^ x
--                Div arg1 arg2 ->
--                    eval valMap (expZeroR mp arg1) /
--                    eval valMap (expZeroR mp arg2)
--                Sqrt arg -> sqrt (eval valMap (expZeroR mp arg))
--                Sin arg -> sin (eval valMap (expZeroR mp arg))
--                Cos arg -> cos (eval valMap (expZeroR mp arg))
--                Tan arg -> tan (eval valMap (expZeroR mp arg))
--                Exp arg -> exp (eval valMap (expZeroR mp arg))
--                Log arg -> log (eval valMap (expZeroR mp arg))
--                Sinh arg -> sinh (eval valMap (expZeroR mp arg))
--                Cosh arg -> cosh (eval valMap (expZeroR mp arg))
--                Tanh arg -> tanh (eval valMap (expZeroR mp arg))
--                Asin arg -> asin (eval valMap (expZeroR mp arg))
--                Acos arg -> acos (eval valMap (expZeroR mp arg))
--                Atan arg -> atan (eval valMap (expZeroR mp arg))
--                Asinh arg -> asinh (eval valMap (expZeroR mp arg))
--                Acosh arg -> acosh (eval valMap (expZeroR mp arg))
--                Atanh arg -> atanh (eval valMap (expZeroR mp arg))
--                RealPart arg -> realPart (eval valMap (expZeroC mp arg))
--                ImagPart arg -> imagPart (eval valMap (expZeroC mp arg))
--                InnerProd R arg1 arg2 ->
--                    case retrieveShape arg1 mp of
--                        [] ->
--                            eval valMap (expZeroR mp arg1) *
--                            eval valMap (expZeroR mp arg2)
--                        [size] ->
--                            let res1 = eval valMap $ expOneR mp arg1
--                                res2 = eval valMap $ expOneR mp arg2
--                             in sum [ x * y
--                                    | i <- [0 .. size - 1]
--                                    , let x = res1 ! i
--                                    , let y = res2 ! i
--                                    ]
--                        [size1, size2] ->
--                            let res1 = eval valMap $ expTwoR mp arg1
--                                res2 = eval valMap $ expTwoR mp arg2
--                             in sum [ x * y
--                                    | i <- [0 .. size1 - 1]
--                                    , j <- [0 .. size2 - 1]
--                                    , let x = res1 ! (i, j)
--                                    , let y = res2 ! (i, j)
--                                    ]
--                        [size1, size2, size3] ->
--                            let res1 = eval valMap $ expThreeR mp arg1
--                                res2 = eval valMap $ expThreeR mp arg2
--                             in sum [ x * y
--                                    | i <- [0 .. size1 - 1]
--                                    , j <- [0 .. size2 - 1]
--                                    , k <- [0 .. size3 - 1]
--                                    , let x = res1 ! (i, j, k)
--                                    , let y = res2 ! (i, j, k)
--                                    ]
--                        _ -> error "4D shape?"
--                Piecewise marks conditionArg branchArgs ->
--                    let cdt = eval valMap $ expZeroR mp conditionArg
--                        branches = map (eval valMap . expZeroR mp) branchArgs
--                     in chooseBranch marks cdt branches
                _ ->
                    error
                        ("expression structure Scalar R is wrong " ++ prettify e)
        | otherwise = error "one r but shape is not [] ??"
