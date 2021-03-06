{-# OPTIONS -Wall #-}





-- | This module defines what it means to be a program in the simply typed
-- lambda calculus w/ parametric user defined types (eg Maybe, List).

module Poly.Core.Program where

import Utils.ABT
import Utils.Pretty
import Poly.Core.ConSig
import Poly.Core.Term
import Poly.Core.Type

import Data.List (intercalate)





-- | A program is just a series of 'Statement's.

newtype Program = Program [Statement]

instance Show Program where
  show (Program stmts) = intercalate "\n\n" (map show stmts)





-- | A 'Statement' is either a 'TypeDeclaration' or a 'TermDeclaration'.

data Statement
  = TyDecl TypeDeclaration
  | TmDecl TermDeclaration

instance Show Statement where
  show (TyDecl td) = show td
  show (TmDecl td) = show td





-- | A term can be declared either with a simple equality, as in
--
-- > let not : Bool -> Bool
-- >   = \b -> case b of
-- >           | True -> False
-- >           | False -> True
-- >           end
-- > end
--
-- or with a pattern match, as in
--
-- > let not : Bool -> Bool where
-- >   | not True = False
-- >   | not False = True
-- > end

data TermDeclaration
  = TermDeclaration String Type Term
  | WhereDeclaration String Type [([Pattern],[String],Term)]

instance Show TermDeclaration where
  show (TermDeclaration n ty def) =
    "let " ++ n ++ " : " ++ pretty ty ++ " = " ++ pretty def ++ " end"
  show (WhereDeclaration n ty preclauses) =
    "let " ++ n ++ " : " ++ pretty ty ++ " where "
      ++ intercalate " | " (map showPreclause preclauses)
    where
      showPreclause :: ([Pattern],[String],Term) -> String
      showPreclause (ps,_,b) =
        intercalate " || " (map pretty ps) ++ " -> " ++ pretty b





-- | A type is declared with Haskell-like notation, as in
--
-- > data Bool = True | False end
--
-- Types with no constructors need no @=@:
--
-- > data Void end

data TypeDeclaration
  = TypeDeclaration String [String] [(String,ConSig)]

instance Show TypeDeclaration where
  show (TypeDeclaration tycon params []) =
    "data " ++ tycon ++ concat (map (' ':) params) ++ " end"
  show (TypeDeclaration tycon params alts) =
    "data " ++ tycon ++ concat (map (' ':) params) ++ " = "
      ++ intercalate
           " | "
           [ showAlt c (map body as) | (c, ConSig as _) <- alts ]
      ++ " end"
   where
     showAlt :: String -> [Type] -> String
     showAlt c [] = c
     showAlt c as = c ++ " " ++ unwords (map pretty as)