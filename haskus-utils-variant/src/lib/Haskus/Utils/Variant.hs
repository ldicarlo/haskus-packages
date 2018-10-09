{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ViewPatterns #-}

-- | Open sum type
module Haskus.Utils.Variant
   ( V (..)
   , variantIndex
   -- * Patterns
   , pattern V
   , pattern VMaybe
   , (:<)
   , (:<?)
   -- * Operations by index
   , toVariantAt
   , toVariantHead
   , toVariantTail
   , fromVariantAt
   , popVariantAt
   , popVariantHead
   , mapVariantAt
   , mapVariantAtM
   , foldMapVariantAt
   , foldMapVariantAtM
   -- * Operations by type
   , toVariant
   , Member
   , Filter
   , popVariant
   , popVariantMaybe
   , fromVariant
   , fromVariantMaybe
   , fromVariantFirst
   , mapVariantFirst
   , mapVariantFirstM
   , ReplaceAll
   , MapVariant
   , mapVariant
   , mapNubVariant
   , foldMapVariantFirst
   , foldMapVariantFirstM
   , foldMapVariant
   -- * Generic operations with type classes
   , NoConstraint
   , AlterVariant
   , alterVariant
   , TraverseVariant
   , traverseVariant
   , traverseVariant_
   , ReduceVariant
   , reduceVariant
   -- * Conversions between variants
   , appendVariant
   , prependVariant
   , Liftable
   , liftVariant
   , nubVariant
   , productVariant
   , Flattenable
   , FlattenVariant
   , flattenVariant
   , ExtractM
   , joinVariant
   , joinVariantUnsafe
   , JoinVariant
   , splitVariant
   , SplitVariant
   -- * Conversions to/from other data types
   , variantToValue
   , variantFromValue
   , variantToEither
   , variantFromEither
   , variantToHList
   , variantToTuple
   -- ** Continuations
   , ContVariant (..)
   -- ** Internals
   , pattern VSilent
   , liftVariant'
   , fromVariant'
   , popVariant'
   , toVariant'
   , LiftVariant
   , PopVariant
   )
where

import Unsafe.Coerce
import GHC.Exts (Any)
import Data.Typeable

import Haskus.Utils.Monad
import Haskus.Utils.Types
import Haskus.Utils.Tuple
import Haskus.Utils.HList
import Haskus.Utils.ContFlow
import Haskus.Utils.Types.List

-- | A variant contains a value whose type is at the given position in the type
-- list
data V (l :: [*]) = Variant {-# UNPACK #-} !Word Any

-- Make GHC consider `l` as a representational parameter to make coercions
-- between Variant values unsafe
type role V representational

-- | Pattern synonym for Variant
--
-- Usage: case v of
--          V (x :: Int)    -> ...
--          V (x :: String) -> ...
pattern V :: forall c cs. (c :< cs) => c -> V cs
pattern V x <- (fromVariant -> Just x)
   where
      V x = toVariant x

-- | Silent pattern synonym for Variant
--
-- Usage: case v of
--          VSilent (x :: Int)    -> ...
--          VSilent (x :: String) -> ...
pattern VSilent :: forall c cs.
   ( Member' c cs
   , PopVariant c cs
   ) => c -> V cs
pattern VSilent x <- (fromVariant' -> Just x)
   where
      VSilent x = toVariant' x

-- | Statically unchecked matching on a Variant
pattern VMaybe :: forall c cs. (c :<? cs) => c -> V cs
pattern VMaybe x <- (fromVariantMaybe -> Just x)

instance Eq (V '[]) where
   (==) _ _ = True

instance
   ( Eq (V xs)
   , Eq x
   ) => Eq (V (x ': xs))
   where
      {-# INLINE (==) #-}
      (==) v1@(Variant t1 _) v2@(Variant t2 _)
         | t1 /= t2  = False
         | otherwise = case (popVariantHead v1, popVariantHead v2) of
            (Right a, Right b) -> a == b
            (Left as, Left bs) -> as == bs
            _                  -> False

instance Ord (V '[]) where
   compare = error "Empty variant"

instance
   ( Ord (V xs)
   , Ord x
   ) => Ord (V (x ': xs))
   where
      compare v1 v2 = case (popVariantHead v1, popVariantHead v2) of
         (Right a, Right b) -> compare a b
         (Left as, Left bs) -> compare as bs
         (Right _, Left _)  -> LT
         (Left _, Right _)  -> GT

instance Show (V '[]) where
   show _ = "V '[]"

instance
   ( Show (V xs)
   , Show x
   , Typeable x
   ) => Show (V (x ': xs))
   where
      show v = case popVariantHead v of
         Right x -> let parens s
                           | ' ' `elem` s = "(" ++ s ++ ")"
                           | otherwise    = s
                        -- naive parenthesing but it works
                     in "V @" ++ parens (show (typeOf x)) ++ " " ++ parens (show x)
         Left xs -> show xs

-----------------------------------------------------------
-- Operations by index
-----------------------------------------------------------

-- | Get Variant index
variantIndex :: V a -> Word
variantIndex (Variant n _) = n

-- | Set the value with the given indexed type
toVariantAt :: forall (n :: Nat) (l :: [*]).
   ( KnownNat n
   ) => Index n l -> V l
{-# INLINABLE toVariantAt #-}
toVariantAt a = Variant (natValue' @n) (unsafeCoerce a)

-- | Set the first value
toVariantHead :: forall x xs. x -> V (x ': xs)
{-# INLINABLE toVariantHead #-}
toVariantHead a = Variant 0 (unsafeCoerce a)

-- | Set the tail
toVariantTail :: forall x xs. V xs -> V (x ': xs)
{-# INLINABLE toVariantTail #-}
toVariantTail (Variant t a) = Variant (t+1) a

-- | Get the value if it has the indexed type
fromVariantAt :: forall (n :: Nat) (l :: [*]).
   ( KnownNat n
   ) => V l -> Maybe (Index n l)
{-# INLINABLE fromVariantAt #-}
fromVariantAt (Variant t a) = do
   guard (t == natValue' @n)
   return (unsafeCoerce a) -- we know it is the effective type

-- | Pop a variant value by index, return either the value or the remaining
-- variant
popVariantAt :: forall (n :: Nat) l. 
   ( KnownNat n
   ) => V l -> Either (V (RemoveAt n l)) (Index n l)
{-# INLINABLE popVariantAt #-}
popVariantAt v@(Variant t a) = case fromVariantAt @n v of
   Just x  -> Right x
   Nothing -> Left $ if t > natValue' @n
      then Variant (t-1) a
      else Variant t a

-- | Pop the head of a variant value
popVariantHead :: forall x xs. V (x ': xs) -> Either (V xs) x
{-# INLINABLE popVariantHead #-}
popVariantHead v@(Variant t a) = case fromVariantAt @0 v of
   Just x  -> Right x
   Nothing -> Left $ Variant (t-1) a

-- | Update a single variant value by index
mapVariantAt :: forall (n :: Nat) a b l.
   ( KnownNat n
   , a ~ Index n l
   ) => (a -> b) -> V l -> V (ReplaceN n b l)
{-# INLINABLE mapVariantAt #-}
mapVariantAt f v@(Variant t a) =
   case fromVariantAt @n v of
      Nothing -> Variant t a
      Just x  -> Variant t (unsafeCoerce (f x))

-- | Applicative update of a single variant value by index
mapVariantAtM :: forall (n :: Nat) a b l m .
   ( KnownNat n
   , Applicative m
   , a ~ Index n l
   )
   => (a -> m b) -> V l -> m (V (ReplaceN n b l))
{-# INLINABLE mapVariantAtM #-}
mapVariantAtM f v@(Variant t a) =
   case fromVariantAt @n v of
      Nothing -> pure (Variant t a)
      Just x  -> Variant t <$> unsafeCoerce (f x)

-----------------------------------------------------------
-- Operations by type
-----------------------------------------------------------

-- | Put a value into a Variant
--
-- Use the first matching type index.
toVariant :: forall a l.
   ( Member a l
   ) => a -> V l
{-# INLINABLE toVariant #-}
toVariant = toVariantAt @(IndexOf a l)

-- | Put a value into a Variant (silent)
--
-- Use the first matching type index.
toVariant' :: forall a l.
   ( Member' a l
   ) => a -> V l
{-# INLINABLE toVariant' #-}
toVariant' = toVariantAt @(IndexOf a l)

class PopVariant a xs where
   -- | Remove a type from a variant
   popVariant' :: V xs -> Either (V (Filter a xs)) a

instance PopVariant a '[] where
   {-# INLINE popVariant' #-}
   popVariant' _ = undefined

instance forall a xs n xs' y ys.
      ( PopVariant a xs'
      , n ~ MaybeIndexOf a xs
      , xs' ~ RemoveAt1 n xs
      , Filter a xs' ~ Filter a xs
      , KnownNat n
      , xs ~ (y ': ys)
      ) => PopVariant a (y ': ys)
   where
      {-# INLINE popVariant' #-}
      popVariant' (Variant t a)
         = case natValue' @n of
            0             -> Left (Variant t a) -- no 'a' left in xs
            n | n-1 == t  -> Right (unsafeCoerce a)
              | n-1 < t   -> popVariant' @a @xs' (Variant (t-1) a)
              | otherwise -> Left (Variant t a)

class SplitVariant as rs xs where
   splitVariant' :: V xs -> Either (V as) (V (Complement rs as))

instance SplitVariant as rs '[] where
   {-# INLINE splitVariant' #-}
   splitVariant' _ = undefined

instance forall as rs xs x n m.
   ( n ~ MaybeIndexOf x as
   , m ~ IndexOf x rs
   , SplitVariant as rs xs
   , KnownNat m
   , KnownNat n
   ) => SplitVariant as rs (x ': xs)
   where
      {-# INLINE splitVariant' #-}
      splitVariant' (Variant 0 v)
         = case natValue' @n of
            0 -> Right (Variant (natValue' @m) v)
            t -> Left (Variant (t-1) v)
      splitVariant' (Variant t v)
         = splitVariant' @as @rs (Variant (t-1) v :: V xs)

-- | Split a variant in two
splitVariant :: forall as xs.
   ( SplitVariant as xs xs
   ) => V xs -> Either (V as) (V (Complement xs as))
splitVariant = splitVariant' @as @xs

-- | A value of type "x" can be extracted from (V xs)
type (:<) x xs =
   ( Member x xs
   , x :<? xs
   )

-- | A value of type "x" **might** be extracted from (V xs).
-- We don't check that "x" is in "xs".
type (:<?) x xs =
   ( PopVariant x xs
   )

-- | Extract a type from a variant. Return either the value of this type or the
-- remaining variant
popVariant :: forall a xs.
   ( a :< xs
   ) => V xs -> Either (V (Filter a xs)) a
{-# INLINABLE popVariant #-}
popVariant v = popVariant' @a v

-- | Extract a type from a variant. Return either the value of this type or the
-- remaining variant
popVariantMaybe :: forall a xs.
   ( a :<? xs
   ) => V xs -> Either (V (Filter a xs)) a
{-# INLINABLE popVariantMaybe #-}
popVariantMaybe v = popVariant' @a v

-- | Pick the first matching type of a Variant
--
-- fromVariantFirst @A (Variant 2 undefined :: V '[A,B,A]) == Nothing
fromVariantFirst :: forall a l.
   ( Member a l
   ) => V l -> Maybe a
{-# INLINABLE fromVariantFirst #-}
fromVariantFirst = fromVariantAt @(IndexOf a l)

-- | Try to a get a value of a given type from a Variant
fromVariant :: forall a xs.
   ( a :< xs
   ) => V xs -> Maybe a
{-# INLINABLE fromVariant #-}
fromVariant v = case popVariant v of
   Right a -> Just a
   Left _  -> Nothing

-- | Try to a get a value of a given type from a Variant (silent)
fromVariant' :: forall a xs.
   ( PopVariant a xs
   ) => V xs -> Maybe a
{-# INLINABLE fromVariant' #-}
fromVariant' v = case popVariant' v of
   Right a -> Just a
   Left _  -> Nothing

-- | Try to a get a value of a given type from a Variant that may not even
-- support the given type.
fromVariantMaybe :: forall a xs.
   ( a :<? xs
   ) => V xs -> Maybe a
{-# INLINABLE fromVariantMaybe #-}
fromVariantMaybe v = case popVariantMaybe v of
   Right a -> Just a
   Left _  -> Nothing

-- | Update of the first matching variant value
mapVariantFirst :: forall a b n l.
   ( Member a l
   , n ~ IndexOf a l
   ) => (a -> b) -> V l -> V (ReplaceN n b l)
{-# INLINABLE mapVariantFirst #-}
mapVariantFirst f v = mapVariantAt @n f v

-- | Applicative update of the first matching variant value
mapVariantFirstM :: forall a b n l m.
   ( Member a l
   , n ~ IndexOf a l
   , Applicative m
   ) => (a -> m b) -> V l -> m (V (ReplaceN n b l))
{-# INLINABLE mapVariantFirstM #-}
mapVariantFirstM f v = mapVariantAtM @n f v

class MapVariantIndexes a b cs (is :: [Nat]) where
   mapVariant' :: (a -> b) -> V cs -> V (ReplaceNS is b cs)

instance MapVariantIndexes a b '[] is where
   {-# INLINE mapVariant' #-}
   mapVariant' = undefined

instance MapVariantIndexes a b cs '[] where
   {-# INLINE mapVariant' #-}
   mapVariant' _ v = v

instance forall a b cs is i.
   ( MapVariantIndexes a b (ReplaceN i b cs) is
   , a ~ Index i cs
   , KnownNat i
   ) => MapVariantIndexes a b cs (i ': is) where
   {-# INLINE mapVariant' #-}
   mapVariant' f v = mapVariant' @a @b @(ReplaceN i b cs) @is f (mapVariantAt @i f v)

type MapVariant a b cs =
   ( MapVariantIndexes a b cs (IndexesOf a cs)
   )

type ReplaceAll a b cs = ReplaceNS (IndexesOf a cs) b cs


-- | Map the matching types of a variant
mapVariant :: forall a b cs.
   ( MapVariant a b cs
   ) => (a -> b) -> V cs -> V (ReplaceAll a b cs)
{-# INLINABLE mapVariant #-}
mapVariant = mapVariant' @a @b @cs @(IndexesOf a cs)

-- | Map the matching types of a variant and nub the result
mapNubVariant :: forall a b cs ds rs.
   ( MapVariant a b cs
   , ds ~ ReplaceNS (IndexesOf a cs) b cs
   , rs ~ Nub ds
   , Liftable ds rs
   ) => (a -> b) -> V cs -> V rs
{-# INLINABLE mapNubVariant #-}
mapNubVariant f = nubVariant . mapVariant f


-- | Update a variant value with a variant and fold the result
foldMapVariantAt :: forall (n :: Nat) l l2 .
   ( KnownNat n
   , KnownNat (Length l2)
   ) => (Index n l -> V l2) -> V l -> V (ReplaceAt n l l2)
foldMapVariantAt f v@(Variant t a) =
   case fromVariantAt @n v of
      Nothing ->
         -- we need to adapt the tag if new valid tags (from l2) are added before
         if t < n
            then Variant t a
            else Variant (t+nl2-1) a

      Just x  -> case f x of
         Variant t2 a2 -> Variant (t2+n) a2
   where
      n   = natValue' @n
      nl2 = natValue' @(Length l2)

-- | Update a variant value with a variant and fold the result
foldMapVariantAtM :: forall (n :: Nat) m l l2.
   ( KnownNat n
   , KnownNat (Length l2)
   , Monad m
   ) => (Index n l -> m (V l2)) -> V l -> m (V (ReplaceAt n l l2))
foldMapVariantAtM f v@(Variant t a) =
   case fromVariantAt @n v of
      Nothing ->
         -- we need to adapt the tag if new valid tags (from l2) are added before
         return $ if t < n
            then Variant t a
            else Variant (t+nl2-1) a

      Just x  -> do
         y <- f x
         case y of
            Variant t2 a2 -> return (Variant (t2+n) a2)
   where
      n   = natValue' @n
      nl2 = natValue' @(Length l2)

-- | Update a variant value with a variant and fold the result
foldMapVariantFirst :: forall a (n :: Nat) l l2 .
   ( KnownNat n
   , KnownNat (Length l2)
   , n ~ IndexOf a l
   , a ~ Index n l
   ) => (a -> V l2) -> V l -> V (ReplaceAt n l l2)
foldMapVariantFirst f v = foldMapVariantAt @n f v

-- | Update a variant value with a variant and fold the result
foldMapVariantFirstM :: forall a (n :: Nat) l l2 m.
   ( KnownNat n
   , KnownNat (Length l2)
   , n ~ IndexOf a l
   , a ~ Index n l
   , Monad m
   ) => (a -> m (V l2)) -> V l -> m (V (ReplaceAt n l l2))
foldMapVariantFirstM f v = foldMapVariantAtM @n f v



-- | Update a variant value with a variant and fold the result
foldMapVariant :: forall a cs ds i.
   ( i ~ IndexOf a cs
   , a :< cs
   ) => (a -> V ds) -> V cs -> V (InsertAt i (Filter a cs) ds)
foldMapVariant f v = case popVariant v of
   Right a -> case f a of
      Variant t x -> Variant (i + t) x
   Left (Variant t x)
      | t < i     -> Variant t x
      | otherwise -> Variant (i+t) x
   where
      i = natValue' @i




-----------------------------------------------------------
-- Generic operations with type classes
-----------------------------------------------------------

-- | Useful to specify a "* -> Constraint" function returning an empty constraint
class NoConstraint a
instance NoConstraint a

class AlterVariant c (b :: [*]) where
   alterVariant' :: (forall a. c a => a -> a) -> Word -> Any -> Any

instance AlterVariant c '[] where
   {-# INLINE alterVariant' #-}
   alterVariant' _ = undefined

instance
   ( AlterVariant c xs
   , c x
   ) => AlterVariant c (x ': xs)
   where
      {-# INLINE alterVariant' #-}
      alterVariant' f t v =
         case t of
            0 -> unsafeCoerce (f (unsafeCoerce v :: x))
            n -> alterVariant' @c @xs f (n-1) v

-- | Alter a variant. You need to specify the constraints required by the
-- modifying function.
--
-- Usage:
--    alterVariant @NoConstraint id         v
--    alterVariant @Resizable    (resize 4) v
--
--
--    -- Multiple constraints:
--    class (Ord a, Num a) => OrdNum a
--    instance (Ord a, Num a) => OrdNum a
--    alterVariant @OrdNum foo v
--
alterVariant :: forall c (a :: [*]).
   ( AlterVariant c a
   ) => (forall x. c x => x -> x) -> V a  -> V a
{-# INLINABLE alterVariant #-}
alterVariant f (Variant t a) = 
   Variant t (alterVariant' @c @a f t a)




class TraverseVariant c (b :: [*]) m where
   traverseVariant' :: (forall a . (Monad m, c a) => a -> m a) -> Word -> Any -> m Any

instance TraverseVariant c '[] m where
   {-# INLINE traverseVariant' #-}
   traverseVariant' _ = undefined

instance
   ( TraverseVariant c xs m
   , c x
   , Monad m
   ) => TraverseVariant c (x ': xs) m
   where
      {-# INLINE traverseVariant' #-}
      traverseVariant' f t v =
         case t of
            0 -> unsafeCoerce <$> f (unsafeCoerce v :: x)
            n -> traverseVariant' @c @xs f (n-1) v


-- | Traverse a variant. You need to specify the constraints required by the
-- modifying function.
traverseVariant :: forall c (a :: [*]) m.
   ( TraverseVariant c a m
   , Monad m
   ) => (forall x. c x => x -> m x) -> V a  -> m (V a)
{-# INLINABLE traverseVariant #-}
traverseVariant f (Variant t a) = 
   Variant t <$> traverseVariant' @c @a f t a

-- | Traverse a variant. You need to specify the constraints required by the
-- modifying function.
traverseVariant_ :: forall c (a :: [*]) m.
   ( TraverseVariant c a m
   , Monad m
   ) => (forall x. c x => x -> m ()) -> V a -> m ()
{-# INLINABLE traverseVariant_ #-}
traverseVariant_ f v = void (traverseVariant @c @a f' v)
   where
      f' :: forall x. c x => x -> m x
      f' x = f x >> return x



class ReduceVariant c r (b :: [*]) where
   reduceVariant' :: (forall a. c a => a -> r) -> Word -> Any -> r

instance ReduceVariant c r '[] where
   {-# INLINE reduceVariant' #-}
   reduceVariant' _ = undefined

instance
   ( ReduceVariant c r xs
   , c x
   ) => ReduceVariant c r (x ': xs)
   where
      {-# INLINE reduceVariant' #-}
      reduceVariant' f t v =
         case t of
            0 -> f (unsafeCoerce v :: x)
            n -> reduceVariant' @c @r @xs f (n-1) v

-- | Reduce a variant to a single value by using a class function. You need to
-- specify the constraints required by the modifying function.
--
-- Usage:
--    reduceVariant @Show show v
--
reduceVariant :: forall c r (a :: [*]).
   ( ReduceVariant c r a
   ) => (forall x. c x => x -> r) -> V a  -> r
{-# INLINABLE reduceVariant #-}
reduceVariant f (Variant t a) = reduceVariant' @c @r @a f t a


-----------------------------------------------------------
-- Conversions between variants
-----------------------------------------------------------

-- | Extend a variant by appending other possible values
appendVariant :: forall (ys :: [*]) (xs :: [*]). V xs -> V (Concat xs ys)
{-# INLINABLE appendVariant #-}
appendVariant (Variant t a) = Variant t a

-- | Extend a variant by prepending other possible values
prependVariant :: forall (ys :: [*]) (xs :: [*]).
   ( KnownNat (Length ys)
   ) => V xs -> V (Concat ys xs)
{-# INLINABLE prependVariant #-}
prependVariant (Variant t a) = Variant (n+t) a
   where
      n = natValue' @(Length ys)

-- | xs is liftable in ys
type Liftable xs ys =
   ( IsSubset xs ys ~ 'True
   , LiftVariant xs ys
   )

class LiftVariant xs ys where
   liftVariant' :: V xs -> V ys

instance LiftVariant '[] ys where
   {-# INLINE liftVariant' #-}
   liftVariant' _ = undefined

instance forall xs ys x.
      ( LiftVariant xs ys
      , KnownNat (IndexOf x ys)
      ) => LiftVariant (x ': xs) ys
   where
      {-# INLINE liftVariant' #-}
      liftVariant' (Variant t a)
         | t == 0    = Variant (natValue' @(IndexOf x ys)) a
         | otherwise = liftVariant' @xs (Variant (t-1) a)


-- | Lift a variant into another
--
-- Set values to the first matching type
liftVariant :: forall ys xs.
   ( Liftable xs ys
   ) => V xs -> V ys
{-# INLINABLE liftVariant #-}
liftVariant = liftVariant'

-- | Nub the type list
nubVariant :: (Liftable xs (Nub xs)) => V xs -> V (Nub xs)
{-# INLINABLE nubVariant #-}
nubVariant = liftVariant

-- | Product of two variants
productVariant :: forall xs ys.
   ( KnownNat (Length ys)
   ) => V xs -> V ys -> V (Product xs ys)
{-# INLINABLE productVariant #-}
productVariant (Variant n1 a1) (Variant n2 a2)
   = Variant (n1 * natValue @(Length ys) + n2) (unsafeCoerce (a1,a2))

type family FlattenVariant (xs :: [*]) :: [*] where
   FlattenVariant '[]       = '[]
   FlattenVariant (V xs:ys) = Concat xs (FlattenVariant ys)
   FlattenVariant (y:ys)    = y ': FlattenVariant ys

class Flattenable a rs where
   toFlattenVariant :: Word -> a -> rs

instance Flattenable (V '[]) rs where
   {-# INLINE toFlattenVariant #-}
   toFlattenVariant _ _ = undefined

instance forall xs ys rs.
   ( Flattenable (V ys) (V rs)
   , KnownNat (Length xs)
   ) => Flattenable (V (V xs ': ys)) (V rs)
   where
   {-# INLINE toFlattenVariant #-}
   toFlattenVariant i v = case popVariantHead v of
      Right (Variant n a) -> Variant (i+n) a
      Left vys            -> toFlattenVariant (i+natValue @(Length xs)) vys

-- | Flatten variants in a variant
flattenVariant :: forall xs.
   ( Flattenable (V xs) (V (FlattenVariant xs))
   ) => V xs -> V (FlattenVariant xs)
{-# INLINABLE flattenVariant #-}
flattenVariant v = toFlattenVariant 0 v

type family ExtractM m f where
   ExtractM m '[]         = '[]
   ExtractM m (m x ': xs) = x ': ExtractM m xs

class JoinVariant m xs where
   -- | Join on a variant
   --
   -- Transform a variant of applicatives as follow:
   --    f :: V '[m a, m b, m c] -> m (V '[a,b,c])
   --    f = joinVariant @m
   --
   joinVariant :: V xs -> m (V (ExtractM m xs))

instance JoinVariant m '[] where
   {-# INLINE joinVariant #-}
   joinVariant _ = undefined

instance forall m xs a.
   ( Functor m
   , ExtractM m (m a ': xs) ~ (a ': ExtractM m xs)
   , JoinVariant m xs
   ) => JoinVariant m (m a ': xs) where
   {-# INLINE joinVariant #-}
   joinVariant (Variant 0 a) = (Variant 0 . unsafeCoerce) <$> (unsafeCoerce a :: m a)
   joinVariant (Variant n a) = prependVariant @'[a] <$> joinVariant (Variant (n-1) a :: V xs)

-- | Join on a variant in an unsafe way.
--
-- Works with IO for example but not with Maybe.
--
joinVariantUnsafe :: forall m xs ys.
   ( Functor m
   , ys ~ ExtractM m xs
   ) => V xs -> m (V ys)
{-# INLINABLE joinVariantUnsafe #-}
joinVariantUnsafe (Variant t act) = Variant t <$> (unsafeCoerce act :: m Any)



-----------------------------------------------------------
-- Conversions to other data types
-----------------------------------------------------------

-- | Retrieve a single value
variantToValue :: V '[a] -> a
{-# INLINABLE variantToValue #-}
variantToValue (Variant _ a) = unsafeCoerce a

-- | Create a variant from a single value
variantFromValue :: a -> V '[a]
{-# INLINABLE variantFromValue #-}
variantFromValue a = Variant 0 (unsafeCoerce a)


-- | Convert a variant of two values in a Either
variantToEither :: forall a b. V '[a,b] -> Either b a
{-# INLINABLE variantToEither #-}
variantToEither (Variant 0 a) = Right (unsafeCoerce a)
variantToEither (Variant _ a) = Left (unsafeCoerce a)

-- | Lift an Either into a Variant (reversed order by convention)
variantFromEither :: Either a b -> V '[b,a]
{-# INLINABLE variantFromEither #-}
variantFromEither (Left a)  = toVariantAt @1 a
variantFromEither (Right b) = toVariantAt @0 b


class VariantToHList xs where
   -- | Convert a variant into a HList of Maybes
   variantToHList :: V xs -> HList (Map Maybe xs)

instance VariantToHList '[] where
   variantToHList _ = HNil

instance
   ( VariantToHList xs
   ) => VariantToHList (x ': xs)
   where
      variantToHList v@(Variant t a) =
            fromVariantAt @0 v `HCons` variantToHList v'
         where
            v' :: V xs
            v' = Variant (t-1) a

-- | Get variant possible values in a tuple of Maybe types
variantToTuple :: forall l t.
   ( VariantToHList l
   , HTuple' (Map Maybe l) t
   ) => V l -> t
variantToTuple = hToTuple' . variantToHList



class ContVariant xs where
   -- | Convert a variant into a multi-continuation
   variantToCont :: V xs -> ContFlow xs r

   -- | Convert a variant into a multi-continuation
   variantToContM :: Monad m => m (V xs) -> ContFlow xs (m r)

   -- | Convert a multi-continuation into a Variant
   contToVariant :: ContFlow xs (V xs) -> V xs

   -- | Convert a multi-continuation into a Variant
   contToVariantM :: Monad m => ContFlow xs (m (V xs)) -> m (V xs)

instance ContVariant '[a] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant _ a) = ContFlow $ \(Single f) ->
      f (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(Single f) -> do
      Variant _ a <- act
      f (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      Single (toVariantAt @0)

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      Single (return . toVariantAt @0)

instance ContVariant '[a,b] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2) ->
      case t of
         0 -> f1 (unsafeCoerce a)
         _ -> f2 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2) -> do
      Variant t a <- act
      case t of
         0 -> f1 (unsafeCoerce a)
         _ -> f2 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      )

instance ContVariant '[a,b,c] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2,f3) ->
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         _ -> f3 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2,f3) -> do
      Variant t a <- act
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         _ -> f3 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      , toVariantAt @2
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      , return . toVariantAt @2
      )

instance ContVariant '[a,b,c,d] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2,f3,f4) ->
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         _ -> f4 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2,f3,f4) -> do
      Variant t a <- act
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         _ -> f4 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      , toVariantAt @2
      , toVariantAt @3
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      , return . toVariantAt @2
      , return . toVariantAt @3
      )

instance ContVariant '[a,b,c,d,e] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2,f3,f4,f5) ->
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         3 -> f4 (unsafeCoerce a)
         _ -> f5 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2,f3,f4,f5) -> do
      Variant t a <- act
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         3 -> f4 (unsafeCoerce a)
         _ -> f5 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      , toVariantAt @2
      , toVariantAt @3
      , toVariantAt @4
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      , return . toVariantAt @2
      , return . toVariantAt @3
      , return . toVariantAt @4
      )

instance ContVariant '[a,b,c,d,e,f] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2,f3,f4,f5,f6) ->
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         3 -> f4 (unsafeCoerce a)
         4 -> f5 (unsafeCoerce a)
         _ -> f6 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2,f3,f4,f5,f6) -> do
      Variant t a <- act
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         3 -> f4 (unsafeCoerce a)
         4 -> f5 (unsafeCoerce a)
         _ -> f6 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      , toVariantAt @2
      , toVariantAt @3
      , toVariantAt @4
      , toVariantAt @5
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      , return . toVariantAt @2
      , return . toVariantAt @3
      , return . toVariantAt @4
      , return . toVariantAt @5
      )

instance ContVariant '[a,b,c,d,e,f,g] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7) ->
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         3 -> f4 (unsafeCoerce a)
         4 -> f5 (unsafeCoerce a)
         5 -> f6 (unsafeCoerce a)
         _ -> f7 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7) -> do
      Variant t a <- act
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         3 -> f4 (unsafeCoerce a)
         4 -> f5 (unsafeCoerce a)
         5 -> f6 (unsafeCoerce a)
         _ -> f7 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      , toVariantAt @2
      , toVariantAt @3
      , toVariantAt @4
      , toVariantAt @5
      , toVariantAt @6
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      , return . toVariantAt @2
      , return . toVariantAt @3
      , return . toVariantAt @4
      , return . toVariantAt @5
      , return . toVariantAt @6
      )

instance ContVariant '[a,b,c,d,e,f,g,h] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7,f8) ->
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         3 -> f4 (unsafeCoerce a)
         4 -> f5 (unsafeCoerce a)
         5 -> f6 (unsafeCoerce a)
         6 -> f7 (unsafeCoerce a)
         _ -> f8 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7,f8) -> do
      Variant t a <- act
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         3 -> f4 (unsafeCoerce a)
         4 -> f5 (unsafeCoerce a)
         5 -> f6 (unsafeCoerce a)
         6 -> f7 (unsafeCoerce a)
         _ -> f8 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      , toVariantAt @2
      , toVariantAt @3
      , toVariantAt @4
      , toVariantAt @5
      , toVariantAt @6
      , toVariantAt @7
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      , return . toVariantAt @2
      , return . toVariantAt @3
      , return . toVariantAt @4
      , return . toVariantAt @5
      , return . toVariantAt @6
      , return . toVariantAt @7
      )

instance ContVariant '[a,b,c,d,e,f,g,h,i] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7,f8,f9) ->
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         3 -> f4 (unsafeCoerce a)
         4 -> f5 (unsafeCoerce a)
         5 -> f6 (unsafeCoerce a)
         6 -> f7 (unsafeCoerce a)
         7 -> f8 (unsafeCoerce a)
         _ -> f9 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7,f8,f9) -> do
      Variant t a <- act
      case t of
         0 -> f1 (unsafeCoerce a)
         1 -> f2 (unsafeCoerce a)
         2 -> f3 (unsafeCoerce a)
         3 -> f4 (unsafeCoerce a)
         4 -> f5 (unsafeCoerce a)
         5 -> f6 (unsafeCoerce a)
         6 -> f7 (unsafeCoerce a)
         7 -> f8 (unsafeCoerce a)
         _ -> f9 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      , toVariantAt @2
      , toVariantAt @3
      , toVariantAt @4
      , toVariantAt @5
      , toVariantAt @6
      , toVariantAt @7
      , toVariantAt @8
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      , return . toVariantAt @2
      , return . toVariantAt @3
      , return . toVariantAt @4
      , return . toVariantAt @5
      , return . toVariantAt @6
      , return . toVariantAt @7
      , return . toVariantAt @8
      )

instance ContVariant '[a,b,c,d,e,f,g,h,i,j] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7,f8,f9,f10) ->
      case t of
         0 -> f1  (unsafeCoerce a)
         1 -> f2  (unsafeCoerce a)
         2 -> f3  (unsafeCoerce a)
         3 -> f4  (unsafeCoerce a)
         4 -> f5  (unsafeCoerce a)
         5 -> f6  (unsafeCoerce a)
         6 -> f7  (unsafeCoerce a)
         7 -> f8  (unsafeCoerce a)
         8 -> f9  (unsafeCoerce a)
         _ -> f10 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7,f8,f9,f10) -> do
      Variant t a <- act
      case t of
         0 -> f1  (unsafeCoerce a)
         1 -> f2  (unsafeCoerce a)
         2 -> f3  (unsafeCoerce a)
         3 -> f4  (unsafeCoerce a)
         4 -> f5  (unsafeCoerce a)
         5 -> f6  (unsafeCoerce a)
         6 -> f7  (unsafeCoerce a)
         7 -> f8  (unsafeCoerce a)
         8 -> f9  (unsafeCoerce a)
         _ -> f10 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      , toVariantAt @2
      , toVariantAt @3
      , toVariantAt @4
      , toVariantAt @5
      , toVariantAt @6
      , toVariantAt @7
      , toVariantAt @8
      , toVariantAt @9
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      , return . toVariantAt @2
      , return . toVariantAt @3
      , return . toVariantAt @4
      , return . toVariantAt @5
      , return . toVariantAt @6
      , return . toVariantAt @7
      , return . toVariantAt @8
      , return . toVariantAt @9
      )

instance ContVariant '[a,b,c,d,e,f,g,h,i,j,k] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11) ->
      case t of
         0 -> f1  (unsafeCoerce a)
         1 -> f2  (unsafeCoerce a)
         2 -> f3  (unsafeCoerce a)
         3 -> f4  (unsafeCoerce a)
         4 -> f5  (unsafeCoerce a)
         5 -> f6  (unsafeCoerce a)
         6 -> f7  (unsafeCoerce a)
         7 -> f8  (unsafeCoerce a)
         8 -> f9  (unsafeCoerce a)
         9 -> f10 (unsafeCoerce a)
         _ -> f11 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11) -> do
      Variant t a <- act
      case t of
         0 -> f1  (unsafeCoerce a)
         1 -> f2  (unsafeCoerce a)
         2 -> f3  (unsafeCoerce a)
         3 -> f4  (unsafeCoerce a)
         4 -> f5  (unsafeCoerce a)
         5 -> f6  (unsafeCoerce a)
         6 -> f7  (unsafeCoerce a)
         7 -> f8  (unsafeCoerce a)
         8 -> f9  (unsafeCoerce a)
         9 -> f10 (unsafeCoerce a)
         _ -> f11 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      , toVariantAt @2
      , toVariantAt @3
      , toVariantAt @4
      , toVariantAt @5
      , toVariantAt @6
      , toVariantAt @7
      , toVariantAt @8
      , toVariantAt @9
      , toVariantAt @10
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      , return . toVariantAt @2
      , return . toVariantAt @3
      , return . toVariantAt @4
      , return . toVariantAt @5
      , return . toVariantAt @6
      , return . toVariantAt @7
      , return . toVariantAt @8
      , return . toVariantAt @9
      , return . toVariantAt @10
      )

instance ContVariant '[a,b,c,d,e,f,g,h,i,j,k,l] where
   {-# INLINE variantToCont #-}
   variantToCont (Variant t a) = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12) ->
      case t of
         0  -> f1  (unsafeCoerce a)
         1  -> f2  (unsafeCoerce a)
         2  -> f3  (unsafeCoerce a)
         3  -> f4  (unsafeCoerce a)
         4  -> f5  (unsafeCoerce a)
         5  -> f6  (unsafeCoerce a)
         6  -> f7  (unsafeCoerce a)
         7  -> f8  (unsafeCoerce a)
         8  -> f9  (unsafeCoerce a)
         9  -> f10 (unsafeCoerce a)
         10 -> f11 (unsafeCoerce a)
         _  -> f12 (unsafeCoerce a)

   {-# INLINE variantToContM #-}
   variantToContM act = ContFlow $ \(f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12) -> do
      Variant t a <- act
      case t of
         0  -> f1  (unsafeCoerce a)
         1  -> f2  (unsafeCoerce a)
         2  -> f3  (unsafeCoerce a)
         3  -> f4  (unsafeCoerce a)
         4  -> f5  (unsafeCoerce a)
         5  -> f6  (unsafeCoerce a)
         6  -> f7  (unsafeCoerce a)
         7  -> f8  (unsafeCoerce a)
         8  -> f9  (unsafeCoerce a)
         9  -> f10 (unsafeCoerce a)
         10 -> f11 (unsafeCoerce a)
         _  -> f12 (unsafeCoerce a)

   {-# INLINE contToVariant #-}
   contToVariant c = c >::>
      ( toVariantAt @0
      , toVariantAt @1
      , toVariantAt @2
      , toVariantAt @3
      , toVariantAt @4
      , toVariantAt @5
      , toVariantAt @6
      , toVariantAt @7
      , toVariantAt @8
      , toVariantAt @9
      , toVariantAt @10
      , toVariantAt @11
      )

   {-# INLINE contToVariantM #-}
   contToVariantM c = c >::>
      ( return . toVariantAt @0
      , return . toVariantAt @1
      , return . toVariantAt @2
      , return . toVariantAt @3
      , return . toVariantAt @4
      , return . toVariantAt @5
      , return . toVariantAt @6
      , return . toVariantAt @7
      , return . toVariantAt @8
      , return . toVariantAt @9
      , return . toVariantAt @10
      , return . toVariantAt @11
      )
