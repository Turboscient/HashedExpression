{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleInstances #-}

module HashedSolver where

import Control.Monad (unless)
import Data.Array (bounds)
import qualified Data.IntMap as IM
import Data.List (find, intercalate)
import qualified Data.Map as Map
import Data.Map (Map)
import Data.Maybe (fromJust, mapMaybe)
import qualified Data.Set as Set
import Data.Set (Set)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Tuple.HT (fst3, thd3)
import HashedCollect
import HashedDerivative
import HashedExpression
    ( Covector
    , ET(..)
    , Expression(..)
    , ExpressionMap
    , Node(..)
    , R
    , Scalar
    , Shape
    , exIndex
    , exMap
    )
import HashedInner
import HashedNode
import HashedNormalize (normalize)
import HashedPrettify
import HashedToC
import HashedUtils
import System.Process (readProcess, readProcessWithExitCode)

-- |
--
data Variable =
    Variable
        { varName :: String
        , nodeId :: Int
        , partialDerivativeId :: Int
        }
    deriving (Show)

-- |
--
data Problem =
    Problem
        { variables :: [Variable]
        , objectiveId :: Int
        , expressionMap :: ExpressionMap
        , memMap :: MemMap
        , constraint :: Constraint
        }

-- | 
--
data Constraint
    = NoConstraint
    | BoxConstraint [ConstraintInfo]
    | IPOPTConstraint [ConstraintInfo]
    deriving (Show, Eq, Ord)

-- |
--
data ConstraintInfo
    = ScalarLower (Expression Scalar R) Double
    | ScalarUpper (Expression Scalar R) Double
    | ScalarBetween (Expression Scalar R) (Double, Double)
    -- box constraint of variables
    | BoxUpper String Val
    | BoxLower String Val
    | BoxBetween String (Val, Val)
    deriving (Show, Eq, Ord)

isBox :: ConstraintInfo -> Bool
isBox c =
    case c of
        BoxUpper {} -> True
        BoxLower {} -> True
        BoxBetween {} -> True
        _ -> False

-- | 
--
class ConstraintOperation a b | a -> b where
    (.<=) :: a -> b -> ConstraintInfo
    (.>=) :: a -> b -> ConstraintInfo
    between :: a -> (b, b) -> ConstraintInfo
    (.==) :: a -> b -> ConstraintInfo

infix 1 `between`, .>=, .<=

instance ConstraintOperation (Expression Scalar R) Double where
    (.<=) = ScalarUpper
    (.>=) = ScalarLower
    between = ScalarBetween
    (.==) exp db = ScalarBetween exp (db, db)

instance ConstraintOperation String Val where
    (.<=) = BoxUpper
    (.>=) = BoxLower
    between = BoxBetween
    (.==) var val = BoxBetween var (val, val)

-- | Return a map from variable name to the corresponding partial derivative node id
--   Partial derivatives in Expression Scalar Covector should be collected before passing to this function
--
partialDerivativeMaps :: Expression Scalar Covector -> Map String Int
partialDerivativeMaps df@(Expression dfId dfMp) =
    case retrieveNode dfId dfMp of
        Sum Covector ns -> Map.fromList $ mapMaybe getPartial ns
        _ -> Map.fromList $ mapMaybe getPartial [dfId]
  where
    getPartial :: Int -> Maybe (String, Int)
    getPartial nId
        | Mul Covector [partialId, dId] <- retrieveNode nId dfMp
        , DVar name <- retrieveNode dId dfMp = Just (name, partialId)
        | InnerProd Covector partialId dId <- retrieveNode nId dfMp
        , DVar name <- retrieveNode dId dfMp = Just (name, partialId)
        | otherwise = Nothing

-- | Construct a Problem from given objective function
--
constructProblem :: Expression Scalar R -> [String] -> Constraint -> Problem
constructProblem notSimplifedF varList constraint =
    let vars = Set.fromList varList
        f@(Expression fId fMp) = normalize notSimplifedF
        df@(Expression dfId dfMp) =
            collectDifferentials . exteriorDerivative vars $ f
        -- Map from a variable name to id in the problem's ExpressionMap
        name2Id :: Map String Int
        name2Id =
            Map.fromList $
            filter (flip Set.member vars . fst) $ expressionVarNodes f
        -- Map from a variable name to partial derivative id in the problem's ExpressionMap
        name2PartialDerivativeId :: Map String Int
        name2PartialDerivativeId = partialDerivativeMaps df
        -- Root ids, including the objective function and all partial derivatives
        rootNs = exIndex f : (map snd . Map.toList $ name2PartialDerivativeId)
        -- From a name to a Variable data
        toVariable :: String -> Variable
        toVariable varName =
            Variable
                { varName = varName
                , nodeId = fromJust $ Map.lookup varName name2Id
                , partialDerivativeId =
                      fromJust $ Map.lookup varName name2PartialDerivativeId
                }
        -- variables
        problemVariables = map toVariable . Set.toList $ vars
        mergedMap = IM.union dfMp fMp
        topologicalOrder = topologicalSortManyRoots (mergedMap, rootNs)
        -- expression map
        problemExpressionMap :: ExpressionMap
        problemExpressionMap =
            IM.fromList $
            map
                (\nId -> (nId, fromJust $ IM.lookup nId mergedMap))
                topologicalOrder
        -- mem map
        problemMemMap = makeMemMap problemExpressionMap
        -- objective id
        problemObjectiveId = fId
     in Problem
            { variables = problemVariables
            , objectiveId = problemObjectiveId
            , memMap = problemMemMap
            , expressionMap = problemExpressionMap
            , constraint = constraint
            }

-- | Read $numDoubles$ doubles from $fileName$ to ptr[offset]
--
generateReadValuesCode :: String -> Val -> String -> Int -> Code
generateReadValuesCode dataset val address numDoubles =
    case val of
        VScalar value -> scoped ["*(" ++ address ++ ")" <<- show value]
        V1D _ -> readFileText (dataset ++ ".txt")
        V2D _ -> readFileText (dataset ++ ".txt")
        V3D _ -> readFileText (dataset ++ ".txt")
        V1DFile TXT fileName -> readFileText fileName
        V2DFile TXT fileName -> readFileText fileName
        V3DFile TXT fileName -> readFileText fileName
        V1DFile HDF5 fileName -> readFileHD5 fileName
        V2DFile HDF5 fileName -> readFileHD5 fileName
        V3DFile HDF5 fileName -> readFileHD5 fileName
  where
    readFileText fileName =
        scoped
            [ "printf(\"Reading " ++
              dataset ++ " from text file " ++ fileName ++ "....\\n\");"
            , "FILE *fp = fopen(\"" ++ fileName ++ "\", \"r\");"
            , "int i;"
            , "for (i = 0; i < " ++ show numDoubles ++ "; i++) { "
            , "  fscanf(fp, \"%lf\", " ++ address ++ " + i);"
            , "}"
            , "fclose(fp);"
            ]
    readFileHD5 fileName =
        scoped
            [ "printf(\"Reading " ++
              dataset ++ " from HDF5 file " ++ fileName ++ "....\\n\");"
            , "hid_t file, dset;"
            , "file = H5Fopen (\"" ++
              fileName ++ "\", H5F_ACC_RDONLY, H5P_DEFAULT);"
            , "dset = H5Dopen (file, \"" ++ dataset ++ "\", H5P_DEFAULT);"
            , "H5Dread (dset, H5T_NATIVE_DOUBLE, H5S_ALL, H5S_ALL, H5P_DEFAULT, " ++
              address ++ ");"
            , "H5Fclose (file);"
            , "H5Dclose (dset);"
            ]

-- |
--
data GenResult
    = Invalid String
    | Success (String -> IO ()) -- Give it the name of the folder of your solver, it will write all the files necessary

-- |
--
generateProblemCode :: ValMaps -> Problem -> GenResult
generateProblemCode valMaps Problem {..}
    | Just errorMsg <- checkError = Invalid errorMsg
    | otherwise =
        Success $ \folder -> do
            let codes =
                    defineStuffs ++
                    constraintCodes ++
                    readVals ++
                    evaluatingCodes ++
                    evaluateObjectiveCodes ++ evaluatePartialDerivatives
            let writeVal (var, val) =
                    unless (null $ valElems val) $ do
                        let str = unwords . map show . valElems $ val
                        writeFile (folder ++ "/" ++ var ++ ".txt") str
            let writeUpperBound var val =
                    unless (null . valElems $ val) $ do
                        let str =
                                unwords . map show . valElems $ val
                            fileName = var ++ "_ub.txt"
                        writeFile (folder ++ "/" ++ fileName) str
            let writeLowerBound var val =
                    unless (null . valElems $ val) $ do
                        let str =
                                unwords . map show . valElems $ val
                            fileName = var ++ "_lb.txt"
                        writeFile (folder ++ "/" ++ fileName) str
            mapM_ writeVal $ Map.toList valMaps
            case constraint of
                NoConstraint -> return ()
                BoxConstraint cnts ->
                    let writeEach cnt = case cnt of
                            BoxLower var val -> writeLowerBound var val
                            BoxUpper var val -> writeUpperBound var val
                            BoxBetween var (val1, val2) ->
                                writeLowerBound var val1 >> writeUpperBound var val2
                     in mapM_ writeEach cnts
            writeFile (folder ++ "/problem.c") $ intercalate "\n" codes
    -- var nodes, can be optimizing variables or fixed values
  where
    vs :: [(String, Int)]
    vs = varNodesWithId expressionMap
    -- check if this name is optimizing variable or fixed value
    isVariable :: String -> Bool
    isVariable v = v `elem` map varName variables
    -- variables we're trying to optimize over
    vars :: [String]
    vars = map varName variables
    -- get shape of an optimizing variable
    variableShape :: String -> Shape
    variableShape name =
        let nId = nodeId . fromJust . find ((== name) . varName) $ variables
         in retrieveShape nId expressionMap
    -- variable we have along with shape 
    varsWithShape = zip vars (map variableShape vars)
    -- size of each variable (product of it's shape)
    variableSizes = map (product . variableShape) vars
    totalVarSize = sum variableSizes
    -- MemMap
    entries = entryMap memMap
    getMemOffset = fst3 . fromJust . flip IM.lookup entries
    -- Check if is variable or a fixed value
    checkError
        | Just var <-
             find (not . (`Map.member` valMaps)) . map varName $ variables =
            Just $ "No initial value for variable " ++ var
        | Just var <- find (not . (`Map.member` valMaps)) . map fst $ vs =
            Just $ "No value provided for fixed parameter " ++ var
        | otherwise
        , let isOk (var, nId) =
                  compatible
                      (retrieveShape nId expressionMap)
                      (fromJust (var `Map.lookup` valMaps))
        , Just (var, shape) <- find (not . isOk) vs =
            Just $
            "variable " ++
            var ++
            "is of shape " ++ show shape ++ " but the value provided is not"
        -- Box constraint
        | BoxConstraint cnts <- constraint
        , any (not . isBox) cnts = Just "constraint(s) is not box-constraint"
        | BoxConstraint cnts <- constraint
        , Just reason <- checkConstraint cnts varsWithShape = Just reason
        -- everything is fine
        | otherwise = Nothing
    variableShapes = map (variableShape . varName) variables
    variableOffsets = map (getMemOffset . nodeId) variables
    partialDerivativeOffsets =
        map (getMemOffset . partialDerivativeId) variables
    objectiveOffset = getMemOffset objectiveId
    -- For both variables and fixed value
    readValCodeEach (var, nId) =
        generateReadValuesCode
            var
            (fromJust $ Map.lookup var valMaps)
            ("ptr + " ++ show offset)
            (product shape)
      where
        offset = memOffset memMap nId LookupR
        shape = retrieveShape nId expressionMap
    objectiveAndGradient = objectiveId : map partialDerivativeId variables
    -- MARK: codes part --
    defineStuffs =
        [ "#include <math.h>"
        , "#include <stdio.h>"
        , "#include <stdlib.h>"
        , "#include \"utils.c\""
        , "#include \"hdf5.h\""
        , ""
        , ""
        , "#define NUM_VARIABLES " ++ show (length variables)
        , "#define NUM_ACTUAL_VARIABLES " ++ show totalVarSize
        , "#define MEM_SIZE " ++ show (totalDoubles memMap)
        , ""
        , ""
        , "const char* var_name[NUM_VARIABLES] = {" ++
          (intercalate ", " . map (show . varName) $ variables) ++ "};"
        , "const int var_num_dim[NUM_VARIABLES] = {" ++
          (intercalate ", " . map (show . length) $ variableShapes) ++ "};"
        , "const int var_shape[NUM_VARIABLES][3] = {" ++
          (intercalate ", " . map toShapeString $ variableShapes) ++ "};"
        , "const int var_size[NUM_VARIABLES] = {" ++
          (intercalate ", " . map show $ variableSizes) ++ "};"
        , "const int var_offset[NUM_VARIABLES] = {" ++
          (intercalate ", " . map show $ variableOffsets) ++ "};"
        , "const int partial_derivative_offset[NUM_VARIABLES] = {" ++
          (intercalate ", " . map show $ partialDerivativeOffsets) ++ "};"
        , "const int objective_offset = " ++ show objectiveOffset ++ ";"
        , "double ptr[MEM_SIZE];"
        , ""
        , ""
        ]
    constraintCodes =
        let varPosition =
                take (length variableSizes) $ scanl (+) 0 variableSizes
            varWithPos = zip vars varPosition
            getPos name = snd . fromJust . find ((== name) . fst) $ varWithPos
            readUpperBoundCode name val =
                generateReadValuesCode
                    (name ++ "_ub")
                    val
                    ("upper_bound + " ++ show (getPos name))
                    (product $ variableShape name)
            readLowerBoundCode name val =
                generateReadValuesCode
                    (name ++ "_lb")
                    val
                    ("lower_bound + " ++ show (getPos name))
                    (product $ variableShape name)
            readBounds =
                case constraint of
                    NoConstraint -> []
                    BoxConstraint cnts ->
                        let readBoundCodeEach cnt =
                                case cnt of
                                    BoxUpper name val ->
                                        readUpperBoundCode name val
                                    BoxLower name val ->
                                        readLowerBoundCode name val
                                    BoxBetween name (val1, val2) ->
                                        readLowerBoundCode name val1 ++
                                        readUpperBoundCode name val2
                                    _ ->
                                        error $ show cnt
                         in concatMap readBoundCodeEach cnts
         in [ "const int bound_pos[NUM_VARIABLES] = {" ++
              (intercalate ", " . map show $ varPosition) ++ "};"
            , "double lower_bound[NUM_ACTUAL_VARIABLES];"
            , "double upper_bound[NUM_ACTUAL_VARIABLES];"
            , ""
            , ""
            ] ++ --
            [ "void read_bounds() {" --
            , "  for (int i = 0; i < NUM_ACTUAL_VARIABLES; i++) {"
            , "    lower_bound[i] = -INFINITY;"
            , "    upper_bound[i] = INFINITY;"
            , "  }"
            ] ++
            space 2 readBounds ++ --
            ["}"]
    readVals =
        ["void read_values() {"] ++ --
        space 2 (concatMap readValCodeEach vs) ++ --
        ["}"]
    evaluatingCodes =
        ["void evaluate_partial_derivatives_and_objective() {"] ++
        space
            2
            (generateEvaluatingCodes
                 memMap
                 (expressionMap, objectiveAndGradient)) ++
        ["}"]
    evaluateObjectiveCodes =
        ["void evaluate_objective() {"] ++
        space 2 (generateEvaluatingCodes memMap (expressionMap, [objectiveId])) ++
        ["}"]
    evaluatePartialDerivatives =
        ["void evaluate_partial_derivatives() {"] ++
        space
            2
            (generateEvaluatingCodes
                 memMap
                 (expressionMap, map partialDerivativeId variables)) ++
        ["}"]

-- | 
--
checkConstraint :: [ConstraintInfo] -> [(String, Shape)] -> Maybe String
checkConstraint cts varsWithShape =
    case mapMaybe validEach cts of
        firstReason:_ -> Just firstReason
        [] -> Nothing
  where
    validEach ct =
        case ct of
            BoxLower var val
                | Just (_, shape) <- find ((== var) . fst) varsWithShape ->
                    if compatible shape val
                        then Nothing
                        else Just $
                             "Bound provided for " ++ var ++ " is invalid"
                | otherwise -> Just $ var ++ " is not variable"
            BoxUpper var val
                | Just (_, shape) <- find ((== var) . fst) varsWithShape ->
                    if compatible shape val
                        then Nothing
                        else Just $
                             "Bound provided for " ++ var ++ " is invalid"
                | otherwise -> Just $ var ++ " is not variable"
            BoxBetween var (val1, val2)
                | Just (_, shape) <- find ((== var) . fst) varsWithShape ->
                    if compatible shape val1 && compatible shape val2
                        then Nothing
                        else Just $
                             "Bound provided for " ++ var ++ " is invalid"
                | otherwise -> Just $ var ++ " is not variable"
            _ -> Nothing

-- | 
--
compatible :: Shape -> Val -> Bool
compatible shape v =
    case (shape, v) of
        ([], VScalar val) -> True
        ([x], V1D arr1d)
            | bounds arr1d == (0, x - 1) -> True
        ([x, y], V2D arr2d)
            | bounds arr2d == ((0, 0), (x - 1, y - 1)) -> True
        ([x, y, z], V3D arr3d)
            | bounds arr3d == ((0, 0, 0), (x - 1, y - 1, z - 1)) -> True
        ([x], V1DFile {}) -> True
        ([x, y], V2DFile {}) -> True
        ([x, y, z], V3DFile {}) -> True
        _ -> False

-- | 
--
toShapeString :: Shape -> String
toShapeString shape
    | length shape < 3 =
        "{" ++
        (intercalate ", " . map show $ shape ++ replicate (3 - length shape) 1) ++
        "}"
    | otherwise = "{" ++ (intercalate ", " . map show $ shape) ++ "}"

instance Show Problem where
    show Problem {..} =
        intercalate "\n" $
        [ "-------------- Objective Function --------------"
        , debugPrint (expressionMap, objectiveId)
        ] ++
        map showPartial variables
      where
        showPartial var =
            intercalate
                "\n"
                [ "----------------∂f/∂" ++ varName var ++ "-------------"
                , debugPrint (expressionMap, partialDerivativeId var)
                ]
