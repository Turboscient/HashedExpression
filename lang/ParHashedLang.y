-- This Happy file was machine-generated by the BNF converter
{
{-# OPTIONS_GHC -fno-warn-incomplete-patterns -fno-warn-overlapping-patterns #-}
module ParHashedLang where
import AbsHashedLang
import LexHashedLang
import ErrM

}

%name pProblem Problem
%name pBlock Block
%name pListBlock ListBlock
%name pNumber Number
%name pVal Val
%name pDim Dim
%name pShape Shape
%name pVariableDecl VariableDecl
%name pListVariableDecl ListVariableDecl
%name pListListVariableDecl ListListVariableDecl
%name pVariableBlock VariableBlock
%name pConstantDecl ConstantDecl
%name pListConstantDecl ListConstantDecl
%name pListListConstantDecl ListListConstantDecl
%name pConstantBlock ConstantBlock
%name pLetDecl LetDecl
%name pListLetDecl ListLetDecl
%name pListListLetDecl ListListLetDecl
%name pLetBlock LetBlock
%name pMinimizeBlock MinimizeBlock
%name pRotateAmount RotateAmount
%name pExp Exp
%name pExp1 Exp1
%name pExp2 Exp2
%name pExp3 Exp3
%name pExp4 Exp4
-- no lexer declaration
%monad { Err } { thenM } { returnM }
%tokentype {Token}
%token
  '(' { PT _ (TS _ 1) }
  ')' { PT _ (TS _ 2) }
  '*' { PT _ (TS _ 3) }
  '*.' { PT _ (TS _ 4) }
  '+' { PT _ (TS _ 5) }
  ',' { PT _ (TS _ 6) }
  '-' { PT _ (TS _ 7) }
  '/' { PT _ (TS _ 8) }
  ':' { PT _ (TS _ 9) }
  ';' { PT _ (TS _ 10) }
  '<.>' { PT _ (TS _ 11) }
  '=' { PT _ (TS _ 12) }
  'Dataset' { PT _ (TS _ 13) }
  'File' { PT _ (TS _ 14) }
  'Pattern' { PT _ (TS _ 15) }
  'Random' { PT _ (TS _ 16) }
  '[' { PT _ (TS _ 17) }
  ']' { PT _ (TS _ 18) }
  'rotate' { PT _ (TS _ 19) }
  '{' { PT _ (TS _ 20) }
  '}' { PT _ (TS _ 21) }
  L_integ  { PT _ (TI $$) }
  L_doubl  { PT _ (TD $$) }
  L_quoted { PT _ (TL $$) }
  L_KWVariable { PT _ (T_KWVariable $$) }
  L_KWConstant { PT _ (T_KWConstant $$) }
  L_KWLet { PT _ (T_KWLet $$) }
  L_KWMinimize { PT _ (T_KWMinimize $$) }
  L_KWDataPattern { PT _ (T_KWDataPattern $$) }
  L_PIdent { PT _ (T_PIdent _) }

%%

Integer :: { Integer }
Integer  : L_integ  { (read ( $1)) :: Integer }

Double  :: { Double }
Double   : L_doubl  { (read ( $1)) :: Double }

String  :: { String }
String   : L_quoted {  $1 }

KWVariable :: { KWVariable}
KWVariable  : L_KWVariable { KWVariable ($1)}

KWConstant :: { KWConstant}
KWConstant  : L_KWConstant { KWConstant ($1)}

KWLet :: { KWLet}
KWLet  : L_KWLet { KWLet ($1)}

KWMinimize :: { KWMinimize}
KWMinimize  : L_KWMinimize { KWMinimize ($1)}

KWDataPattern :: { KWDataPattern}
KWDataPattern  : L_KWDataPattern { KWDataPattern ($1)}

PIdent :: { PIdent}
PIdent  : L_PIdent { PIdent (mkPosToken $1)}

Problem :: { Problem }
Problem : ListBlock { AbsHashedLang.Problem $1 }
Block :: { Block }
Block : VariableBlock { AbsHashedLang.BlockVariable $1 }
      | ConstantBlock { AbsHashedLang.BlockConstant $1 }
      | LetBlock { AbsHashedLang.BlockLet $1 }
      | MinimizeBlock { AbsHashedLang.BlockMinimize $1 }
ListBlock :: { [Block] }
ListBlock : Block { (:[]) $1 } | Block ListBlock { (:) $1 $2 }
Number :: { Number }
Number : Integer { AbsHashedLang.NumInt $1 }
       | Double { AbsHashedLang.NumDouble $1 }
Val :: { Val }
Val : 'File' '(' String ')' { AbsHashedLang.ValFile $3 }
    | 'Dataset' '(' String ',' String ')' { AbsHashedLang.ValDataset $3 $5 }
    | 'Pattern' '(' KWDataPattern ')' { AbsHashedLang.ValPattern $3 }
    | 'Random' { AbsHashedLang.ValRandom }
    | Number { AbsHashedLang.ValLiteral $1 }
Dim :: { Dim }
Dim : '[' Integer ']' { AbsHashedLang.Dim $2 }
Shape :: { Shape }
Shape : {- empty -} { AbsHashedLang.ShapeScalar }
      | Dim { AbsHashedLang.Shape1D $1 }
      | Dim Dim { AbsHashedLang.Shape2D $1 $2 }
      | Dim Dim Dim { AbsHashedLang.Shape3D $1 $2 $3 }
VariableDecl :: { VariableDecl }
VariableDecl : PIdent Shape { AbsHashedLang.VariableNoInit $1 $2 }
             | PIdent Shape '=' Val { AbsHashedLang.VariableWithInit $1 $2 $4 }
ListVariableDecl :: { [VariableDecl] }
ListVariableDecl : {- empty -} { [] }
                 | VariableDecl { (:[]) $1 }
                 | VariableDecl ',' ListVariableDecl { (:) $1 $3 }
ListListVariableDecl :: { [[VariableDecl]] }
ListListVariableDecl : {- empty -} { [] }
                     | ListVariableDecl { (:[]) $1 }
                     | ListVariableDecl ';' ListListVariableDecl { (:) $1 $3 }
VariableBlock :: { VariableBlock }
VariableBlock : KWVariable ':' '{' ListListVariableDecl '}' { AbsHashedLang.VariableBlock $1 $4 }
ConstantDecl :: { ConstantDecl }
ConstantDecl : PIdent Shape '=' Val { AbsHashedLang.ConstantDecl $1 $2 $4 }
ListConstantDecl :: { [ConstantDecl] }
ListConstantDecl : {- empty -} { [] }
                 | ConstantDecl { (:[]) $1 }
                 | ConstantDecl ',' ListConstantDecl { (:) $1 $3 }
ListListConstantDecl :: { [[ConstantDecl]] }
ListListConstantDecl : {- empty -} { [] }
                     | ListConstantDecl { (:[]) $1 }
                     | ListConstantDecl ';' ListListConstantDecl { (:) $1 $3 }
ConstantBlock :: { ConstantBlock }
ConstantBlock : KWConstant ':' '{' ListListConstantDecl '}' { AbsHashedLang.ConstantBlock $1 $4 }
LetDecl :: { LetDecl }
LetDecl : PIdent '=' Exp { AbsHashedLang.LetDecl $1 $3 }
ListLetDecl :: { [LetDecl] }
ListLetDecl : {- empty -} { [] }
            | LetDecl { (:[]) $1 }
            | LetDecl ',' ListLetDecl { (:) $1 $3 }
ListListLetDecl :: { [[LetDecl]] }
ListListLetDecl : {- empty -} { [] }
                | ListLetDecl { (:[]) $1 }
                | ListLetDecl ';' ListListLetDecl { (:) $1 $3 }
LetBlock :: { LetBlock }
LetBlock : KWLet ':' '{' ListListLetDecl '}' { AbsHashedLang.LetBlock $1 $4 }
MinimizeBlock :: { MinimizeBlock }
MinimizeBlock : KWMinimize ':' '{' Exp '}' { AbsHashedLang.MinimizeBlock $1 $4 }
RotateAmount :: { RotateAmount }
RotateAmount : Integer { AbsHashedLang.RA1D $1 }
             | '(' Integer ',' Integer ')' { AbsHashedLang.RA2D $2 $4 }
             | '(' Integer ',' Integer ',' Integer ')' { AbsHashedLang.RA3D $2 $4 $6 }
Exp :: { Exp }
Exp : Exp '+' Exp1 { AbsHashedLang.EPlus $1 $3 }
    | Exp '-' Exp1 { AbsHashedLang.ESubtract $1 $3 }
    | Exp1 { $1 }
Exp1 :: { Exp }
Exp1 : Exp1 '*' Exp2 { AbsHashedLang.EMul $1 $3 }
     | Exp1 '/' Exp2 { AbsHashedLang.EDiv $1 $3 }
     | Exp2 { $1 }
Exp2 :: { Exp }
Exp2 : Exp2 '*.' Exp3 { AbsHashedLang.EScale $1 $3 }
     | Exp2 '<.>' Exp3 { AbsHashedLang.EDot $1 $3 }
     | Exp3 { $1 }
Exp3 :: { Exp }
Exp3 : PIdent Exp4 { AbsHashedLang.EFun $1 $2 }
     | 'rotate' RotateAmount Exp4 { AbsHashedLang.ERotate $2 $3 }
     | Exp4 { $1 }
Exp4 :: { Exp }
Exp4 : '(' Exp ')' { $2 }
     | Number { AbsHashedLang.ENum $1 }
     | PIdent { AbsHashedLang.EIdent $1 }
{

returnM :: a -> Err a
returnM = return

thenM :: Err a -> (a -> Err b) -> Err b
thenM = (>>=)

happyError :: [Token] -> Err a
happyError ts =
  Bad $ "syntax error at " ++ tokenPos ts ++
  case ts of
    []      -> []
    [Err _] -> " due to lexer error"
    t:_     -> " before `" ++ id(prToken t) ++ "'"

myLexer = tokens
}

