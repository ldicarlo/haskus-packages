{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE PolyKinds #-}

-- | Tuple helpers
module Haskus.Utils.Tuple
   ( uncurry3
   , uncurry4
   , take4
   , fromTuple4
   , module Data.Tuple
   , Single (..)
   , TupleToList
   , ListToTuple
   , ExtractTuple (..)
   , TupleHead (..)
   , TupleTail (..)
   , TupleCons (..)
   , ReorderTuple (..)
   )
where

import Data.Tuple
import Haskus.Utils.Types

-- | Uncurry specialised for triple
uncurry3 :: (a -> b -> c -> e) -> (a,b,c) -> e
{-# INLINABLE uncurry3 #-}
uncurry3 f (a,b,c) = f a b c

-- | Uncurry specialised for quadruple
uncurry4 :: (a -> b -> c -> d -> e) -> (a,b,c,d) -> e
{-# INLINABLE uncurry4 #-}
uncurry4 f (a,b,c,d) = f a b c d


-- | Take specialised for quadruple
take4 :: [a] -> (a,a,a,a)
{-# INLINABLE take4 #-}
take4 [a,b,c,d] = (a,b,c,d)
take4 _         = error "take4: invalid list (exactly 4 elements required)"


-- | toList for quadruple
fromTuple4 :: (a,a,a,a) -> [a]
{-# INLINABLE fromTuple4 #-}
fromTuple4 (a,b,c,d) = [a,b,c,d]


-- | Singleton type
newtype Single a = Single a deriving (Show,Eq)


type family TupleToList (t :: k) :: [k] where
   TupleToList ()                                                    = '[]
   TupleToList (Single a)                                            = '[a]
   TupleToList (a,b)                                                 = '[a,b]
   TupleToList (a,b,c)                                               = '[a,b,c]
   TupleToList (a,b,c,d)                                             = '[a,b,c,d]
   TupleToList (a,b,c,d,e)                                           = '[a,b,c,d,e]
   TupleToList (a,b,c,d,e,f)                                         = '[a,b,c,d,e,f]
   TupleToList (a,b,c,d,e,f,g)                                       = '[a,b,c,d,e,f,g]
   TupleToList (a,b,c,d,e,f,g,h)                                     = '[a,b,c,d,e,f,g,h]
   TupleToList (a,b,c,d,e,f,g,h,i)                                   = '[a,b,c,d,e,f,g,h,i]
   TupleToList (a,b,c,d,e,f,g,h,i,j)                                 = '[a,b,c,d,e,f,g,h,i,j]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k)                               = '[a,b,c,d,e,f,g,h,i,j,k]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l)                             = '[a,b,c,d,e,f,g,h,i,j,k,l]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m)                           = '[a,b,c,d,e,f,g,h,i,j,k,l,m]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n)                         = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o)                       = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p)                     = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q)                   = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r)                 = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s)               = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t)             = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u)           = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v)         = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w)       = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x)     = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y)   = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y]
   TupleToList (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z) = '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z]

type family ListToTuple (t :: [k]) :: k where
   ListToTuple '[]                                                    = ()
   ListToTuple '[a]                                                   = Single a
   ListToTuple '[a,b]                                                 = (a,b)
   ListToTuple '[a,b,c]                                               = (a,b,c)
   ListToTuple '[a,b,c,d]                                             = (a,b,c,d)
   ListToTuple '[a,b,c,d,e]                                           = (a,b,c,d,e)
   ListToTuple '[a,b,c,d,e,f]                                         = (a,b,c,d,e,f)
   ListToTuple '[a,b,c,d,e,f,g]                                       = (a,b,c,d,e,f,g)
   ListToTuple '[a,b,c,d,e,f,g,h]                                     = (a,b,c,d,e,f,g,h)
   ListToTuple '[a,b,c,d,e,f,g,h,i]                                   = (a,b,c,d,e,f,g,h,i)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j]                                 = (a,b,c,d,e,f,g,h,i,j)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k]                               = (a,b,c,d,e,f,g,h,i,j,k)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l]                             = (a,b,c,d,e,f,g,h,i,j,k,l)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m]                           = (a,b,c,d,e,f,g,h,i,j,k,l,m)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n]                         = (a,b,c,d,e,f,g,h,i,j,k,l,m,n)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o]                       = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]                     = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q]                   = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r]                 = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s]               = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t]             = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u]           = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v]         = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w]       = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x]     = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y]   = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y)
   ListToTuple '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z] = (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z)

