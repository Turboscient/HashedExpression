module HashedExpression.Internal.Utils where

import Data.Array
import Data.Complex
import qualified Data.IntMap.Strict as IM
import Data.List.Split (splitOn)
import Data.Map (Map, fromList)
import qualified Data.Map as Map
import Data.Maybe
import qualified Data.Set as Set
import qualified Data.Text as T
import Data.Time (diffUTCTime, getCurrentTime)
import GHC.IO.Unsafe (unsafePerformIO)
import GHC.Stack (HasCallStack)
import HashedExpression.Internal.Expression
import HashedExpression.Internal.Hash
import HashedExpression.Internal.Node
import HashedExpression.Prettify
import Prelude hiding ((^))
import qualified Prelude

-- | Forward pipe operator in Elm
(|>) :: a -> (a -> b) -> b
(|>) = flip ($)

infixl 1 |>

-- | Chain a list of endomorphisms to a endomorphism
chain :: [a -> a] -> a -> a
chain = flip $ foldl (|>)

-- |
read2DValues :: FilePath -> IO (Array (Int, Int) Double)
read2DValues filePath = do
  rows <- lines <$> readFile filePath
  let doubleRows = map (map read . splitOn " ") rows
  let numRow = length doubleRows
      numCol = length . head $ doubleRows
      allDoubles = concat doubleRows
  return $ listArray ((0, 0), (numRow - 1, numCol - 1)) allDoubles

--        allDoubles = map read . concat $ rows

-- |
mapBoth :: (a -> b) -> (a, a) -> (b, b)
mapBoth f (x, y) = (f x, f y)

-- |
mapSecond :: (b -> c) -> [(a, b)] -> [(a, c)]
mapSecond _ [] = []
mapSecond f ((x, y) : rest) = (x, f y) : mapSecond f rest

-- |
measureTime :: IO a -> IO ()
measureTime action = do
  beforeTime <- getCurrentTime
  action
  afterTime <- getCurrentTime
  putStrLn $ "Took " ++ show (diffUTCTime afterTime beforeTime) ++ " seconds"

-- |
bringMaybeOut :: (Maybe a, Maybe b) -> Maybe (a, b)
bringMaybeOut (Just x, Just y) = Just (x, y)
bringMaybeOut _ = Nothing

-- | Check if all elements of the list is equal
allEqual :: (Eq a) => [a] -> Bool
allEqual xs = and $ zipWith (==) (safeTail xs) xs
  where
    safeTail [] = []
    safeTail (x : xs) = xs

fromR :: Double -> Complex Double
fromR x = x :+ 0

ensureSameShape :: Expression d et1 -> Expression d et2 -> a -> a
ensureSameShape e1 e2 after
  | expressionShape e1 == expressionShape e2 = after
  | otherwise =
    error $
      "Ensure same shape failed "
        ++ show (prettifyDebug e1)
        ++ " "
        ++ show (prettifyDebug e2)

ensureSameShapeList :: [Expression d et] -> a -> a
ensureSameShapeList es after
  | allEqual (map expressionShape es) = after
  | otherwise =
    error $ "Ensure same shape failed " ++ show (map expressionShape es)

constWithShape :: Shape -> Double -> Expression d R
constWithShape shape val = Expression h (IM.fromList [(h, node)])
  where
    node = (shape, Const val)
    h = hash node

varWithShape :: Shape -> String -> (ExpressionMap, NodeID)
varWithShape shape name = (IM.fromList [(h, node)], h)
  where
    node = (shape, Var name)
    h = hash node

-- |
isScalarShape :: Shape -> Bool
isScalarShape = null

-- |
pullConstant :: ExpressionMap -> NodeID -> Maybe (Shape, Double)
pullConstant mp n
  | (shape, Const c) <- retrieveInternal n mp = Just (shape, c)
  | otherwise = Nothing

