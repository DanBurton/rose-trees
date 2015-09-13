module Data.Tree.Set where

import Prelude hiding (map, elem, filter)
import qualified Data.Set as Set
import qualified Data.Foldable as F
import qualified Data.Maybe as M
import Data.Monoid
import Control.Monad


data SetTree a = SetTree
  { sNode     :: a
  , sChildren :: Set.Set (SetTree a)
  } deriving (Show, Eq, Ord)

-- * Query

-- | set-like alias for @isDescendantOf@.
elem :: Eq a => a -> SetTree a -> Bool
elem = isDescendantOf

isChildOf :: Eq a => a -> SetTree a -> Bool
isChildOf x (SetTree _ ys) =
  getAny $ F.foldMap (Any . (x ==) . sNode) ys

isDescendantOf :: Eq a => a -> SetTree a -> Bool
isDescendantOf x (SetTree y ys) =
  (x == y) || getAny (F.foldMap (Any . isDescendantOf x) ys)

-- | Heirarchical analogue to subseteq.
isSubtreeOf :: Eq a => SetTree a -> SetTree a -> Bool
isSubtreeOf xss yss@(SetTree _ ys) =
  xss == yss || getAny (F.foldMap (Any . isSubtreeOf xss) ys)

-- | Bottom-up version
isSubtreeOf' :: Eq a => SetTree a -> SetTree a -> Bool
isSubtreeOf' xss yss@(SetTree _ ys) =
  getAny (F.foldMap (Any . isSubtreeOf' xss) ys) || xss == yss

isProperSubtreeOf :: Eq a => SetTree a -> SetTree a -> Bool
isProperSubtreeOf xss (SetTree _ ys) =
  getAny $ F.foldMap (Any . isSubtreeOf xss) ys

-- | Bottom-up version
isProperSubtreeOf' :: Eq a => SetTree a -> SetTree a -> Bool
isProperSubtreeOf' xss (SetTree _ ys) =
  getAny $ F.foldMap (Any . isSubtreeOf' xss) ys

eqHead :: Eq a => SetTree a -> SetTree a -> Bool
eqHead (SetTree x _) (SetTree y _) = x == y

-- * Construction

insertChild :: Ord a => SetTree a -> SetTree a -> SetTree a
insertChild x (SetTree y ys) = SetTree y $ Set.insert x ys

delete :: Eq a => a -> SetTree a -> Maybe (SetTree a)
delete x = filter (/= x)

singleton :: a -> SetTree a
singleton x = SetTree x Set.empty

-- * Combination

-- -- | Prefer the second
-- union :: Ord a => SetTree a -> SetTree a -> SetTree a
-- union (SetTree _ xs) (SetTree y ys)
--   | xs == Set.empty = SetTree y ys
--   | ys == Set.empty = SetTree y xs
--   | otherwise = SetTree y $ childs xs ys
--   where
--     childs :: Ord a => Set.Set (SetTree a) -> Set.Set (SetTree a) -> Set.Set (SetTree a)
--     childs xs ys = Set.fromList $ F.foldr go (Set.toList xs) (Set.toList ys)
--       where go y@(SetTree _ ys) = insertWhen (not . eqHead y) y (`childs` ys)
--             insertWhen _ i _ [] = [i]
--             insertWhen p i h (x@(SetTree x' xs'):xs)
--               | p x = x:insertWhen p i h xs
--               | otherwise = SetTree x' (h xs'):xs
--
-- intersection :: Ord a => SetTree a -> SetTree a -> Maybe (SetTree a)
-- intersection (SetTree x xs) (SetTree y ys) = do
--   guard $ x == y
--   let xs' = Set.toAscList xs
--       ys' = Set.toAscList ys
--   return $ SetTree y $ Set.fromAscList $ same xs' ys'
--   where same [] _ = []
--         same _ [] = []
--         same (x:xs) (y:ys) | x < y = same xs (y:ys)
--                            | x > y = same (x:xs) ys
--                            | otherwise = x : same xs ys

-- difference :: SetTree a -> SetTree a -> SetTree a

-- * Filtering

filter :: Eq a => (a -> Bool) -> SetTree a -> Maybe (SetTree a)
filter p (SetTree x xs) = do
  guard $ p x
  return $ SetTree x $ Set.fromAscList $ M.mapMaybe (filter p) $ Set.toAscList xs

-- * Mapping

map :: Ord b => (a -> b) -> SetTree a -> SetTree b
map f (SetTree x xs) = SetTree (f x) $ Set.map (map f) xs

mapMaybe :: Eq b => (a -> Maybe b) -> SetTree a -> Maybe (SetTree b)
mapMaybe p (SetTree x xs) = do
  x' <- p x
  return $ SetTree x' $ Set.fromAscList $ M.mapMaybe (mapMaybe p) $ Set.toAscList xs