-- | Extract a tuple value statically
class ExtractTuple (n :: Nat) t x | n t -> x where
   -- | Extract a tuple value by type-level index
   tupleN :: t -> x

instance ExtractTuple 0 (Single t) t where
   {-# INLINABLE tupleN #-}
   tupleN (Single t) = t

instance ExtractTuple 0 (e0, e1) e0 where
   {-# INLINABLE tupleN #-}
   tupleN (t,_) = t

instance ExtractTuple 1 (e0, e1) e1 where
   {-# INLINABLE tupleN #-}
   tupleN (_,t) = t

instance ExtractTuple 0 (e0, e1, e2) e0 where
   {-# INLINABLE tupleN #-}
   tupleN (t,_,_) = t

instance ExtractTuple 1 (e0, e1, e2) e1 where
   {-# INLINABLE tupleN #-}
   tupleN (_,t,_) = t

instance ExtractTuple 2 (e0, e1, e2) e2 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,t) = t

instance ExtractTuple 0 (e0, e1, e2, e3) e0 where
   {-# INLINABLE tupleN #-}
   tupleN (t,_,_,_) = t

instance ExtractTuple 1 (e0, e1, e2, e3) e1 where
   {-# INLINABLE tupleN #-}
   tupleN (_,t,_,_) = t

instance ExtractTuple 2 (e0, e1, e2, e3) e2 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,t,_) = t

instance ExtractTuple 3 (e0, e1, e2, e3) e3 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,t) = t


instance ExtractTuple 0 (e0, e1, e2, e3, e4) e0 where
   {-# INLINABLE tupleN #-}
   tupleN (t,_,_,_,_) = t

instance ExtractTuple 1 (e0, e1, e2, e3, e4) e1 where
   {-# INLINABLE tupleN #-}
   tupleN (_,t,_,_,_) = t

instance ExtractTuple 2 (e0, e1, e2, e3, e4) e2 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,t,_,_) = t

instance ExtractTuple 3 (e0, e1, e2, e3, e4) e3 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,t,_) = t

instance ExtractTuple 4 (e0, e1, e2, e3, e4) e4 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,_,t) = t


instance ExtractTuple 0 (e0, e1, e2, e3, e4, e5) e0 where
   {-# INLINABLE tupleN #-}
   tupleN (t,_,_,_,_,_) = t

instance ExtractTuple 1 (e0, e1, e2, e3, e4, e5) e1 where
   {-# INLINABLE tupleN #-}
   tupleN (_,t,_,_,_,_) = t

instance ExtractTuple 2 (e0, e1, e2, e3, e4, e5) e2 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,t,_,_,_) = t

instance ExtractTuple 3 (e0, e1, e2, e3, e4, e5) e3 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,t,_,_) = t

instance ExtractTuple 4 (e0, e1, e2, e3, e4, e5) e4 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,_,t,_) = t

instance ExtractTuple 5 (e0, e1, e2, e3, e4, e5) e5 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,_,_,t) = t


instance ExtractTuple 0 (e0, e1, e2, e3, e4, e5, e6) e0 where
   {-# INLINABLE tupleN #-}
   tupleN (t,_,_,_,_,_,_) = t

instance ExtractTuple 1 (e0, e1, e2, e3, e4, e5, e6) e1 where
   {-# INLINABLE tupleN #-}
   tupleN (_,t,_,_,_,_,_) = t

instance ExtractTuple 2 (e0, e1, e2, e3, e4, e5, e6) e2 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,t,_,_,_,_) = t

instance ExtractTuple 3 (e0, e1, e2, e3, e4, e5, e6) e3 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,t,_,_,_) = t

instance ExtractTuple 4 (e0, e1, e2, e3, e4, e5, e6) e4 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,_,t,_,_) = t

