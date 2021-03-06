{-# OPTIONS -Wall #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeSynonymInstances #-}





-- | The terms of the simply typed lambda calculus w/ non-parametric user
-- defined types (eg Bool, Nat).

module Poly.Core.Term where

import Poly.Core.Type

import Utils.ABT
import Utils.Pretty

import Data.List (intercalate)





-- | There are five kinds of terms, an annotated term @M : T@, a lambda term
-- @\\x -> M@, an application term @M N@, a constructor term @C M0 ... Mn@, and
-- a case term @case M0 || ... || Mn of p0* -> N0 | ... | pm* -> Nm end@.

data TermF r
  = Defined String
  | Ann r Type
  | Lam r
  | App r r
  | Con String [r]
  | Case [r] [ClauseF r]
  deriving (Functor,Foldable)


type Term = ABT TermF


-- | Clauses are a subsort of terms that has bunch of pattern scopes together
-- with a clause body.

data ClauseF r = Clause [Scope PatternF] r
  deriving (Functor,Foldable)


type Clause = ClauseF (Scope TermF)


-- | Patterns are only constructor patterns, with some number of pattern args.

data PatternF r = ConPat String [r]
  deriving (Functor,Foldable,Traversable)

  
type Pattern = ABT PatternF


defined :: String -> Term
defined n = In (Defined n)

annH :: Term -> Type -> Term
annH m t = In (Ann (scope [] m) t)

lamH :: String -> Term -> Term
lamH v b = In (Lam (scope [v] b))

appH :: Term -> Term -> Term
appH f x = In (App (scope [] f) (scope [] x))

conH :: String -> [Term] -> Term
conH c xs = In (Con c (map (scope []) xs))

caseH :: [Term] -> [Clause] -> Term
caseH as cs = In (Case (map (scope []) as) cs)

clauseH :: [String] -> [Pattern] -> Term -> Clause
clauseH vs ps b = Clause (map (scope vs) ps) (scope vs b)

conPatH :: String -> [Pattern] -> Pattern
conPatH c xs = In (ConPat c (map (scope []) xs))





-- | Terms have a variety of locations that can potentially be sites of
-- de-parenthesization.

data TermParenLoc
  = AnnTerm
  | LamBody | AppFun | AppArg
  | ConArg | CaseArg | ClauseBody
  deriving (Eq)


instance Parens Term where
  type Loc Term = TermParenLoc
  
  parenLoc (Var _) =
    [AnnTerm,LamBody,AppFun,AppArg,ConArg,CaseArg,ClauseBody]
  parenLoc (In (Defined _)) =
    [AnnTerm,LamBody,AppFun,AppArg,ConArg,CaseArg,ClauseBody]
  parenLoc (In (Ann _ _)) =
    [LamBody,CaseArg,ClauseBody]
  parenLoc (In (Lam _)) =
    [LamBody,CaseArg,ClauseBody]
  parenLoc (In (App _ _)) =
    [AnnTerm,LamBody,AppFun,CaseArg,ClauseBody]
  parenLoc (In (Con _ [])) =
    [AnnTerm,LamBody,AppFun,AppArg,ConArg,CaseArg,ClauseBody]
  parenLoc (In (Con _ _)) =
    [AnnTerm,LamBody,CaseArg,ClauseBody]
  parenLoc (In (Case _ _)) =
    [LamBody,ClauseBody]

  parenRec (Var v) =
    name v
  parenRec (In (Defined n)) = n
  parenRec (In (Ann m t)) =
    parenthesize (Just AnnTerm) (instantiate0 m)
      ++ " : "
      ++ pretty t
  parenRec (In (Lam sc)) =
    "\\" ++ unwords (names sc)
      ++ " -> "
      ++ parenthesize (Just LamBody)
           (body sc)
  parenRec (In (App f a)) =
    parenthesize (Just AppFun) (instantiate0 f)
      ++ " "
      ++ parenthesize (Just AppArg) (instantiate0 a)
  parenRec (In (Con c [])) =
    c
  parenRec (In (Con c as)) =
    c ++ " "
      ++ intercalate
           " "
           (map (parenthesize (Just ConArg) . instantiate0) as)
  parenRec (In (Case as cs)) =
    "case "
      ++ intercalate
           " || "
           (map (parenthesize (Just CaseArg) . instantiate0) as)
      ++ " of "
      ++ intercalate " | " (map auxClause cs) ++ " end"
    where
      auxClause :: Clause -> String
      auxClause (Clause pscs sc) =
        intercalate " || "
          (map (parenthesize Nothing . body) pscs)
        ++ " -> "
        ++ parenthesize (Just ClauseBody) (body sc)





-- | Pattern locations are even simpler, as there's only one: constructor arg.

data PatternParenLoc = ConPatArg
  deriving (Eq)

instance Parens Pattern where
  type Loc Pattern = PatternParenLoc
  
  parenLoc (Var _)            = [ConPatArg]
  parenLoc (In (ConPat _ [])) = [ConPatArg]
  parenLoc (In (ConPat _ _))  = []
  
  parenRec (Var v) =
    name v
  parenRec (In (ConPat c [])) = c
  parenRec (In (ConPat c ps)) =
    c ++ " " ++ unwords (map (parenthesize (Just ConPatArg) . body) ps)