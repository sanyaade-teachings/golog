module TORCS.MessageParser
  (ParseResult, stringify, stringify1, parseMsg, parseMsg1, parseMsg') where

import Text.ParserCombinators.Parsec

type Tag = String
type ParseResult = Either ParseError [(Tag, [String])]

stringify1 :: Show a => Tag -> a -> String
stringify1 tag value = stringify tag [value]

stringify :: Show a => Tag -> [a] -> String
stringify tag values = "(" ++ tag ++ concatMap ((" "++).show) values ++ ")"

parseMsg1 :: Read a => ParseResult -> Tag -> a
parseMsg1 result tag =
   case parseMsg result tag of
        x:_ -> x
        _   -> error "parseMsg1: empty parsing result"

parseMsg :: Read a => ParseResult -> Tag -> [a]
parseMsg (Right result) tag =
   case lookup tag result of
        Just values -> map read values
        Nothing     -> error $ "parseMsg: tag "++tag++" not found"
parseMsg (Left _) _ = error "parseMsg: parser error"

parseMsg' :: String -> ParseResult
parseMsg' input = parse csrMsg source input
   where source = "(string: " ++ input ++ ")"

csrMsg :: GenParser Char st [(Tag, [String])]
csrMsg = many keyValue

keyValue :: GenParser Char st (Tag, [String])
keyValue = do  _ <- openBracket
               t:vs <- sepEndBy1 symbol delim
               _ <- closedBracket
               return (t, vs)
   where openBracket   = many space >> char '(' >> many space
         closedBracket = many space >> char ')' >> many space
         delim         = many1 space
         symbol        = many1 (noneOf "() \n")