instance ExtractTuple 5 (e0, e1, e2, e3, e4, e5, e6) e5 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,_,_,t,_) = t

instance ExtractTuple 6 (e0, e1, e2, e3, e4, e5, e6) e6 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,_,_,_,t) = t


instance ExtractTuple 0 (e0, e1, e2, e3, e4, e5, e6, e7) e0 where
   {-# INLINABLE tupleN #-}
   tupleN (t,_,_,_,_,_,_,_) = t

instance ExtractTuple 1 (e0, e1, e2, e3, e4, e5, e6, e7) e1 where
   {-# INLINABLE tupleN #-}
   tupleN (_,t,_,_,_,_,_,_) = t

instance ExtractTuple 2 (e0, e1, e2, e3, e4, e5, e6, e7) e2 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,t,_,_,_,_,_) = t

instance ExtractTuple 3 (e0, e1, e2, e3, e4, e5, e6, e7) e3 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,t,_,_,_,_) = t

instance ExtractTuple 4 (e0, e1, e2, e3, e4, e5, e6, e7) e4 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,_,t,_,_,_) = t

instance ExtractTuple 5 (e0, e1, e2, e3, e4, e5, e6, e7) e5 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,_,_,t,_,_) = t

instance ExtractTuple 6 (e0, e1, e2, e3, e4, e5, e6, e7) e6 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,_,_,_,t,_) = t

