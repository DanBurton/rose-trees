{-# LANGUAGE
    KindSignatures
  , DeriveFunctor
  , DeriveFoldable
  , DeriveTraversable
  , GeneralizedNewtypeDeriving
  , MultiParamTypeClasses
  , FlexibleInstances
  #-}

module Data.Tree.Knuth.Forest where

import Prelude hiding (foldr, elem)
import Data.Monoid hiding ((<>))
import Data.Semigroup
import Data.Foldable hiding (elem)
import Data.Witherable
import Data.Traversable
import qualified Data.Set.Class as Sets
import Control.Applicative
import Control.Monad


-- * Forest

data KnuthForest a = Fork { kNode :: a
                          , kChildren :: KnuthForest a
                          , kSiblings :: KnuthForest a }
                   | Nil
  deriving (Show, Eq, Functor)

-- | Siblings before children
instance Ord a => Ord (KnuthForest a) where
  compare (Fork x xc xs) (Fork y yc ys) =
    compare x y <> compare xs ys <> compare xc yc
  compare Nil Nil = EQ
  compare Nil _ = LT
  compare _ Nil = GT

-- TODO:
-- Data.Set.Class instances
-- isSubtreeOf, etc.

-- | Zippy
instance Applicative KnuthForest where
  pure x = Fork x Nil Nil
  Nil <*> _ = Nil
  _ <*> Nil = Nil
  (Fork f fc fs) <*> (Fork x xc xs) =
    Fork (f x) (fc <*> xc) (fs <*> xs)

instance Alternative KnuthForest where
  empty = Nil
  (<|>) = union

-- | Breadth-first
instance Monad KnuthForest where
  return x = Fork x Nil Nil
  Nil >>= _ = Nil
  (Fork x xc xs) >>= f = f x `union` (xs >>= f) `union` (xc >>= f)

instance MonadPlus KnuthForest where
  mzero = Nil
  mplus = union

instance Semigroup (KnuthForest a) where
  (<>) = union

instance Monoid (KnuthForest a) where
  mempty = Nil
  mappend = union

-- | Breadth-first
instance Foldable KnuthForest where
  foldr _ acc Nil = acc
  foldr f acc (Fork x xc xs) =
    foldr f (foldr f (f x acc) xs) xc

instance Traversable KnuthForest where
  sequenceA Nil = pure Nil
  sequenceA (Fork x xc xs) = liftA3 Fork x (sequenceA xc) (sequenceA xs)

instance Witherable KnuthForest where
  catMaybes Nil = Nil
  catMaybes (Fork mx xc xs) = case mx of
    Nothing -> Nil
    Just x -> Fork x (catMaybes xc) (catMaybes xs)

instance Sets.HasUnion (KnuthForest a) where
  union = union

instance Eq a => Sets.HasIntersection (KnuthForest a) where
  intersection = intersection

instance Eq a => Sets.HasDifference (KnuthForest a) where
  difference = difference

instance Sets.HasSize (KnuthForest a) where
  size = size

instance Sets.HasEmpty (KnuthForest a) where
  empty = Nil

instance Sets.HasSingleton a (KnuthForest a) where
  singleton = singleton

instance Eq a => Sets.HasDelete a (KnuthForest a) where
  delete = delete

-- ** Query

size :: KnuthForest a -> Int
size Nil = 0
size (Fork _ xc xs) = 1 + size xc + size xs

-- Breadth-first
elem :: Eq a => a -> KnuthForest a -> Bool
elem _ Nil = False
elem x (Fork y yc ys) = x == y || elem x ys || elem x yc

-- Top-down, breadth-first
isSubforestOf :: Eq a => KnuthForest a -> KnuthForest a -> Bool
isSubforestOf Nil _ = True
isSubforestOf xss yss@(Fork _ yc ys) =
  xss == yss || isSubforestOf xss ys || isSubforestOf xss yc
isSubforestOf _ Nil = False

-- Bottom-up, depth-first
isSubforestOf' :: Eq a => KnuthForest a -> KnuthForest a -> Bool
isSubforestOf' Nil _ = True
isSubforestOf' xss yss@(Fork _ yc ys) =
  isSubforestOf xss yc || isSubforestOf xss ys || xss == yss
isSubforestOf' _ Nil = False

-- | No siblings
isProperSubforestOf :: Eq a => KnuthForest a -> KnuthForest a -> Bool
isProperSubforestOf Nil _ = True
isProperSubforestOf xss (Fork _ yc _) = isSubforestOf xss yc
isProperSubforestOf _ Nil = False

-- | Depth-first
isProperSubforestOf' :: Eq a => KnuthForest a -> KnuthForest a -> Bool
isProperSubforestOf' Nil _ = True
isProperSubforestOf' xss (Fork _ yc _) = isSubforestOf' xss yc
isProperSubforestOf' _ Nil = False

isSiblingOf :: Eq a => a -> KnuthForest a -> Bool
isSiblingOf _ Nil = False
isSiblingOf x (Fork y _ ys) = x == y || isSiblingOf x ys

-- | depth of one
isChildOf :: Eq a => a -> KnuthForest a -> Bool
isChildOf _ Nil = False
isChildOf x (Fork _ yc ys) = isSiblingOf x yc || isChildOf x ys


isDescendantOf :: Eq a => a -> KnuthForest a -> Bool
isDescendantOf _ Nil = False
isDescendantOf x (Fork y yc _) = x == y || isDescendantOf x yc

isProperDescendantOf :: Eq a => a -> KnuthForest a -> Bool
isProperDescendantOf _ Nil = False
isProperDescendantOf x (Fork _ yc _) = isDescendantOf x yc


-- ** Construction

singleton :: a -> KnuthForest a
singleton x = Fork x Nil Nil

delete :: Eq a => a -> KnuthForest a -> KnuthForest a
delete _ Nil = Nil
delete x (Fork y yc ys) | x == y = Nil
                        | otherwise = Fork y (delete x yc) (delete x ys)

-- ** Combination

union :: KnuthForest a -> KnuthForest a -> KnuthForest a
union Nil y = y
union (Fork x xc Nil) y = Fork x xc y
union (Fork x xc xs) y = Fork x xc $ union xs y

intersection :: Eq a => KnuthForest a -> KnuthForest a -> KnuthForest a
intersection Nil _ = Nil
intersection _ Nil = Nil
intersection (Fork x xc xs) (Fork y yc ys)
  | x == y = Fork y (intersection xc yc) (intersection xs ys)
  | otherwise = Nil

-- | Removes the possible subtree on the right, from the left.
difference :: Eq a => KnuthForest a -> KnuthForest a -> KnuthForest a
difference Nil _ = Nil
difference x Nil = x
difference (Fork x xc xs) yss@(Fork y _ _)
  | x == y = Nil
  | otherwise = Fork x (difference xc yss) (difference xs yss)
