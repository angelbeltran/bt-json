module Main where

import Lib
import System.IO

main :: IO ()

main = do 
    btToJSON stdin stdout