instance ExtractTuple 7 (e0, e1, e2, e3, e4, e5, e6, e7) e7 where
   {-# INLINABLE tupleN #-}
   tupleN (_,_,_,_,_,_,_,t) = t


class TupleHead ts ts' | ts -> ts' where
   tupleHead :: ts -> ts'

instance TupleHead (Single a) a where
   {-# INLINABLE tupleHead #-}
   tupleHead (Single a) = a

instance TupleHead (a,b) a where
   {-# INLINABLE tupleHead #-}
   tupleHead (a,_) = a

instance TupleHead (a,b,c) a where
   {-# INLINABLE tupleHead #-}
   tupleHead (a,_,_) = a

instance TupleHead (a,b,c,d) a where
   {-# INLINABLE tupleHead #-}
   tupleHead (a,_,_,_) = a

instance TupleHead (a,b,c,d,e) a where
   {-# INLINABLE tupleHead #-}
   tupleHead (a,_,_,_,_) = a

instance TupleHead (a,b,c,d,e,f) a where
   {-# INLINABLE tupleHead #-}
   tupleHead (a,_,_,_,_,_) = a


class TupleTail ts ts' | ts -> ts' where
   tupleTail :: ts -> ts'

instance TupleTail (a,b) (Single b) where
   {-# INLINABLE tupleTail #-}
   tupleTail (_,b) = Single b

instance TupleTail (a,b,c) (b,c) where
   {-# INLINABLE tupleTail #-}
   tupleTail (_,b,c) = (b,c)

instance TupleTail (a,b,c,d) (b,c,d) where
   {-# INLINABLE tupleTail #-}
   tupleTail (_,b,c,d) = (b,c,d)

instance TupleTail (a,b,c,d,e) (b,c,d,e) where
   {-# INLINABLE tupleTail #-}
   tupleTail (_,b,c,d,e) = (b,c,d,e)

instance TupleTail (a,b,c,d,e,f) (b,c,d,e,f) where
   {-# INLINABLE tupleTail #-}
   tupleTail (_,b,c,d,e,f) = (b,c,d,e,f)



class TupleCons t ts ts' | t ts -> ts' where
   tupleCons :: t -> ts -> ts'

instance TupleCons a (Single b) (a,b) where
   {-# INLINABLE tupleCons #-}
   tupleCons a (Single b) = (a,b)

instance TupleCons a (b,c) (a,b,c) where
   {-# INLINABLE tupleCons #-}
   tupleCons a (b,c) = (a,b,c)

instance TupleCons a (b,c,d) (a,b,c,d) where
   {-# INLINABLE tupleCons #-}
   tupleCons a (b,c,d) = (a,b,c,d)

instance TupleCons a (b,c,d,e) (a,b,c,d,e) where
   {-# INLINABLE tupleCons #-}
   tupleCons a (b,c,d,e) = (a,b,c,d,e)

instance TupleCons a (b,c,d,e,f) (a,b,c,d,e,f) where
   {-# INLINABLE tupleCons #-}
   tupleCons a (b,c,d,e,f) = (a,b,c,d,e,f)


-- | Reorder tuple elements
class ReorderTuple t1 t2 where
   -- | Reorder tuple elements
   tupleReorder :: t1 -> t2


instance ReorderTuple (Single a) (Single a) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder = id

instance ReorderTuple (a,b) (a,b) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder = id

instance ReorderTuple (a,b,c) (a,b,c) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder = id

instance ReorderTuple (a,b,c,d) (a,b,c,d) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder = id

instance ReorderTuple (a,b,c,d,e) (a,b,c,d,e) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder = id

instance ReorderTuple (a,b,c,d,e,f) (a,b,c,d,e,f) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder = id

instance ReorderTuple (a,b,c,d,e,f,g) (a,b,c,d,e,f,g) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder = id

instance ReorderTuple (a,b,c,d,e,f,g,h) (a,b,c,d,e,f,g,h) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder = id

instance ReorderTuple (a,b,c,d,e,f,g,h,i) (a,b,c,d,e,f,g,h,i) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder = id

instance ReorderTuple (a,b,c,d,e,f,g,h,i,j) (a,b,c,d,e,f,g,h,i,j) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder = id


instance ReorderTuple (a,b) (b,a) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b) = (b,a)

instance ReorderTuple (a,b,c) (a,c,b) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c) = (a,c,b)

instance ReorderTuple (a,b,c) (b,a,c) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c) = (b,a,c)

instance ReorderTuple (a,b,c) (b,c,a) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c) = (b,c,a)

instance ReorderTuple (a,b,c) (c,a,b) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c) = (c,a,b)

instance ReorderTuple (a,b,c) (c,b,a) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c) = (c,b,a)

instance ReorderTuple (b,c,d) (x,y,z) => ReorderTuple (a,b,c,d) (a,x,y,z) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d) = let (x,y,z) = tupleReorder (b,c,d) in (a,x,y,z)

instance ReorderTuple (a,c,d) (x,y,z) => ReorderTuple (a,b,c,d) (x,b,y,z) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d) = let (x,y,z) = tupleReorder (a,c,d) in (x,b,y,z)

instance ReorderTuple (a,b,d) (x,y,z) => ReorderTuple (a,b,c,d) (x,y,c,z) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d) = let (x,y,z) = tupleReorder (a,b,d) in (x,y,c,z)

instance ReorderTuple (a,b,c) (x,y,z) => ReorderTuple (a,b,c,d) (x,y,z,d) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d) = let (x,y,z) = tupleReorder (a,b,c) in (x,y,z,d)

instance ReorderTuple (b,c,d,e) (x,y,z,w) => ReorderTuple (a,b,c,d,e) (a,x,y,z,w) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e) = let (x,y,z,w) = tupleReorder (b,c,d,e) in (a,x,y,z,w)

instance ReorderTuple (a,c,d,e) (x,y,z,w) => ReorderTuple (a,b,c,d,e) (x,b,y,z,w) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e) = let (x,y,z,w) = tupleReorder (a,c,d,e) in (x,b,y,z,w)

instance ReorderTuple (a,b,d,e) (x,y,z,w) => ReorderTuple (a,b,c,d,e) (x,y,c,z,w) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e) = let (x,y,z,w) = tupleReorder (a,b,d,e) in (x,y,c,z,w)

instance ReorderTuple (a,b,c,e) (x,y,z,w) => ReorderTuple (a,b,c,d,e) (x,y,z,d,w) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e) = let (x,y,z,w) = tupleReorder (a,b,c,e) in (x,y,z,d,w)

instance ReorderTuple (a,b,c,d) (x,y,z,w) => ReorderTuple (a,b,c,d,e) (x,y,z,w,e) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e) = let (x,y,z,w) = tupleReorder (a,b,c,d) in (x,y,z,w,e)

instance ReorderTuple (b,c,d,e,f) (x,y,z,w,v) => ReorderTuple (a,b,c,d,e,f) (a,x,y,z,w,v) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f) = let (x,y,z,w,v) = tupleReorder (b,c,d,e,f) in (a,x,y,z,w,v)

instance ReorderTuple (a,c,d,e,f) (x,y,z,w,v) => ReorderTuple (a,b,c,d,e,f) (x,b,y,z,w,v) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f) = let (x,y,z,w,v) = tupleReorder (a,c,d,e,f) in (x,b,y,z,w,v)

