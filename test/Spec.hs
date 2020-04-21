{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}

import qualified CollectSpec
import Commons
import Data.Array.Unboxed as U
import Data.Map (fromList, union)
import Data.Maybe (fromJust)
import qualified Data.Set as Set
import HashedExpression.Derivative
import HashedExpression.Internal.Expression
import HashedExpression.Internal.Normalize
import HashedExpression.Internal.Utils
import HashedExpression.Interp
import HashedExpression.Operation hiding (product, sum)
import qualified HashedExpression.Operation
import HashedExpression.Prettify
import qualified InterpSpec
import qualified NormalizeEval.OneCSpec as OneCSpec
import qualified NormalizeEval.OneRSpec as OneRSpec
import qualified NormalizeEval.ScalarCSpec as ScalarCSpec
import qualified NormalizeEval.ScalarRSpec as ScalarRSpec
import qualified NormalizeSpec
import qualified SolverSpec
import qualified StructureSpec
import Test.Hspec
import Test.Hspec.Runner
import qualified Test1
import qualified Test2
import qualified ToCSpec
import Var

main :: IO ()
main = hspecWith defaultConfig {configQuickCheckMaxSuccess = Just 50} spec

spec :: Spec
spec = do
  describe "HashedSolverSpec" SolverSpec.spec
  describe "NormalizeSpec" NormalizeSpec.spec
  describe "Test1" Test1.spec
  describe "Test2" Test2.spec
  describe "HashedInterpSpec" InterpSpec.spec
  describe "HashedCollectSpec" CollectSpec.spec
  describe "HashedToCSpec" ToCSpec.spec
  describe "StructureSpec" StructureSpec.spec
  describe "NormalizeEval.ScalarRSpec" ScalarRSpec.spec
  describe "NormalizeEval.ScalarCSpec" ScalarCSpec.spec
  describe "NormalizeEval.OneRSpec" OneRSpec.spec
  describe "NormalizeEval.OneCSpec" OneCSpec.spec
