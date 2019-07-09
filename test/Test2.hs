module Test2 where
import Commons
import Data.Maybe (fromJust)
import HashedExpression
import HashedOperation hiding (product, sum)
import qualified HashedOperation
import HashedPrettify
import HashedSimplify
import HashedVar
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
    , sum
    , tan
    , tanh
    )
import Test.Hspec

spec :: Spec
spec = describe "Simplify spec" $ do
          specify "simplify scalar one zero" $ do
              x `shouldBe` x
              simplify ((x*y*z)^2) `shouldBe` simplify (x^2*y^2*z^2)
              simplify (x*.y+x*.z) `shouldBe` simplify x*(y+z)