instance ReorderTuple (a,b,d,e,f) (x,y,z,w,v) => ReorderTuple (a,b,c,d,e,f) (x,y,c,z,w,v) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f) = let (x,y,z,w,v) = tupleReorder (a,b,d,e,f) in (x,y,c,z,w,v)

instance ReorderTuple (a,b,c,e,f) (x,y,z,w,v) => ReorderTuple (a,b,c,d,e,f) (x,y,z,d,w,v) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f) = let (x,y,z,w,v) = tupleReorder (a,b,c,e,f) in (x,y,z,d,w,v)

instance ReorderTuple (a,b,c,d,f) (x,y,z,w,v) => ReorderTuple (a,b,c,d,e,f) (x,y,z,w,e,v) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f) = let (x,y,z,w,v) = tupleReorder (a,b,c,d,f) in (x,y,z,w,e,v)

instance ReorderTuple (a,b,c,d,e) (x,y,z,w,v) => ReorderTuple (a,b,c,d,e,f) (x,y,z,w,v,f) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f) = let (x,y,z,w,v) = tupleReorder (a,b,c,d,e) in (x,y,z,w,v,f)


instance ReorderTuple (b,c,d,e,f,g) (x,y,z,w,v,u) => ReorderTuple (a,b,c,d,e,f,g) (a,x,y,z,w,v,u) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f,g) = let (x,y,z,w,v,u) = tupleReorder (b,c,d,e,f,g) in (a,x,y,z,w,v,u)

instance ReorderTuple (a,c,d,e,f,g) (x,y,z,w,v,u) => ReorderTuple (a,b,c,d,e,f,g) (x,b,y,z,w,v,u) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f,g) = let (x,y,z,w,v,u) = tupleReorder (a,c,d,e,f,g) in (x,b,y,z,w,v,u)

instance ReorderTuple (a,b,d,e,f,g) (x,y,z,w,v,u) => ReorderTuple (a,b,c,d,e,f,g) (x,y,c,z,w,v,u) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f,g) = let (x,y,z,w,v,u) = tupleReorder (a,b,d,e,f,g) in (x,y,c,z,w,v,u)

instance ReorderTuple (a,b,c,e,f,g) (x,y,z,w,v,u) => ReorderTuple (a,b,c,d,e,f,g) (x,y,z,d,w,v,u) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f,g) = let (x,y,z,w,v,u) = tupleReorder (a,b,c,e,f,g) in (x,y,z,d,w,v,u)

instance ReorderTuple (a,b,c,d,f,g) (x,y,z,w,v,u) => ReorderTuple (a,b,c,d,e,f,g) (x,y,z,w,e,v,u) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f,g) = let (x,y,z,w,v,u) = tupleReorder (a,b,c,d,f,g) in (x,y,z,w,e,v,u)

instance ReorderTuple (a,b,c,d,e,g) (x,y,z,w,v,u) => ReorderTuple (a,b,c,d,e,f,g) (x,y,z,w,v,f,u) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f,g) = let (x,y,z,w,v,u) = tupleReorder (a,b,c,d,e,g) in (x,y,z,w,v,f,u)

instance ReorderTuple (a,b,c,d,e,f) (x,y,z,w,v,u) => ReorderTuple (a,b,c,d,e,f,g) (x,y,z,w,v,u,g) where
   {-# INLINABLE tupleReorder #-}
   tupleReorder (a,b,c,d,e,f,g) = let (x,y,z,w,v,u) = tupleReorder (a,b,c,d,e,f) in (x,y,z,w,v,u,g)