-- |
pullConstants :: ExpressionMap -> [NodeID] -> Maybe (Shape, [Double])
pullConstants mp ns
  | xs@(x : _) <- mapMaybe (pullConstant mp) ns = Just (fst x, map snd xs)
  | otherwise = Nothing

-- |
isZero :: ExpressionMap -> NodeID -> Bool
isZero mp nId
  | Const 0 <- retrieveNode nId mp = True
  | RealImag arg1 arg2 <- retrieveNode nId mp,
    Const 0 <- retrieveNode arg1 mp,
    Const 0 <- retrieveNode arg2 mp =
    True
  | otherwise = False

-- |
isOne :: ExpressionMap -> NodeID -> Bool
isOne mp nId
  | Const 1 <- retrieveNode nId mp = True
  | RealImag arg1 arg2 <- retrieveNode nId mp,
    Const 1 <- retrieveNode arg1 mp,
    Const 0 <- retrieveNode arg2 mp =
    True
  | otherwise = False

-- |
isConstant :: ExpressionMap -> NodeID -> Bool
isConstant mp nId
  | Const _ <- retrieveNode nId mp = True
  | otherwise = False

-- |
pullSumOperands :: ExpressionMap -> NodeID -> [NodeID]
pullSumOperands mp nId
  | Sum _ operands <- retrieveNode nId mp = operands
  | otherwise = [nId]

-- |
pullProdOperands :: ExpressionMap -> NodeID -> [NodeID]
pullProdOperands mp nId
  | Mul _ operands <- retrieveNode nId mp = operands
  | otherwise = [nId]

-- |
aConst :: Shape -> Double -> (ExpressionMap, NodeID)
aConst shape val = (IM.fromList [(h, node)], h)
  where
    node = (shape, Const val)
    h = hash node

-- |
dVarWithShape :: Shape -> String -> (ExpressionMap, NodeID)
dVarWithShape shape name = (IM.fromList [(h, node)], h)
  where
    node = (shape, DVar name)
    h = hash node

showT :: Show a => a -> T.Text
showT = T.pack . show

-- |
maybeVariable :: DimensionType d => Expression d R -> Maybe (String, Shape)
maybeVariable (Expression nID mp) = case retrieveInternal nID mp of 
  (shape, Var name) -> Just (name, shape)
  _ -> Nothing
  

-------------------------------------------------------------------------------

-- | MARK: (+)
-------------------------------------------------------------------------------
instance Num (Array Int Double) where
  (+) arr1 arr2 =
    listArray
      (0, size - 1)
      [x + y | i <- [0 .. size - 1], let x = arr1 ! i, let y = arr2 ! i]
    where
      size = length . elems $ arr1
  negate arr =
    listArray (0, size - 1) [- x | i <- [0 .. size - 1], let x = arr ! i]
    where
      size = length . elems $ arr
  (*) arr1 arr2 =
    listArray
      (0, size - 1)
      [x * y | i <- [0 .. size - 1], let x = arr1 ! i, let y = arr2 ! i]
    where
      size = length . elems $ arr1
  abs = error "TODO"
  signum = error "N/A"
  fromInteger = error "TODO"

instance Num (Array Int (Complex Double)) where
  (+) arr1 arr2 =
    listArray
      (0, size - 1)
      [x + y | i <- [0 .. size - 1], let x = arr1 ! i, let y = arr2 ! i]
    where
      size = length . elems $ arr1
  negate arr =
    listArray (0, size - 1) [- x | i <- [0 .. size - 1], let x = arr ! i]
    where
      size = length . elems $ arr
  (*) arr1 arr2 =
    listArray
      (0, size - 1)
      [x * y | i <- [0 .. size - 1], let x = arr1 ! i, let y = arr2 ! i]
    where
      size = length . elems $ arr1
  abs = error "TODO"
  signum = error "N/A"
  fromInteger = error "TODO"

instance PowerOp Double Int where
  (^) x y = x Prelude.^ y
